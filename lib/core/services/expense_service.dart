import '../models/expense.dart';
import '../models/journal_entry.dart';
import 'database_helper.dart';
import 'accounting_service.dart';

class ExpenseService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final AccountingService _accountingService = AccountingService();

  Future<int> addExpense(Expense expense) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      // 1. Save expense record
      final expenseId = await txn.insert('expenses', expense.toMap());

      // 2. Create Journal Entry
      // Debit: Expense Account (e.g., 5200 - مصاريف عامة)
      // Credit: Cash Account (1100 - الصندوق)
      
      final expenseAccount = await _getAccountByCode(txn, '5200');
      final cashAccount = await _getAccountByCode(txn, '1100');

      if (expenseAccount != null && cashAccount != null) {
        final entry = JournalEntry(
          date: expense.date,
          description: 'مصروف: ${expense.note ?? "بدون ملاحظات"}',
          referenceType: 'expense',
          referenceId: expenseId,
          createdAt: DateTime.now(),
          lines: [
            JournalEntryLine(
              entryId: 0, // Placeholder
              accountId: expenseAccount.id!,
              debit: expense.amount,
              credit: 0,
            ),
            JournalEntryLine(
              entryId: 0, // Placeholder
              accountId: cashAccount.id!,
              debit: 0,
              credit: expense.amount,
            ),
          ],
        );

        // We use a internal helper to add journal entry within the same transaction
        await _addJournalEntryInternal(txn, entry);
      }

      return expenseId;
    });
  }

  Future<List<Expense>> getExpenses() async {
    final db = await _dbHelper.database;
    final maps = await db.query('expenses', orderBy: 'date DESC');
    return maps.map((map) => Expense.fromMap(map)).toList();
  }

  Future<dynamic> _getAccountByCode(dynamic txn, String code) async {
    final maps = await txn.query('accounts', where: 'code = ?', whereArgs: [code]);
    if (maps.isEmpty) return null;
    // We only need the ID and type for internal processing
    return (id: maps.first['id'] as int, type: maps.first['type'] as String);
  }

  Future<void> _addJournalEntryInternal(dynamic txn, JournalEntry entry) async {
    final entryId = await txn.insert('journal_entries', entry.toMap());

    for (var line in entry.lines) {
      await txn.insert('journal_entry_lines', {
        ...line.toMap(),
        'entry_id': entryId,
      });

      // Update account balance
      final accountMaps = await txn.query('accounts', where: 'id = ?', whereArgs: [line.accountId]);
      if (accountMaps.isNotEmpty) {
        final type = accountMaps.first['type'] as String;
        double balanceChange = 0;
        if (type == 'asset' || type == 'expense') {
          balanceChange = line.debit - line.credit;
        } else {
          balanceChange = line.credit - line.debit;
        }

        await txn.execute(
          'UPDATE accounts SET balance = balance + ? WHERE id = ?',
          [balanceChange, line.accountId],
        );
      }
    }
  }
}
