import 'package:flutter/foundation.dart';
import '../models/shift.dart';
import 'database_helper.dart';

class ShiftService extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  Shift? _currentShift;
  Shift? get currentShift => _currentShift;

  Future<void> loadActiveShift(int userId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'shifts',
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, ShiftStatus.open.name],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      _currentShift = Shift.fromMap(maps.first);
      notifyListeners();
    } else {
      _currentShift = null;
      notifyListeners();
    }
  }

  Future<int> openShift(int userId, double openingBalance) async {
    final shift = Shift(
      userId: userId,
      startTime: DateTime.now(),
      openingBalance: openingBalance,
      status: ShiftStatus.open,
    );

    final db = await _dbHelper.database;
    final id = await db.insert('shifts', shift.toMap());
    _currentShift = Shift.fromMap({...shift.toMap(), 'id': id});
    notifyListeners();
    return id;
  }

  Future<void> closeShift(double actualBalance) async {
    if (_currentShift == null) return;

    final db = await _dbHelper.database;
    
    // Calculate system balance: opening balance + cash sales
    final List<Map<String, dynamic>> salesMap = await db.rawQuery('''
      SELECT SUM(paid_amount) as total_cash 
      FROM transactions 
      WHERE shift_id = ? AND is_void = 0
    ''', [_currentShift!.id]);

    double cashSales = (salesMap.first['total_cash'] as num?)?.toDouble() ?? 0.0;
    double systemBalance = _currentShift!.openingBalance + cashSales;

    final updatedShift = Shift(
      id: _currentShift!.id,
      userId: _currentShift!.userId,
      startTime: _currentShift!.startTime,
      endTime: DateTime.now(),
      openingBalance: _currentShift!.openingBalance,
      closingBalanceSystem: systemBalance,
      closingBalanceActual: actualBalance,
      status: ShiftStatus.closed,
    );

    await db.update(
      'shifts',
      updatedShift.toMap(),
      where: 'id = ?',
      whereArgs: [_currentShift!.id],
    );

    _currentShift = null;
    notifyListeners();
  }

  Future<List<Shift>> getShiftHistory() async {
    final db = await _dbHelper.database;
    final maps = await db.query('shifts', orderBy: 'start_time DESC');
    return maps.map((m) => Shift.fromMap(m)).toList();
  }
}
