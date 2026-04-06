import '../models/product.dart';
import '../models/app_transaction.dart';
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
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<Product?> getProduct(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
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

  /// Sells a product, deducting its stock and creating a transaction
  Future<void> sellProduct({
    required Product product,
    required int quantity,
    required TransactionType type,
    int? customerId,
    String note = '',
  }) async {
    if (quantity <= 0) throw Exception('Quantity must be greater than 0');
    if (product.stockQuantity < quantity) throw Exception('uninsufficient_stock');

    final double totalAmount = product.price * quantity;
    final String finalNote = note.isEmpty ? 'Sold $quantity x ${product.name}' : 'Sold $quantity x ${product.name} | $note';

    // 1. Create the transaction
    await _transactionService.addTransaction(
      AppTransaction(
        customerId: customerId,
        type: type,
        amount: totalAmount,
        currency: product.currency,
        date: DateTime.now(),
        note: finalNote,
      ),
    );

    // 2. Reduce the stock
    final updatedProduct = product.copyWith(stockQuantity: product.stockQuantity - quantity);
    await updateProduct(updatedProduct);
  }
}
