import 'database_helper.dart';
import '../models/discount_code.dart';

class DiscountCodeService {
  final _dbHelper = DatabaseHelper.instance;

  Future<List<DiscountCode>> getAllCodes() async {
    final db = await _dbHelper.database;
    final maps = await db.query('discount_codes', orderBy: 'created_at DESC');
    return maps.map((m) => DiscountCode.fromMap(m)).toList();
  }

  Future<DiscountCode?> getByCode(String code) async {
    final db = await _dbHelper.database;
    final maps = await db.query('discount_codes', where: 'code = ?', whereArgs: [code.toUpperCase()]);
    if (maps.isEmpty) return null;
    return DiscountCode.fromMap(maps.first);
  }

  Future<void> addCode(DiscountCode code) async {
    final db = await _dbHelper.database;
    final map = code.toMap();
    map.remove('id');
    await db.insert('discount_codes', map);
  }

  Future<void> updateCode(DiscountCode code) async {
    final db = await _dbHelper.database;
    await db.update('discount_codes', code.toMap(), where: 'id = ?', whereArgs: [code.id]);
  }

  Future<void> deleteCode(int id) async {
    final db = await _dbHelper.database;
    await db.delete('discount_codes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementUses(int id) async {
    final db = await _dbHelper.database;
    await db.execute('UPDATE discount_codes SET current_uses = current_uses + 1 WHERE id = ?', [id]);
  }

  Future<double> validateAndApply(String codeText, double subtotal) async {
    final code = await getByCode(codeText);
    if (code == null) throw Exception('promo_invalid');
    if (!code.isValid) throw Exception('promo_expired');
    if (code.minPurchase > 0 && subtotal < code.minPurchase) {
      throw Exception('promo_min_purchase');
    }
    return code.applyDiscount(subtotal);
  }
}
