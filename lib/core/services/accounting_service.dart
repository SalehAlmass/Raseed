import '../models/account.dart';
import '../models/journal_entry.dart';
import 'database_helper.dart';
import 'package:sqflite/sqflite.dart';

class AccountingService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<Account>> getAccounts() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('accounts', orderBy: 'code ASC');
    return maps.map((map) => Account.fromMap(map)).toList();
  }

  Future<Account?> getAccountByCode(String code) async {
    final db = await _dbHelper.database;
    final maps = await db.query('accounts', where: 'code = ?', whereArgs: [code]);
    if (maps.isEmpty) return null;
    return Account.fromMap(maps.first);
  }

  Future<int> addJournalEntry(JournalEntry entry) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      // 1. Insert header
      final entryId = await txn.insert('journal_entries', entry.toMap());

      // 2. Insert lines and update balances
      for (var line in entry.lines) {
        await txn.insert('journal_entry_lines', {
          ...line.toMap(),
          'entry_id': entryId,
        });

        // Update balance
        // Assets/Expenses: Debit increases (+), Credit decreases (-)
        // Liabilities/Equity/Revenue: Credit increases (+), Debit decreases (-)
        final account = await _getAccountById(txn, line.accountId);
        if (account != null) {
          double balanceChange = 0;
          if (account.type == AccountType.asset || account.type == AccountType.expense) {
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
      return entryId;
    });
  }

  Future<Account?> _getAccountById(DatabaseExecutor db, int id) async {
    final maps = await db.query('accounts', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Account.fromMap(maps.first);
  }

  Future<List<JournalEntry>> getJournalEntries() async {
    final db = await _dbHelper.database;
    final maps = await db.query('journal_entries', orderBy: 'date DESC');
    
    List<JournalEntry> entries = [];
    for (var map in maps) {
      final entryId = map['id'] as int;
      final lineMaps = await db.rawQuery('''
        SELECT jel.*, a.name as account_name 
        FROM journal_entry_lines jel
        JOIN accounts a ON jel.account_id = a.id
        WHERE jel.entry_id = ?
      ''', [entryId]);
      
      final lines = lineMaps.map((m) => JournalEntryLine.fromMap(m, accountName: m['account_name'] as String)).toList();
      entries.add(JournalEntry.fromMap(map, lines: lines));
    }
    return entries;
  }
}
