import '../models/app_settings.dart';
import 'database_helper.dart';

class SettingsService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<AppSettings> getSettings() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('settings', limit: 1);
    if (maps.isEmpty) return AppSettings();
    return AppSettings.fromMap(maps.first);
  }

  Future<void> updateSettings(AppSettings settings) async {
    final db = await _dbHelper.database;
    await db.update('settings', settings.toMap());
  }
}
