import 'package:easy_localization/easy_localization.dart';

import '../models/product.dart';
import '../models/app_transaction.dart';
import '../models/transaction_item.dart';
import '../models/batch.dart';
import 'database_helper.dart';
import 'transaction_service.dart';

class ProductService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final TransactionService _transactionService;

  ProductService(this._transactionService);

  Future<int> addProduct(Product product) async {
    final db = await _dbHelper.database;
    return await db.insert('products', product.toMap());
  }

  Future<List<Product>> getAllProducts() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('products', orderBy: 'name ASC');
    
    final List<Product> products = [];
    for (var map in maps) {
      final product = Product.fromMap(map);
      final batches = await _getBatches(product.id!);
      products.add(product.copyWith(batches: batches));
    }
    return products;
  }

  Future<List<Batch>> _getBatches(int productId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'product_batches',
      where: 'product_id = ? AND quantity > 0',
      orderBy: 'created_at ASC',
    );
    return List.generate(maps.length, (i) => Batch.fromMap(maps[i]));
  }

  Future<Product?> getProduct(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    final product = Product.fromMap(maps.first);
    final batches = await _getBatches(id);
    return product.copyWith(batches: batches);
  }

  Future<int> updateProduct(Product product) async {
    final db = await _dbHelper.database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  /// Sells a product, creating a sale transaction with items
  /// Stock is managed by TransactionService (not duplicated here)
  Future<void> sellProduct({
    required Product product,
    required int quantity,
    required TransactionType type,
    int? customerId,
    double paidAmount = 0,
    String note = '',
  }) async {
    if (quantity <= 0) throw Exception('Quantity must be greater than 0');
    if (product.stockQuantity < quantity) throw Exception('uninsufficient_stock');
    if (type != TransactionType.sale) throw Exception('Invalid transaction type for selling');

    final double totalAmount = product.price * quantity;
    final String finalNote = note.isEmpty ? 'Sold $quantity x ${product.name}' : 'Sold $quantity x ${product.name} | $note';

    // Create transaction item
    final item = TransactionItem(
      productId: product.id!,
      productName: product.name,
      quantity: quantity,
      price: product.price,
      costPrice: product.costPrice,
      currency: product.currency,
    );

    // Create the transaction (TransactionService will handle stock update)
    await _transactionService.addTransaction(
      AppTransaction(
        customerId: customerId,
        type: TransactionType.sale,
        amount: totalAmount,
        paidAmount: paidAmount,
        currency: product.currency,
        date: DateTime.now(),
        note: finalNote,
        items: [item],
      ),
    );
  }

  /// Adds a new batch to a product
  Future<int> addBatch(Batch batch) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      final id = await txn.insert('product_batches', batch.toMap());
      // Update total stock quantity in products table
      await txn.execute(
        'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
        [batch.quantity, batch.productId]
      );
      return id;
    });
  }

  String formatStock(int totalStock, int unitsPerPackage) {
    if (unitsPerPackage <= 1) return "$totalStock ${'units'.tr()}";
    
    final cartons = totalStock ~/ unitsPerPackage;
    final units = totalStock % unitsPerPackage;
    
    if (cartons == 0) return "$units ${'units'.tr()}";
    if (units == 0) return "$cartons ${'packages'.tr()}";
    
    return "$cartons ${'packages'.tr()} + $units ${'units'.tr()}";
  }
}
