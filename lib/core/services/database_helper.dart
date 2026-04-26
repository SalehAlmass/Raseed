import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static String? testPath;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(testPath ?? 'raseed.db');
    return _database!;
  }

  static void reset() {
    _database = null;
  }

  Future<Database> _initDB(String filePath) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path;
    if (filePath == inMemoryDatabasePath) {
      path = inMemoryDatabasePath;
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, filePath);
    }

    return await openDatabase(
      path,
      version: 16,
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
        cost_price REAL DEFAULT 0,
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
        debt_mode TEXT DEFAULT 'block',
        currency TEXT DEFAULT 'YER',
        onboarding_completed INTEGER DEFAULT 0,
        vip_threshold REAL DEFAULT 100000.0,
        inactive_days INTEGER DEFAULT 30,
        dead_days INTEGER DEFAULT 90
      )
    ''');

    await db.insert('settings', {
      'max_debt': 1000.0,
      'reminder_days': 30,
      'strict_mode': 0,
      'currency': 'YER',
      'onboarding_completed': 0,
      'vip_threshold': 100000.0,
      'inactive_days': 30,
      'dead_days': 90,
    });

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
        total_spent REAL DEFAULT 0,
        reorder_level INTEGER DEFAULT 0,
        wholesale_price REAL DEFAULT 0,
        shelf_location TEXT,
        category_id INTEGER,
        main_unit_id INTEGER,
        sub_unit_id INTEGER,
        conversion_factor INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE product_batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        cost_price REAL NOT NULL,
        created_at TEXT NOT NULL,
        expiry_date TEXT,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
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
    if (oldVersion < 10) {
      await db.execute("ALTER TABLE settings ADD COLUMN debt_mode TEXT DEFAULT 'block'");
    }
    if (oldVersion < 11) {
      await db.execute("ALTER TABLE products ADD COLUMN cost_price REAL DEFAULT 0");
      await db.execute("ALTER TABLE transaction_items ADD COLUMN cost_price REAL DEFAULT 0");
    }
    if (oldVersion < 12) {
      await db.execute("ALTER TABLE products ADD COLUMN units_per_package INTEGER DEFAULT 1");
      await db.execute("ALTER TABLE products ADD COLUMN package_price REAL DEFAULT 0");
      
      await db.execute('''
        CREATE TABLE product_batches (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          quantity INTEGER NOT NULL,
          cost_price REAL NOT NULL,
          created_at TEXT NOT NULL,
          expiry_date TEXT,
          FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
        )
      ''');

      // Migrate existing products to batches
      final products = await db.query('products');
      final now = DateTime.now().toIso8601String();
      for (var product in products) {
        final stock = (product['stock_quantity'] as num?)?.toInt() ?? 0;
        if (stock > 0) {
          await db.insert('product_batches', {
            'product_id': product['id'],
            'quantity': stock,
            'cost_price': product['cost_price'] ?? 0.0,
            'created_at': now,
          });
        }
      }
    }
    if (oldVersion < 13) {
       await db.execute("ALTER TABLE settings ADD COLUMN vip_threshold REAL DEFAULT 100000.0");
       await db.execute("ALTER TABLE settings ADD COLUMN inactive_days INTEGER DEFAULT 30");
       await db.execute("ALTER TABLE settings ADD COLUMN dead_days INTEGER DEFAULT 90");
       await db.execute("ALTER TABLE customers ADD COLUMN total_spent REAL DEFAULT 0");
    }
    if (oldVersion < 14) {
      // 1. Create categories table
      await db.execute('''
        CREATE TABLE categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL
        )
      ''');

      // 2. Create units table
      await db.execute('''
        CREATE TABLE units (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          parent_id INTEGER,
          FOREIGN KEY (parent_id) REFERENCES units (id) ON DELETE SET NULL
        )
      ''');

      // 3. Add default data
      await db.insert('categories', {'name': 'العام'});
      await db.insert('categories', {'name': 'مشروبات'});
      await db.insert('categories', {'name': 'مواد غذائية'});
      
      await db.insert('units', {'name': 'كرتون'}); // id: 1
      await db.insert('units', {'name': 'حبة', 'parent_id': 1}); // id: 2, parent: كرتون
      await db.insert('units', {'name': 'كيلو'}); // id: 3
      await db.insert('units', {'name': 'جرام', 'parent_id': 3}); // id: 4, parent: كيلو

      // 4. Update products table
      await db.execute("ALTER TABLE products ADD COLUMN category_id INTEGER");
      await db.execute("ALTER TABLE products ADD COLUMN main_unit_id INTEGER");
      await db.execute("ALTER TABLE products ADD COLUMN sub_unit_id INTEGER");
      await db.execute("ALTER TABLE products ADD COLUMN conversion_factor INTEGER DEFAULT 1");
    }
    if (oldVersion < 15) {
      await db.execute("ALTER TABLE products ADD COLUMN reorder_level INTEGER DEFAULT 0");
      await db.execute("ALTER TABLE products ADD COLUMN wholesale_price REAL DEFAULT 0");
      await db.execute("ALTER TABLE products ADD COLUMN shelf_location TEXT");
    }
    if (oldVersion < 16) {
      await db.execute("ALTER TABLE units ADD COLUMN parent_id INTEGER");
      
      // Update existing default units if they exist
      final units = await db.query('units');
      int? cartonId;
      int? pieceId;
      int? kgId;
      int? gramId;

      for (var u in units) {
        final name = u['name'].toString();
        if (name == 'كرتون') cartonId = u['id'] as int;
        if (name == 'حبة') pieceId = u['id'] as int;
        if (name == 'كيلو') kgId = u['id'] as int;
        if (name == 'جرام') gramId = u['id'] as int;
      }

      if (cartonId != null && pieceId != null) {
        await db.update('units', {'parent_id': cartonId}, where: 'id = ?', whereArgs: [pieceId]);
      }
      if (kgId != null && gramId != null) {
        await db.update('units', {'parent_id': kgId}, where: 'id = ?', whereArgs: [gramId]);
      }
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
