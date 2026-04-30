import '../models/app_settings.dart';
import 'database_helper.dart';

class SettingsService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Cache settings
  AppSettings? _cachedSettings;

  Future<AppSettings> getSettings() async {
    if (_cachedSettings != null) return _cachedSettings!;
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('settings', limit: 1);
    if (maps.isEmpty) {
      _cachedSettings = AppSettings();
      return _cachedSettings!;
    }
    _cachedSettings = AppSettings.fromMap(maps.first);
    return _cachedSettings!;
  }

  AppSettings get settings => _cachedSettings ?? AppSettings();

  Future<void> updateSettings(AppSettings settings) async {
    _cachedSettings = settings;
    final db = await _dbHelper.database;
    await db.update('settings', settings.toMap());
  }
}
