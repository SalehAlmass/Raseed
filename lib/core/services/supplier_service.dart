import '../models/supplier.dart';
import 'database_helper.dart';

class SupplierService {
  final _dbHelper = DatabaseHelper.instance;

  Future<int> addSupplier(Supplier supplier) async {
    final db = await _dbHelper.database;
    return await db.insert('suppliers', supplier.toMap());
  }

  Future<List<Supplier>> getAllSuppliers() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('suppliers', orderBy: 'name ASC');
    return List.generate(maps.length, (i) => Supplier.fromMap(maps[i]));
  }

  Future<int> updateSupplier(Supplier supplier) async {
    final db = await _dbHelper.database;
    return await db.update(
      'suppliers',
      supplier.toMap(),
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
  }

  Future<int> deleteSupplier(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'suppliers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Supplier?> getSupplierById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'suppliers',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Supplier.fromMap(maps.first);
    }
    return null;
  }

  Future<void> updateSupplierDebt(int supplierId, double amountDelta) async {
    final db = await _dbHelper.database;
    final supplier = await getSupplierById(supplierId);
    if (supplier != null) {
      final newDebt = supplier.totalDebt + amountDelta;
      await db.update(
        'suppliers',
        {
          'total_debt': newDebt,
          'last_transaction_date': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [supplierId],
      );
    }
  }
}
