import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';

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
      version: 25,
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
        total_spent REAL DEFAULT 0,
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
        dead_days INTEGER DEFAULT 90,
        enable_whatsapp INTEGER DEFAULT 1,
        enable_pdf_receipt INTEGER DEFAULT 1,
        product_form_config TEXT,
        module_config TEXT,
        store_profile TEXT,
        staff_config TEXT
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
        conversion_factor INTEGER DEFAULT 1,
        supplier_id INTEGER,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE SET NULL
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

    // Categories table (v14+)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT,
        color INTEGER
      )
    ''');

    // Units table (v14+)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS units (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'main',
        parent_id INTEGER,
        conversion_factor INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        company TEXT,
        total_debt REAL DEFAULT 0,
        last_transaction_date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE supplier_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER NOT NULL,
        type TEXT NOT NULL, -- purchase, payment
        amount REAL NOT NULL,
        paid_amount REAL DEFAULT 0,
        currency TEXT DEFAULT 'YER',
        date TEXT NOT NULL,
        note TEXT,
        is_void INTEGER DEFAULT 0,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE supplier_transaction_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        cost_price REAL NOT NULL,
        currency TEXT DEFAULT 'YER',
        FOREIGN KEY (transaction_id) REFERENCES supplier_transactions (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE SET NULL
    )
    ''');

    // Accounting Tables (v22+)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL, -- asset, liability, equity, revenue, expense
        parent_id INTEGER,
        balance REAL DEFAULT 0,
        FOREIGN KEY (parent_id) REFERENCES accounts (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS journal_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        description TEXT,
        reference_type TEXT, -- sale, purchase, payment, manual
        reference_id INTEGER,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS journal_entry_lines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entry_id INTEGER NOT NULL,
        account_id INTEGER NOT NULL,
        debit REAL DEFAULT 0,
        credit REAL DEFAULT 0,
        FOREIGN KEY (entry_id) REFERENCES journal_entries (id) ON DELETE CASCADE,
        FOREIGN KEY (account_id) REFERENCES accounts (id)
      )
    ''');

    // Insert Default Chart of Accounts
    await _insertDefaultAccounts(db);

    // Create performance indexes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_customer_id ON transactions(customer_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transaction_items_transaction_id ON transaction_items(transaction_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers(name)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_supplier_transactions_supplier_id ON supplier_transactions(supplier_id)');
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
    if (oldVersion < 17) {
      try {
        await db.execute("ALTER TABLE settings ADD COLUMN enable_whatsapp INTEGER DEFAULT 1");
      } catch (e) {
        if (!e.toString().contains('duplicate column name')) rethrow;
      }
      try {
        await db.execute("ALTER TABLE settings ADD COLUMN enable_pdf_receipt INTEGER DEFAULT 1");
      } catch (e) {
        if (!e.toString().contains('duplicate column name')) rethrow;
      }
    }

    // v18: Safety migration — ensure categories & units tables exist on ALL devices
    // Fixes devices that had a database version ≥14 but somehow missing these tables.
    if (oldVersion < 18) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          icon TEXT,
          color INTEGER
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS units (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL DEFAULT 'main',
          parent_id INTEGER,
          conversion_factor INTEGER DEFAULT 1
        )
      ''');
    }

    // v19: Ensure total_spent column exists in customers table
    if (oldVersion < 19) {
      try {
        await db.execute("ALTER TABLE customers ADD COLUMN total_spent REAL DEFAULT 0");
      } catch (e) {
        if (!e.toString().contains('duplicate column name')) {
          debugPrint('Error adding total_spent column: $e');
        }
      }
    }

    // v20: Create suppliers table
    if (oldVersion < 20) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS suppliers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT NOT NULL,
          company TEXT,
          total_debt REAL DEFAULT 0,
          last_transaction_date TEXT
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers(name)');
    }

    // v21: Supplier improvements
    if (oldVersion < 21) {
      // 1. Add supplier_id to products
      try {
        await db.execute("ALTER TABLE products ADD COLUMN supplier_id INTEGER");
      } catch (e) {
        if (!e.toString().contains('duplicate column name')) rethrow;
      }

      // 2. Create supplier_transactions
      await db.execute('''
        CREATE TABLE IF NOT EXISTS supplier_transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          supplier_id INTEGER NOT NULL,
          type TEXT NOT NULL,
          amount REAL NOT NULL,
          paid_amount REAL DEFAULT 0,
          currency TEXT DEFAULT 'YER',
          date TEXT NOT NULL,
          note TEXT,
          is_void INTEGER DEFAULT 0,
          FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE
        )
      ''');

      // 3. Create supplier_transaction_items
      await db.execute('''
        CREATE TABLE IF NOT EXISTS supplier_transaction_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          transaction_id INTEGER NOT NULL,
          product_id INTEGER NOT NULL,
          product_name TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          cost_price REAL NOT NULL,
          currency TEXT DEFAULT 'YER',
          FOREIGN KEY (transaction_id) REFERENCES supplier_transactions (id) ON DELETE CASCADE,
          FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE SET NULL
        )
      ''');
      
      await db.execute('CREATE INDEX IF NOT EXISTS idx_supplier_transactions_supplier_id ON supplier_transactions(supplier_id)');
    }

    // v22: Accounting tables
    if (oldVersion < 22) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS accounts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          code TEXT UNIQUE NOT NULL,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          parent_id INTEGER,
          balance REAL DEFAULT 0,
          FOREIGN KEY (parent_id) REFERENCES accounts (id) ON DELETE SET NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS journal_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          description TEXT,
          reference_type TEXT,
          reference_id INTEGER,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS journal_entry_lines (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          entry_id INTEGER NOT NULL,
          account_id INTEGER NOT NULL,
          debit REAL DEFAULT 0,
          credit REAL DEFAULT 0,
          FOREIGN KEY (entry_id) REFERENCES journal_entries (id) ON DELETE CASCADE,
          FOREIGN KEY (account_id) REFERENCES accounts (id)
        )
      ''');

      await _insertDefaultAccounts(db);
    }

    if (oldVersion < 23) {
      try {
        await db.execute('ALTER TABLE settings ADD COLUMN product_form_config TEXT');
      } catch (e) {
        debugPrint("product_form_config already exists");
      }
    }

    if (oldVersion < 24) {
      try {
        await db.execute('ALTER TABLE settings ADD COLUMN module_config TEXT');
      } catch (e) {
        debugPrint("module_config already exists");
      }
    }

    if (oldVersion < 25) {
      try {
        await db.execute('ALTER TABLE settings ADD COLUMN store_profile TEXT');
      } catch (e) {
        debugPrint("store_profile already exists");
      }
      try {
        await db.execute('ALTER TABLE settings ADD COLUMN staff_config TEXT');
      } catch (e) {
        debugPrint("staff_config already exists");
      }
    }
  }

  Future<void> _insertDefaultAccounts(Database db) async {
    final now = DateTime.now().toIso8601String();
    
    // Assets
    await db.insert('accounts', {'code': '1000', 'name': 'الأصول', 'type': 'asset'});
    await db.insert('accounts', {'code': '1100', 'name': 'الصندوق', 'type': 'asset', 'parent_id': 1});
    await db.insert('accounts', {'code': '1200', 'name': 'المخزون', 'type': 'asset', 'parent_id': 1});
    await db.insert('accounts', {'code': '1300', 'name': 'ذمم العملاء', 'type': 'asset', 'parent_id': 1});
    
    // Liabilities
    await db.insert('accounts', {'code': '2000', 'name': 'الخصوم', 'type': 'liability'});
    await db.insert('accounts', {'code': '2100', 'name': 'ذمم الموردين', 'type': 'liability', 'parent_id': 5});
    
    // Equity
    await db.insert('accounts', {'code': '3000', 'name': 'حقوق الملكية', 'type': 'equity'});
    await db.insert('accounts', {'code': '3100', 'name': 'رأس المال', 'type': 'equity', 'parent_id': 7});
    
    // Revenue
    await db.insert('accounts', {'code': '4000', 'name': 'الإيرادات', 'type': 'revenue'});
    await db.insert('accounts', {'code': '4100', 'name': 'إيرادات المبيعات', 'type': 'revenue', 'parent_id': 9});
    
    // Expenses
    await db.insert('accounts', {'code': '5000', 'name': 'المصروفات', 'type': 'expense'});
    await db.insert('accounts', {'code': '5100', 'name': 'تكلفة البضاعة المباعة', 'type': 'expense', 'parent_id': 11});
    await db.insert('accounts', {'code': '5200', 'name': 'مصاريف عامة', 'type': 'expense', 'parent_id': 11});
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }

  Future<void> _deleteAllTables(Database db) async {
    // Delete in order to respect foreign key constraints
    await db.delete('journal_entry_lines');
    await db.delete('journal_entries');
    await db.delete('accounts');
    await db.delete('supplier_transaction_items');
    await db.delete('supplier_transactions');
    await db.delete('suppliers');
    await db.delete('transaction_items');
    await db.delete('transactions');
    await db.delete('customers');
    await db.delete('products');
    await db.delete('categories');
    await db.delete('units');
    await db.delete('product_batches');
  }

  Future<void> deleteAllData() async {
    final db = await instance.database;
    
    await db.transaction((txn) async {
      // 1. Delete all transaction and master data
      await txn.delete('journal_entry_lines');
      await txn.delete('journal_entries');
      await txn.delete('supplier_transaction_items');
      await txn.delete('supplier_transactions');
      await txn.delete('transaction_items');
      await txn.delete('transactions');
      await txn.delete('customers');
      await txn.delete('suppliers');
      await txn.delete('products');
      await txn.delete('product_batches');
      
      // 2. Reset account balances instead of deleting accounts (to keep the structure)
      await txn.update('accounts', {'balance': 0.0});
      
      // 3. Reset settings to default values
      await txn.update('settings', {
        'max_debt': 1000.0,
        'reminder_days': 30,
        'strict_mode': 0,
        'currency': 'YER',
        'onboarding_completed': 0,
      });
    });
  }
}
