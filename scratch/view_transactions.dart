import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../lib/core/services/database_helper.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  print('--- DB DIAGNOSTICS ---');
  final dbHelper = DatabaseHelper.instance;
  final db = await dbHelper.database;

  final customers = await db.query('customers');
  print('\n=== CUSTOMERS ===');
  for (var c in customers) {
    print('ID: ${c['id']}, Name: ${c['name']}, Phone: ${c['phone']}, Total Debt: ${c['total_debt']}, Total Spent: ${c['total_spent']}');
  }

  final transactions = await db.query('transactions');
  print('\n=== TRANSACTIONS ===');
  for (var t in transactions) {
    print('ID: ${t['id']}, CustomerID: ${t['customer_id']}, Type: ${t['type']}, Amount: ${t['amount']}, Paid: ${t['paid_amount']}, Date: ${t['date']}, Note: ${t['note']}, Void: ${t['is_void']}');
  }

  print('\n--- Diagnostic Complete ---');
  exit(0);
}
