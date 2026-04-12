
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../lib/core/models/app_settings.dart';
import '../lib/core/models/app_transaction.dart';
import '../lib/core/models/customer.dart';
import '../lib/core/models/transaction_item.dart';
import '../lib/core/services/database_helper.dart';
import '../lib/core/services/transaction_service.dart';
import '../lib/core/services/customer_service.dart';
import '../lib/core/services/settings_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper dbHelper;
  late CustomerService customerService;
  late SettingsService settingsService;
  late TransactionService transactionService;

  setUp(() async {
    DatabaseHelper.testPath = inMemoryDatabasePath;
    DatabaseHelper.reset();
    dbHelper = DatabaseHelper.instance;
    customerService = CustomerService();
    settingsService = SettingsService();
    transactionService = TransactionService(customerService, settingsService);
  });

  group('Transaction Rules Enforcement', () {
    test('Should block sale if insufficient stock and strictMode is ON', () async {
      final db = await dbHelper.database;
      final productId = await db.insert('products', {
        'name': 'Laptop',
        'price': 1000.0,
        'stock_quantity': 5,
        'barcode': '12345',
      });

      final customerId = await customerService.createCustomer(Customer(name: 'Test', phone: '1'));
      
      await settingsService.updateSettings(AppSettings(strictMode: true));

      final sale = AppTransaction(
        customerId: customerId,
        type: TransactionType.sale,
        amount: 6000.0,
        date: DateTime.now(),
        items: [
          TransactionItem(productId: productId, productName: 'Laptop', quantity: 6, price: 1000.0)
        ],
      );

      expect(() => transactionService.addTransaction(sale), throwsA(anything));
    });

    test('Should increase stock on refund and decrease on void refund', () async {
      final db = await dbHelper.database;
      final productId = await db.insert('products', {
        'name': 'Laptop',
        'price': 1000.0,
        'stock_quantity': 5,
        'barcode': '12345',
      });

      final customerId = await customerService.createCustomer(Customer(name: 'Test', phone: '1'));
      await settingsService.updateSettings(AppSettings(maxDebt: 5000));
      
      // 1. Sale
      final sale = AppTransaction(
        customerId: customerId,
        type: TransactionType.sale,
        amount: 2000.0,
        paidAmount: 500.0,
        date: DateTime.now(),
        items: [
          TransactionItem(productId: productId, productName: 'Laptop', quantity: 2, price: 1000.0)
        ],
      );
      final saleId = await transactionService.addTransaction(sale);

      var prod = await db.query('products', where: 'id = ?', whereArgs: [productId]);
      expect(prod.first['stock_quantity'], 3);

      // 2. Refund
      final originalSale = (await transactionService.getAllTransactions()).first;
      final item = originalSale.items.first;
      final refundId = await transactionService.processRefund(
        originalTransaction: originalSale,
        itemsToRefund: [
          TransactionItem(
            productId: item.productId,
            productName: item.productName,
            quantity: 1,
            price: item.price,
            currency: item.currency,
          )
        ],
      );

      prod = await db.query('products', where: 'id = ?', whereArgs: [productId]);
      expect(prod.first['stock_quantity'], 4);

      var customer = await customerService.getCustomer(customerId);
      expect(customer?.totalDebt, 500.0); // 1500 - 1000

      // 3. Void Refund
      final refundTx = (await transactionService.getAllTransactions()).firstWhere((t) => t.id == refundId);
      await transactionService.voidTransaction(refundTx);

      prod = await db.query('products', where: 'id = ?', whereArgs: [productId]);
      expect(prod.first['stock_quantity'], 3);

      customer = await customerService.getCustomer(customerId);
      expect(customer?.totalDebt, 1500.0);
    });

    test('Should block sale on debt limit in BLOCK mode', () async {
      final customerId = await customerService.createCustomer(Customer(name: 'Test', phone: '1'));
      await settingsService.updateSettings(AppSettings(maxDebt: 100, debtMode: DebtMode.block));

      final sale = AppTransaction(
        customerId: customerId,
        type: TransactionType.sale,
        amount: 200.0,
        paidAmount: 0.0,
        date: DateTime.now(),
      );

      expect(() => transactionService.addTransaction(sale), throwsA(anything));
    });

    test('Should allow sale on debt limit in WARNING mode', () async {
      final customerId = await customerService.createCustomer(Customer(name: 'Test', phone: '1'));
      await settingsService.updateSettings(AppSettings(maxDebt: 100, debtMode: DebtMode.warning));

      final sale = AppTransaction(
        customerId: customerId,
        type: TransactionType.sale,
        amount: 200.0,
        paidAmount: 0.0,
        date: DateTime.now(),
      );

      final id = await transactionService.addTransaction(sale);
      expect(id, greaterThan(0));
    });
  });
}
