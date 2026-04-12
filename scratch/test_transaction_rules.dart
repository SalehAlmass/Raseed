
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../lib/core/models/app_settings.dart';
import '../lib/core/models/app_transaction.dart';
import '../lib/core/models/customer.dart';
import '../lib/core/models/product.dart';
import '../lib/core/models/transaction_item.dart';
import '../lib/core/services/database_helper.dart';
import '../lib/core/services/transaction_service.dart';
import '../lib/core/services/customer_service.dart';
import '../lib/core/services/settings_service.dart';

void main() async {
  // Initialize FFI
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  print('--- Starting Transaction Service Test ---');

  final dbHelper = DatabaseHelper.instance;
  final customerService = CustomerService();
  final settingsService = SettingsService();
  final transactionService = TransactionService(customerService, settingsService);

  // Clear data for fresh test
  await dbHelper.deleteAllData();

  // 1. Create Customer
  final customerId = await customerService.createCustomer(Customer(
    name: 'Test Customer',
    phone: '123456789',
  ));
  print('Created Customer: $customerId');

  // 2. Create Product
  final db = await dbHelper.database;
  final productId = await db.insert('products', {
    'name': 'Laptop',
    'price': 1000.0,
    'stock_quantity': 5,
    'barcode': '12345',
  });
  print('Created Product: $productId with stock 5');

  // 3. Test Strict Stock (Set strictMode to true)
  await settingsService.updateSettings(AppSettings(strictMode: true, maxDebt: 5000));
  print('Settings updated: strictMode=true, maxDebt=5000');

  try {
    print('Testing insufficient stock sale...');
    await transactionService.addTransaction(AppTransaction(
      customerId: customerId,
      type: TransactionType.sale,
      amount: 6000.0,
      date: DateTime.now(),
      items: [
        TransactionItem(
          productId: productId,
          productName: 'Laptop',
          quantity: 6, // More than 5
          price: 1000.0,
        )
      ],
    ));
    print('FAIL: Sale succeeded despite insufficient stock');
  } catch (e) {
    print('SUCCESS: Caught expected exception: $e');
  }

  // 4. Test Valid Sale
  print('Testing valid sale...');
  final saleId = await transactionService.addTransaction(AppTransaction(
    customerId: customerId,
    type: TransactionType.sale,
    amount: 2000.0,
    paidAmount: 500.0,
    date: DateTime.now(),
    items: [
      TransactionItem(
        productId: productId,
        productName: 'Laptop',
        quantity: 2,
        price: 1000.0,
      )
    ],
  ));
  print('Sale created: $saleId');

  final customerAfterSale = await customerService.getCustomer(customerId);
  print('Customer debt after sale: ${customerAfterSale?.totalDebt} (Expected: 1500)');
  
  final productAfterSale = await db.query('products', where: 'id = ?', whereArgs: [productId]);
  print('Product stock after sale: ${productAfterSale.first['stock_quantity']} (Expected: 3)');

  // 5. Test Refund (Return)
  print('Testing refund...');
  final originalSale = (await transactionService.getAllTransactions()).first;
  final itemToRefund = originalSale.items.first.copyWith(quantity: 1);
  
  final refundId = await transactionService.processRefund(
    originalTransaction: originalSale,
    itemsToRefund: [itemToRefund],
  );
  print('Refund created: $refundId');

  final customerAfterRefund = await customerService.getCustomer(customerId);
  print('Customer debt after refund: ${customerAfterRefund?.totalDebt} (Expected: 500)');
  
  final productAfterRefund = await db.query('products', where: 'id = ?', whereArgs: [productId]);
  print('Product stock after refund: ${productAfterRefund.first['stock_quantity']} (Expected: 4)');

  // 6. Test Void Refund
  print('Testing void refund...');
  final refundTransaction = (await transactionService.getAllTransactions()).firstWhere((t) => t.id == refundId);
  await transactionService.voidTransaction(refundTransaction);
  print('Refund voided');

  final customerAfterVoid = await customerService.getCustomer(customerId);
  print('Customer debt after void refund: ${customerAfterVoid?.totalDebt} (Expected: 1500)');
  
  final productAfterVoid = await db.query('products', where: 'id = ?', whereArgs: [productId]);
  print('Product stock after void refund: ${productAfterVoid.first['stock_quantity']} (Expected: 3)');

  // 7. Test Debt Limit (BLOCK)
  print('Testing debt limit (BLOCK)...');
  await settingsService.updateSettings(AppSettings(maxDebt: 1000, debtMode: DebtMode.block));
  
  try {
    await transactionService.addTransaction(AppTransaction(
      customerId: customerId,
      type: TransactionType.sale,
      amount: 1000.0,
      paidAmount: 0.0,
      date: DateTime.now(),
      items: [
        TransactionItem(
          productId: productId,
          productName: 'Laptop',
          quantity: 1,
          price: 1000.0,
        )
      ],
    ));
    print('FAIL: Sale succeeded despite debt limit');
  } catch (e) {
    print('SUCCESS: Caught expected exception: $e');
  }

  // 8. Test Debt Limit (WARNING)
  print('Testing debt limit (WARNING)...');
  await settingsService.updateSettings(AppSettings(maxDebt: 1000, debtMode: DebtMode.warning));
  
  final warningSaleId = await transactionService.addTransaction(AppTransaction(
    customerId: customerId,
    type: TransactionType.sale,
    amount: 1000.0,
    paidAmount: 0.0,
    date: DateTime.now(),
    items: [
      TransactionItem(
        productId: productId,
        productName: 'Laptop',
        quantity: 1,
        price: 1000.0,
      )
    ],
  ));
  print('Sale with warning succeeded: $warningSaleId');

  print('--- Test Complete ---');
  exit(0);
}
