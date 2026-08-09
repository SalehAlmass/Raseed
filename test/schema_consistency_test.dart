import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rseed/core/models/app_settings.dart';
import 'package:rseed/core/models/app_transaction.dart';
import 'package:rseed/core/models/customer.dart';
import 'package:rseed/core/models/supplier.dart';
import 'package:rseed/core/models/supplier_transaction.dart';
import 'package:rseed/core/models/transaction_item.dart';
import 'package:rseed/core/services/customer_service.dart';
import 'package:rseed/core/services/database_helper.dart';
import 'package:rseed/core/services/settings_service.dart';
import 'package:rseed/core/services/supplier_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Set<String>> tableColumns(Database db, String table) async {
  final info = await db.rawQuery('PRAGMA table_info($table)');
  return info.map((row) => row['name'] as String).toSet();
}

/// Creates a database replicating the schema a real pre-fix database had after
/// migrating through versions 1..36: the final columns are MISSING because the
/// pre-fix `_createDB` (fresh installs) lacked them, and migrated databases
/// never received `settings.store_profile`.
Future<void> createOldV36Schema(Database db) async {
  await db.execute('''
    CREATE TABLE settings (
      max_debt REAL DEFAULT 100000,
      reminder_days INTEGER DEFAULT 30,
      strict_mode INTEGER DEFAULT 0,
      debt_mode TEXT DEFAULT 'block',
      currency TEXT DEFAULT 'YER',
      onboarding_completed INTEGER DEFAULT 0,
      vip_threshold REAL DEFAULT 100000.0,
      inactive_days INTEGER DEFAULT 30,
      dead_days INTEGER DEFAULT 90,
      enable_whatsapp INTEGER DEFAULT 1,
      enable_pdf_receipt INTEGER DEFAULT 1,
      product_form_config TEXT,
      module_config TEXT,
      staff_config TEXT,
      language_code TEXT DEFAULT 'ar',
      pdf_page_format TEXT DEFAULT 'A4',
      receipt_width INTEGER DEFAULT 80
    )
  ''');
  await db.insert('settings', {
    'max_debt': 100000.0,
    'reminder_days': 30,
    'strict_mode': 0,
    'currency': 'YER',
    'onboarding_completed': 0,
    'vip_threshold': 100000.0,
    'inactive_days': 30,
    'dead_days': 90,
    'language_code': 'ar',
    'pdf_page_format': 'A4',
    'receipt_width': 80,
  });

  await db.execute('''
    CREATE TABLE customers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      phone TEXT NOT NULL,
      total_debt REAL DEFAULT 0,
      total_spent REAL DEFAULT 0,
      last_transaction_date TEXT
    )
  ''');

  await db.execute('''
    CREATE TABLE products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      price REAL NOT NULL,
      cost_price REAL DEFAULT 0,
      currency TEXT DEFAULT 'YER',
      stock_quantity INTEGER DEFAULT 0,
      barcode TEXT,
      units_per_package INTEGER DEFAULT 1,
      package_price REAL DEFAULT 0,
      reorder_level INTEGER DEFAULT 0,
      wholesale_price REAL DEFAULT 0,
      shelf_location TEXT,
      category_id INTEGER,
      main_unit_id INTEGER,
      sub_unit_id INTEGER,
      conversion_factor INTEGER DEFAULT 1,
      supplier_id INTEGER
    )
  ''');

  await db.execute('''
    CREATE TABLE transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      customer_id INTEGER,
      type TEXT NOT NULL,
      amount REAL NOT NULL,
      paid_amount REAL DEFAULT 0,
      currency TEXT DEFAULT 'YER',
      date TEXT NOT NULL,
      note TEXT,
      is_void INTEGER DEFAULT 0
    )
  ''');

  await db.execute('''
    CREATE TABLE transaction_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      transaction_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      product_name TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      price REAL NOT NULL,
      cost_price REAL DEFAULT 0,
      currency TEXT DEFAULT 'YER'
    )
  ''');

  await db.execute('''
    CREATE TABLE suppliers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      phone TEXT NOT NULL,
      company TEXT,
      total_debt REAL DEFAULT 0,
      total_paid REAL DEFAULT 0,
      last_transaction_date TEXT
    )
  ''');

  await db.execute('''
    CREATE TABLE supplier_transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      supplier_id INTEGER NOT NULL,
      type TEXT NOT NULL,
      amount REAL NOT NULL,
      paid_amount REAL DEFAULT 0,
      currency TEXT DEFAULT 'YER',
      date TEXT NOT NULL,
      note TEXT,
      is_void INTEGER DEFAULT 0
    )
  ''');

  await db.execute('''
    CREATE TABLE categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE units (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      parent_id INTEGER
    )
  ''');
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Fresh installation (v37)', () {
    setUp(() {
      DatabaseHelper.testPath = inMemoryDatabasePath;
      DatabaseHelper.reset();
    });

    test('canonical columns exist on fresh database', () async {
      final db = await DatabaseHelper.instance.database;

      expect(
        await tableColumns(db, 'transactions'),
        containsAll(['shift_id', 'return_reason', 'return_condition', 'discount_type', 'discount_value', 'promo_code']),
      );
      expect(await tableColumns(db, 'transaction_items'), contains('line_discount'));
      expect(await tableColumns(db, 'supplier_transactions'), contains('return_reason'));
      expect(await tableColumns(db, 'settings'), contains('store_profile'));
      expect(await tableColumns(db, 'customers'), contains('total_debt_sar'));
    });

    test('model writes that previously crashed on fresh install now succeed', () async {
      final db = await DatabaseHelper.instance.database;
      final customerId = await CustomerService().createCustomer(Customer(name: 'Ahmad', phone: '1'));
      final settingsService = SettingsService();
      final supplierService = SupplierService();

      await settingsService.updateSettings(AppSettings(languageCode: 'en'));
      final settingsRow = await db.query('settings', limit: 1);
      expect(settingsRow.first['language_code'], 'en');
      expect(settingsRow.first.containsKey('store_profile'), isTrue);

      final productId = await db.insert('products', {
        'name': 'Milk',
        'price': 500.0,
        'cost_price': 400.0,
        'stock_quantity': 10,
      });

      final sale = AppTransaction(
        customerId: customerId,
        type: TransactionType.sale,
        amount: 900.0,
        paidAmount: 900.0,
        date: DateTime.now(),
        discountType: DiscountType.percentage,
        discountValue: 10,
        promoCode: 'PROMO10',
        items: [
          TransactionItem(
            productId: productId,
            productName: 'Milk',
            quantity: 2,
            price: 500.0,
            costPrice: 400.0,
            lineDiscount: 100,
          ),
        ],
      );
      final txId = await db.insert('transactions', sale.toMap());
      expect(txId, greaterThan(0));
      final itemId = await db.insert('transaction_items', sale.items.first.toMap()..['transaction_id'] = txId);
      expect(itemId, greaterThan(0));

      final supplierId = await supplierService.addSupplier(Supplier(name: 'S', phone: '2'));
      final supplierReturn = SupplierTransaction(
        supplierId: supplierId,
        type: SupplierTransactionType.return_,
        amount: 500.0,
        date: DateTime.now(),
        returnReason: 'defective',
      );
      final supTxId = await db.insert('supplier_transactions', supplierReturn.toMap());
      expect(supTxId, greaterThan(0));
    });
  });

  group('Migration from existing pre-fix database (36 -> 37)', () {
    late String dbFile;

    setUp(() async {
      dbFile = p.join(Directory.systemTemp.path, 'raseed_schema_test_${DateTime.now().millisecondsSinceEpoch}.db');
      final oldDb = await databaseFactoryFfi.openDatabase(
        dbFile,
        options: OpenDatabaseOptions(
          version: 36,
          onCreate: (db, version) => createOldV36Schema(db),
        ),
      );
      await oldDb.insert('customers', {'name': 'Mahmoud', 'phone': '777', 'total_debt': 1200.0});
      await oldDb.insert('products', {'name': 'Rice', 'price': 1000.0, 'stock_quantity': 8});
      await oldDb.insert('suppliers', {'name': 'Dist', 'phone': '999', 'total_debt': 300.0});
      await oldDb.close();

      DatabaseHelper.testPath = dbFile;
      DatabaseHelper.reset();
    });

    tearDown(() async {
      DatabaseHelper.reset();
      final dir = Directory(p.dirname(dbFile));
      await databaseFactoryFfi.deleteDatabase(dbFile);
      final files = dir.listSync().whereType<File>().where((f) => p.basename(f.path).startsWith(p.basenameWithoutExtension(dbFile)));
      for (final f in files) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    });

    test('migration adds missing canonical columns and preserves data', () async {
      final db = await DatabaseHelper.instance.database;

      expect(
        await tableColumns(db, 'transactions'),
        containsAll(['shift_id', 'return_reason', 'return_condition', 'discount_type', 'discount_value', 'promo_code']),
      );
      expect(await tableColumns(db, 'transaction_items'), contains('line_discount'));
      expect(await tableColumns(db, 'supplier_transactions'), contains('return_reason'));
      expect(await tableColumns(db, 'settings'), contains('store_profile'));
      expect(await tableColumns(db, 'customers'), contains('total_debt_sar'));
      expect(await tableColumns(db, 'categories'), containsAll(['icon', 'color']));
      expect(await tableColumns(db, 'units'), containsAll(['type', 'conversion_factor']));
      expect(await tableColumns(db, 'products'), contains('total_spent'));

      final customer = await db.query('customers');
      expect(customer, hasLength(1));
      expect(customer.first['name'], 'Mahmoud');
      expect(customer.first['total_debt'], 1200.0);

      final product = await db.query('products');
      expect(product, hasLength(1));
      expect(product.first['stock_quantity'], 8);

      final supplier = await db.query('suppliers');
      expect(supplier, hasLength(1));
      expect(supplier.first['total_debt'], 300.0);
    });

    test('migrated database accepts the model writes that previously crashed', () async {
      final db = await DatabaseHelper.instance.database;

      await SettingsService().updateSettings(AppSettings(maxDebt: 50000));
      final settingsRow = await db.query('settings', limit: 1);
      expect(settingsRow.first['max_debt'], 50000.0);
      expect(settingsRow.first.containsKey('store_profile'), isTrue);

      final customerId = await CustomerService().createCustomer(Customer(name: 'Yusuf', phone: '5'));
      final productId = await db.insert('products', {
        'name': 'Tea',
        'price': 200.0,
        'stock_quantity': 5,
      });

      final sale = AppTransaction(
        customerId: customerId,
        type: TransactionType.sale,
        amount: 200.0,
        paidAmount: 0,
        date: DateTime.now(),
        discountType: DiscountType.fixed,
        discountValue: 20,
        items: [
          TransactionItem(
            productId: productId,
            productName: 'Tea',
            quantity: 1,
            price: 200.0,
            lineDiscount: 10,
          ),
        ],
      );
      final txId = await db.insert('transactions', sale.toMap());
      expect(txId, greaterThan(0));
      await db.insert('transaction_items', sale.items.first.toMap()..['transaction_id'] = txId);

      final supplierId = (await db.query('suppliers')).first['id'] as int;
      final supTx = SupplierTransaction(
        supplierId: supplierId,
        type: SupplierTransactionType.payment,
        amount: 100.0,
        date: DateTime.now(),
        returnReason: '',
      );
      final supTxId = await db.insert('supplier_transactions', supTx.toMap());
      expect(supTxId, greaterThan(0));
    });
  });
}
