
import '../models/unit.dart';
import 'database_helper.dart';

class UnitService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> addUnit(Unit unit) async {
    final db = await _dbHelper.database;
    return await db.insert('units', unit.toMap());
  }

  Future<List<Unit>> getAllUnits() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('units', orderBy: 'name ASC');
    return List.generate(maps.length, (i) => Unit.fromMap(maps[i]));
  }

  Future<int> updateUnit(Unit unit) async {
    final db = await _dbHelper.database;
    return await db.update('units', unit.toMap(), where: 'id = ?', whereArgs: [unit.id]);
  }

  Future<int> deleteUnit(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('units', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> isUnitInUse(int id) async {
    final db = await _dbHelper.database;
    // Check if used as main unit or sub unit in products
    final List<Map<String, dynamic>> res = await db.query(
      'products',
      where: 'main_unit_id = ? OR sub_unit_id = ?',
      whereArgs: [id, id],
      limit: 1,
    );
    if (res.isNotEmpty) return true;

    // Also check if used as a parent of another unit
    final List<Map<String, dynamic>> res2 = await db.query(
      'units',
      where: 'parent_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return res2.isNotEmpty;
  }
}
