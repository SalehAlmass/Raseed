import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('raseed.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 9,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        total_debt REAL DEFAULT 0,
        last_transaction_date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER,
        type TEXT NOT NULL, -- sale, payment, return
        amount REAL NOT NULL,
        paid_amount REAL DEFAULT 0,
        currency TEXT DEFAULT 'YER',
        date TEXT NOT NULL,
        note TEXT,
        is_void INTEGER DEFAULT 0,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
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
        currency TEXT DEFAULT 'YER',
        FOREIGN KEY (transaction_id) REFERENCES transactions (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        max_debt REAL DEFAULT 1000,
        reminder_days INTEGER DEFAULT 30,
        strict_mode INTEGER DEFAULT 0,
        currency TEXT DEFAULT 'YER',
        onboarding_completed INTEGER DEFAULT 0
      )
    ''');

    await db.insert('settings', {
      'max_debt': 1000.0,
      'reminder_days': 30,
      'strict_mode': 0,
      'currency': 'YER',
      'onboarding_completed': 0,
    });

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        currency TEXT DEFAULT 'YER',
        stock_quantity INTEGER DEFAULT 0,
        barcode TEXT
      )
    ''');

    // Create performance indexes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_customer_id ON transactions(customer_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transaction_items_transaction_id ON transaction_items(transaction_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode)');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE settings ADD COLUMN currency TEXT DEFAULT "YER"');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE settings ADD COLUMN onboarding_completed INTEGER DEFAULT 0');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE transactions ADD COLUMN currency TEXT DEFAULT "YER"');
      await db.execute('ALTER TABLE customers ADD COLUMN total_debt_sar REAL DEFAULT 0');
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE products (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          price REAL NOT NULL,
          currency TEXT DEFAULT 'YER',
          stock_quantity INTEGER DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE products ADD COLUMN barcode TEXT');
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE transaction_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          transaction_id INTEGER NOT NULL,
          product_id INTEGER NOT NULL,
          product_name TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          price REAL NOT NULL,
          currency TEXT DEFAULT 'YER',
          FOREIGN KEY (transaction_id) REFERENCES transactions (id) ON DELETE CASCADE,
          FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE SET NULL
        )
      ''');
    }
    if (oldVersion < 8) {
      // Add missing columns to transactions table
      await db.execute('ALTER TABLE transactions ADD COLUMN paid_amount REAL DEFAULT 0');
      await db.execute('ALTER TABLE transactions ADD COLUMN is_void INTEGER DEFAULT 0');
      
      // Add performance indexes
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_customer_id ON transactions(customer_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transaction_items_transaction_id ON transaction_items(transaction_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode)');
    }
    if (oldVersion < 9) {
      // Migrate old transaction types to new types
      // 'cash' and 'debt' → 'sale', 'payment' stays 'payment'
      await db.execute("UPDATE transactions SET type = 'sale' WHERE type = 'cash'");
      await db.execute("UPDATE transactions SET type = 'sale' WHERE type = 'debt'");
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }

  Future<void> deleteAllData() async {
    final db = await instance.database;
    
    // Delete all data from tables (in order to respect foreign key constraints)
    await db.delete('transactions');
    await db.delete('customers');
    await db.delete('products');
    
    // Reset settings to default values
    await db.update('settings', {
      'max_debt': 1000.0,
      'reminder_days': 30,
      'strict_mode': 0,
      'currency': 'YER',
      'onboarding_completed': 0,
    });
  }
}
