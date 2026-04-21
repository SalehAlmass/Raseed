
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
}
