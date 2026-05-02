import 'database_helper.dart';
import '../models/journal_entry.dart';

class FiscalYearService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<void> performAnnualClosing(String year) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // 1. Get all accounts and their current balances
      final List<Map<String, dynamic>> accounts = await txn.query('accounts');
      
      final now = DateTime.now().toIso8601String();
      
      // 2. Create an Annual Closing Journal Entry
      final entryId = await txn.insert('journal_entries', {
        'date': now,
        'description': 'إقفال السنة المالية $year',
        'is_system_generated': 1,
      });

      for (var account in accounts) {
        double balance = (account['balance'] as num).toDouble();
        if (balance == 0) continue;

        String type = account['type'];
        
        // Logic: 
        // For Assets/Liabilities/Equity -> Carry forward balance
        // For Revenue/Expenses -> Zero out to Equity (Retained Earnings)
        
        if (type == 'revenue' || type == 'expense') {
          // Zero out: Create entry line to offset balance
          await txn.insert('journal_entry_lines', {
            'journal_entry_id': entryId,
            'account_id': account['id'],
            'debit': type == 'revenue' ? balance : 0,
            'credit': type == 'expense' ? balance : 0,
            'description': 'إقفال حساب ${account['name']} للسنة $year',
          });
          
          // Update account balance to zero
          await txn.update('accounts', {'balance': 0}, where: 'id = ?', whereArgs: [account['id']]);
        }
      }

      // 3. Mark all previous entries as archived/closed (optional, based on design)
      // For now, we just ensure balances are correct.
    });
  }
}
