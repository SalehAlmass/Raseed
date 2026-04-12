import '../models/product.dart';
import '../models/app_transaction.dart';
import '../models/transaction_item.dart';
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
}
