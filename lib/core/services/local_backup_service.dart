  import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'database_helper.dart';

class LocalBackupService {
  static const String _lastLocalBackupKey = 'last_local_backup_time';
  static const String _customBackupPathKey = 'custom_backup_path';
  static const String _dbFileName = 'raseed.db';
  static const int _keepLast = 7;

  final SharedPreferences _prefs;
  LocalBackupService(this._prefs);

  // ─── Custom Save Path ─────────────────────────────────────────────────────────

  /// Returns the currently saved custom backup path (or null if not set).
  String? get customBackupPath => _prefs.getString(_customBackupPathKey);

  /// Persists a user-chosen backup directory path.
  Future<void> setCustomBackupPath(String path) async {
    await _prefs.setString(_customBackupPathKey, path);
  }

  /// Clears the custom path and reverts to the default app documents directory.
  Future<void> clearCustomBackupPath() async {
    await _prefs.remove(_customBackupPathKey);
  }

  /// Opens a system folder-picker dialog and saves the chosen path.
  /// Returns the chosen path, or null if the user cancelled.
  Future<String?> pickAndSaveBackupPath() async {
    if (!await _requestPermissions()) {
      throw Exception('storage_permission_denied');
    }
    
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'اختر مجلد حفظ النسخ الاحتياطية',
    );
    if (selected != null) {
      await setCustomBackupPath(selected);
    }
    return selected;
  }

  // ─── Public API ───────────────────────────────────────────────────────────────

  /// Creates a compressed local backup of the database.
  /// If [customDir] is provided it overrides the stored custom path.
  /// Returns the created backup [File].
  Future<File> createLocalBackup({String? customDir}) async {
    final backupDir = await _resolveBackupDir(customDir: customDir);
    final timestamp = _formatTimestamp(DateTime.now());
    final zipPath = p.join(backupDir.path, 'backup_$timestamp.zip');

    // Step 1: Copy the DB file to a temp location
    final dbPath = p.join(await getDatabasesPath(), _dbFileName);
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) throw Exception('Database file not found');

    final tempDir = await getTemporaryDirectory();
    final tempDb = await dbFile.copy(p.join(tempDir.path, _dbFileName));

    // Step 2: Compress to ZIP
    final encoder = ZipFileEncoder();
    encoder.create(zipPath);
    encoder.addFile(tempDb);
    encoder.close();
    await tempDb.delete();

    // Step 3: Persist timestamp
    await _prefs.setString(_lastLocalBackupKey, DateTime.now().toIso8601String());

    // Step 4: Prune old backups only from the default dir (don't delete user-chosen exports)
    if (customDir == null && customBackupPath == null) {
      await deleteOldBackups();
    }

    return File(zipPath);
  }

  /// Creates a backup then shares it via the system share sheet (e.g. Save to Files / WhatsApp / etc.).
  Future<void> exportBackupWithShare() async {
    final file = await createLocalBackup();
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Raseed Backup - ${_formatTimestamp(DateTime.now())}',
    );
  }

  /// Creates a backup and saves it to a user-chosen directory.
  /// Opens a folder picker if no custom path is stored yet.
  /// Returns the saved [File].
  Future<File> createBackupToCustomLocation() async {
    if (!await _requestPermissions()) {
      throw Exception('storage_permission_denied');
    }

    String? dir = customBackupPath;
    if (dir == null) {
      dir = await pickAndSaveBackupPath();
      if (dir == null) throw Exception('no_folder_selected');
    }
    // Verify the directory still exists (SD card may have been removed etc.)
    if (!await Directory(dir).exists()) {
      throw Exception('backup_folder_not_found');
    }
    return createLocalBackup(customDir: dir);
  }

  /// Lists all local backup files from the default backup directory, sorted newest-first.
  Future<List<File>> listLocalBackups() async {
    final backupDir = await _defaultBackupDir();
    final files = backupDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.zip'))
        .toList();
    files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return files;
  }

  /// Restores the database from a local [backupFile] (zip).
  Future<void> restoreLocalBackup(File backupFile) async {
    if (!await backupFile.exists()) throw Exception('Backup file not found');

    final bytes = await backupFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final dbEntry = archive.files.firstWhere(
      (f) => f.name == _dbFileName,
      orElse: () => throw Exception('Invalid backup: $_dbFileName not found inside zip'),
    );

    await DatabaseHelper.instance.close();

    final dbPath = p.join(await getDatabasesPath(), _dbFileName);
    final dbFile = File(dbPath);

    // Safety: backup current DB before overwriting
    if (await dbFile.exists()) {
      await dbFile.copy('$dbPath.bak');
    }

    await dbFile.writeAsBytes(dbEntry.content as List<int>);
    DatabaseHelper.reset();
  }

  /// Opens a file picker for the user to choose a .zip backup file to restore.
  /// Returns the selected [File] or null if cancelled.
  Future<File?> pickBackupFileForRestore() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      dialogTitle: 'اختر ملف النسخة الاحتياطية',
    );
    if (result == null || result.files.single.path == null) return null;
    return File(result.files.single.path!);
  }

  /// Deletes old backups keeping only the latest [keepLast].
  Future<void> deleteOldBackups({int keepLast = _keepLast}) async {
    final files = await listLocalBackups();
    if (files.length > keepLast) {
      for (final old in files.sublist(keepLast)) {
        await old.delete();
      }
    }
  }

  /// Returns the [DateTime] of the last local backup, or null.
  DateTime? getLastBackupDate() {
    final str = _prefs.getString(_lastLocalBackupKey);
    return str != null ? DateTime.parse(str) : null;
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────

  /// Resolves the effective backup directory.
  /// Priority: [customDir] arg → stored custom path → default app documents dir.
  Future<Directory> _resolveBackupDir({String? customDir}) async {
    if (customDir != null) {
      final d = Directory(customDir);
      await d.create(recursive: true);
      return d;
    }
    if (customBackupPath != null) {
      final d = Directory(customBackupPath!);
      if (await d.exists()) return d;
    }
    return _defaultBackupDir();
  }

  Future<Directory> _defaultBackupDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'backups'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _formatTimestamp(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}_'
      '${dt.month.toString().padLeft(2, '0')}_'
      '${dt.day.toString().padLeft(2, '0')}_'
      '${dt.hour.toString().padLeft(2, '0')}_'
      '${dt.minute.toString().padLeft(2, '0')}';

  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      
      if (androidInfo.version.sdkInt >= 30) {
        // Android 11+ requires MANAGE_EXTERNAL_STORAGE for custom paths
        var status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
        }
        return status.isGranted;
      } else {
        // Android 10 and below
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
        return status.isGranted;
      }
    }
    return true;
  }
}
