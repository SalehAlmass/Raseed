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
      version: 5,
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
        type TEXT NOT NULL, -- cash, debt, payment
        amount REAL NOT NULL,
        currency TEXT DEFAULT 'YER',
        date TEXT NOT NULL,
        note TEXT,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
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
        stock_quantity INTEGER DEFAULT 0
      )
    ''');
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
