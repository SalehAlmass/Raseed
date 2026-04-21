
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'google_drive_service.dart';

class BackupService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SharedPreferences _prefs;
  final GoogleDriveService _googleDriveService;

  static const String _lastBackupKey = 'last_backup_time';
  static const String _autoBackupEnabledKey = 'auto_backup_enabled';

  BackupService(this._prefs, this._googleDriveService);

  String? get uid => _auth.currentUser?.uid;

  // 1. Cloud Backup (To Google Drive)
  Future<void> backupToCloud({Function(double)? onProgress}) async {
    if (_auth.currentUser == null) throw Exception('User not authenticated');

    final dbPath = join(await getDatabasesPath(), 'raseed.db');
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) throw Exception('Database file not found');

    if (onProgress != null) onProgress(0.5); // Google Drive API doesn't support progress streams easily, so we show 50%
    
    await _googleDriveService.uploadBackup(dbFile);
    
    if (onProgress != null) onProgress(1.0);
    await _prefs.setString(_lastBackupKey, DateTime.now().toIso8601String());
  }

  // 2. Cloud Restore (From Google Drive)
  Future<void> restoreFromCloud() async {
    if (_auth.currentUser == null) throw Exception('User not authenticated');

    final directory = await getApplicationDocumentsDirectory();
    final tempFile = File(join(directory.path, 'temp_restore.db'));

    await _googleDriveService.downloadLatestBackup(tempFile);
    await _replaceLocalDatabase(tempFile);
  }

  // 3. Local Export (Share)
  Future<void> exportLocalBackup() async {
    final dbPath = join(await getDatabasesPath(), 'raseed.db');
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) throw Exception('Database not found');

    final tempDir = await getTemporaryDirectory();
    final backupFile = await dbFile.copy(join(tempDir.path, 'raseed_backup_${DateTime.now().millisecondsSinceEpoch}.db'));

    await Share.shareXFiles([XFile(backupFile.path)], text: 'Raseed Backup');
  }

  // 4. Local Import
  Future<void> importLocalBackup() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result != null && result.files.single.path != null) {
      final selectedFile = File(result.files.single.path!);
      await _replaceLocalDatabase(selectedFile);
    }
  }

  // Helper to replace the database
  Future<void> _replaceLocalDatabase(File sourceFile) async {
    await DatabaseHelper.instance.close();
    
    final dbPath = join(await getDatabasesPath(), 'raseed.db');
    
    final dbFile = File(dbPath);
    if (await dbFile.exists()) {
      await dbFile.copy('$dbPath.bak');
    }

    await sourceFile.copy(dbPath);
    DatabaseHelper.reset();
  }

  // Auto-backup check
  Future<void> checkAutoBackup() async {
    final enabled = _prefs.getBool(_autoBackupEnabledKey) ?? false;
    if (!enabled || _auth.currentUser == null) return;

    final lastBackupStr = _prefs.getString(_lastBackupKey);
    if (lastBackupStr != null) {
      final lastBackup = DateTime.parse(lastBackupStr);
      if (DateTime.now().difference(lastBackup).inHours < 24) return;
    }

    try {
      await backupToCloud();
    } catch (e) {
      print('Auto-backup failed: $e');
    }
  }

  DateTime? get lastBackupTime {
    final str = _prefs.getString(_lastBackupKey);
    return str != null ? DateTime.parse(str) : null;
  }

  bool get isAutoBackupEnabled => _prefs.getBool(_autoBackupEnabledKey) ?? false;

  Future<void> setAutoBackup(bool enabled) async {
    await _prefs.setBool(_autoBackupEnabledKey, enabled);
  }
}
