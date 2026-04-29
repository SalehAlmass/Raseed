import 'package:easy_localization/easy_localization.dart';
import '../models/supplier_transaction.dart';
import '../models/supplier_transaction_item.dart';
import 'database_helper.dart';
import 'supplier_service.dart';
import 'product_service.dart';
import 'package:sqflite/sqflite.dart';
import '../di/injection_container.dart';
import '../models/journal_entry.dart';
import '../models/account.dart';
import 'accounting_service.dart';

class SupplierTransactionService {
  final _dbHelper = DatabaseHelper.instance;

  Future<int> addTransaction(SupplierTransaction tx) async {
    final db = await _dbHelper.database;
    
    return await db.transaction((txn) async {
      // 1. Insert transaction
      final txId = await txn.insert('supplier_transactions', tx.toMap());

      // 2. Insert items and update stock if it's a purchase
      for (var item in tx.items) {
        await txn.insert('supplier_transaction_items', item.toMap(txId));
        
        if (tx.type == SupplierTransactionType.purchase && !tx.isVoid) {
          // Increment stock
          await txn.execute(
            'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
            [item.quantity, item.productId],
          );
        }
      }

      // 3. Update supplier debt
      double debtChange = 0;
      if (tx.type == SupplierTransactionType.purchase) {
        debtChange = tx.amount - tx.paidAmount;
      } else if (tx.type == SupplierTransactionType.payment) {
        debtChange = -tx.amount;
      }

      if (debtChange != 0 && !tx.isVoid) {
        await txn.execute(
          'UPDATE suppliers SET total_debt = total_debt + ?, last_transaction_date = ? WHERE id = ?',
          [debtChange, tx.date.toIso8601String(), tx.supplierId],
        );
      }

      // 4. Generate Journal Entry
      await _generateJournalEntry(txId, tx, txn);

      return txId;
    });
  }

  Future<void> _generateJournalEntry(int txId, SupplierTransaction tx, Transaction txn) async {
    try {
      final now = DateTime.now();

      if (tx.type == SupplierTransactionType.purchase) {
        // Debit: Inventory (1200) -> 3
        // Credit: Cash (1100) -> 2
        // Credit: Accounts Payable (2100) -> 6

        final entryId = await txn.insert('journal_entries', {
          'date': tx.date.toIso8601String(),
          'description': 'purchase_entry_desc'.tr(args: [txId.toString()]),
          'reference_type': 'purchase',
          'reference_id': txId,
          'created_at': now.toIso8601String(),
        });

        List<JournalEntryLine> lines = [];
        // Inventory (Debit)
        lines.add(JournalEntryLine(entryId: entryId, accountId: 3, debit: tx.amount));
        
        // Cash (Credit)
        if (tx.paidAmount > 0) {
          lines.add(JournalEntryLine(entryId: entryId, accountId: 2, credit: tx.paidAmount));
        }

        // Accounts Payable (Credit)
        final debt = tx.amount - tx.paidAmount;
        if (debt > 0) {
          lines.add(JournalEntryLine(entryId: entryId, accountId: 6, credit: debt));
        }

        for (var line in lines) {
          await txn.insert('journal_entry_lines', line.toMap());
          await _updateAccountBalance(txn, line.accountId, line.debit, line.credit);
        }
      } else if (tx.type == SupplierTransactionType.payment) {
        // Debit: Accounts Payable (2100) -> 6
        // Credit: Cash (1100) -> 2

        final entryId = await txn.insert('journal_entries', {
          'date': tx.date.toIso8601String(),
          'description': 'supplier_payment_entry_desc'.tr(args: [txId.toString()]),
          'reference_type': 'supplier_payment',
          'reference_id': txId,
          'created_at': now.toIso8601String(),
        });

        final lines = [
          JournalEntryLine(entryId: entryId, accountId: 6, debit: tx.amount),
          JournalEntryLine(entryId: entryId, accountId: 2, credit: tx.amount),
        ];

        for (var line in lines) {
          await txn.insert('journal_entry_lines', line.toMap());
          await _updateAccountBalance(txn, line.accountId, line.debit, line.credit);
        }
      }
    } catch (e) {
      print('Supplier Accounting error: $e');
    }
  }

  Future<void> _updateAccountBalance(Transaction txn, int accountId, double debit, double credit) async {
    final maps = await txn.query('accounts', where: 'id = ?', whereArgs: [accountId]);
    if (maps.isEmpty) return;
    final account = Account.fromMap(maps.first);
    
    double balanceChange = 0;
    if (account.type == AccountType.asset || account.type == AccountType.expense) {
      balanceChange = debit - credit;
    } else {
      balanceChange = credit - debit;
    }

    await txn.execute(
      'UPDATE accounts SET balance = balance + ? WHERE id = ?',
      [balanceChange, accountId],
    );
  }

  Future<List<SupplierTransaction>> getTransactionsBySupplier(int supplierId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'supplier_transactions',
      where: 'supplier_id = ?',
      whereArgs: [supplierId],
      orderBy: 'date DESC',
    );

    List<SupplierTransaction> transactions = [];
    for (var map in maps) {
      final itemsMap = await db.query(
        'supplier_transaction_items',
        where: 'transaction_id = ?',
        whereArgs: [map['id']],
      );
      final items = itemsMap.map((m) => SupplierTransactionItem.fromMap(m)).toList();
      transactions.add(SupplierTransaction.fromMap(map, items: items));
    }
    return transactions;
  }

  Future<void> voidTransaction(int txId) async {
    final db = await _dbHelper.database;
    final txMap = await db.query('supplier_transactions', where: 'id = ?', whereArgs: [txId]);
    if (txMap.isEmpty) return;
    
    final tx = SupplierTransaction.fromMap(txMap.first);
    if (tx.isVoid) return;

    await db.transaction((txn) async {
      // 1. Mark as void
      await txn.update('supplier_transactions', {'is_void': 1}, where: 'id = ?', whereArgs: [txId]);

      // 2. Reverse stock if purchase
      if (tx.type == SupplierTransactionType.purchase) {
        final itemsMap = await txn.query('supplier_transaction_items', where: 'transaction_id = ?', whereArgs: [txId]);
        for (var itemMap in itemsMap) {
          final item = SupplierTransactionItem.fromMap(itemMap);
          await txn.execute(
            'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
            [item.quantity, item.productId],
          );
        }
      }

      // 3. Reverse debt
      double debtReverse = 0;
      if (tx.type == SupplierTransactionType.purchase) {
        debtReverse = -(tx.amount - tx.paidAmount);
      } else if (tx.type == SupplierTransactionType.payment) {
        debtReverse = tx.amount;
      }

      if (debtReverse != 0) {
        await txn.execute(
          'UPDATE suppliers SET total_debt = total_debt + ? WHERE id = ?',
          [debtReverse, tx.supplierId],
        );
      }
    });
  }
}
