import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'local_backup_service.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

class GoogleDriveBackupService {
  static const String _lastDriveBackupKey = 'last_drive_backup_time';
  static const String _backupFolderName = 'Raseed Backups';
  static const int _keepLast = 7;

  final SharedPreferences _prefs;
  final LocalBackupService _localBackupService;
  final AuthService _authService;

  GoogleDriveBackupService(this._prefs, this._localBackupService, this._authService);

  bool get isLoggedIn => _authService.googleUser != null;

  Future<drive.DriveApi?> _getDriveApi({bool forceSignIn = false}) async {
    var user = _authService.googleUser;
    
    // Attempt silent sign-in if no current user
    if (user == null) {
      user = await _authService.googleSignIn.signInSilently();
    }
    
    // Force UI sign-in if requested and still null
    if (user == null && forceSignIn) {
      user = await _authService.googleSignIn.signIn();
    }
    
    if (user == null) return null;

    final headers = await user.authHeaders;
    final client = GoogleAuthClient(headers);
    return drive.DriveApi(client);
  }

  /// Finds or creates the app backup folder in Google Drive
  Future<String?> _getOrCreateBackupFolder(drive.DriveApi driveApi) async {
    try {
      final query = "mimeType='application/vnd.google-apps.folder' and name='$_backupFolderName' and trashed=false";
      final folderList = await driveApi.files.list(q: query, spaces: 'drive');
      
      if (folderList.files != null && folderList.files!.isNotEmpty) {
        return folderList.files!.first.id;
      }

      // Create folder
      final folder = drive.File()
        ..name = _backupFolderName
        ..mimeType = 'application/vnd.google-apps.folder';
      
      final createdFolder = await driveApi.files.create(folder);
      return createdFolder.id;
    } catch (e) {
      debugPrint('[DriveBackup] Folder error: $e');
      return null;
    }
  }

  // ─── Upload ───────────────────────────────────────────────────────────────

  Future<void> uploadBackupToDrive(
    File localBackupFile, {
    Function(double)? onProgress,
  }) async {
    try {
      final driveApi = await _getDriveApi(forceSignIn: true);
      if (driveApi == null) throw Exception('Google Drive not authenticated');

      if (!await localBackupFile.exists()) throw Exception('Backup file not found');

      final folderId = await _getOrCreateBackupFolder(driveApi);
      if (folderId == null) throw Exception('Could not access or create backup folder');

      final fileName = p.basename(localBackupFile.path);

      final fileToUpload = drive.File()
        ..name = fileName
        ..parents = [folderId];

      final fileLength = await localBackupFile.length();
      final media = drive.Media(localBackupFile.openRead(), fileLength);

      // Simulate progress since driveApi doesn't expose byte streams directly easily
      onProgress?.call(0.5);

      await driveApi.files.create(fileToUpload, uploadMedia: media);
      
      onProgress?.call(1.0);
      await _prefs.setString(_lastDriveBackupKey, DateTime.now().toIso8601String());

      // Prune old
      await deleteOldDriveBackups();
    } catch (e) {
      debugPrint('[DriveBackup] upload error: $e');
      if (e.toString().contains('ApiException: 7')) {
        throw Exception('Network error during Google Sign-In. Please check your internet connection or emulator settings.');
      }
      rethrow;
    }
  }

  // ─── List ─────────────────────────────────────────────────────────────────

  Future<List<drive.File>> listDriveBackups() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return [];

      final folderId = await _getOrCreateBackupFolder(driveApi);
      if (folderId == null) return [];

      final query = "'$folderId' in parents and trashed=false and mimeType!='application/vnd.google-apps.folder'";
      
      final fileList = await driveApi.files.list(
        q: query, 
        spaces: 'drive',
        orderBy: 'createdTime desc',
        $fields: 'files(id, name, createdTime, size)',
      );

      return fileList.files ?? [];
    } catch (e) {
      debugPrint('[DriveBackup] list error: $e');
      return [];
    }
  }

  // ─── Download & Restore ───────────────────────────────────────────────────

  Future<void> restoreFromDriveBackup(
    drive.File driveFile, {
    Function(double)? onProgress,
  }) async {
    try {
      final driveApi = await _getDriveApi(forceSignIn: true);
      if (driveApi == null) throw Exception('Google Drive not authenticated');

      final tempDir = await getTemporaryDirectory();
      final tempZip = File(p.join(tempDir.path, 'drive_restore.zip'));

      onProgress?.call(0.2);

      final media = await driveApi.files.get(driveFile.id!, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
      
      final sink = tempZip.openWrite();
      await media.stream.pipe(sink);

      onProgress?.call(0.7);

      await _localBackupService.restoreLocalBackup(tempZip);
      onProgress?.call(1.0);

      await tempZip.delete();
    } catch (e) {
      debugPrint('[DriveBackup] restore error: $e');
      if (e.toString().contains('ApiException: 7')) {
        throw Exception('Network error during Google Sign-In. Please check your internet connection or emulator settings.');
      }
      rethrow;
    }
  }

  // ─── Delete Old ───────────────────────────────────────────────────────────

  Future<void> deleteOldDriveBackups({int keepLast = _keepLast}) async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return;

      final backups = await listDriveBackups();
      if (backups.length > keepLast) {
        for (final old in backups.sublist(keepLast)) {
          if (old.id != null) {
            await driveApi.files.delete(old.id!);
          }
        }
      }
    } catch (e) {
      debugPrint('[DriveBackup] delete error: $e');
    }
  }

  DateTime? getLastDriveBackupDate() {
    final str = _prefs.getString(_lastDriveBackupKey);
    return str != null ? DateTime.parse(str) : null;
  }

  Future<void> createAndUpload({Function(double)? onProgress}) async {
    onProgress?.call(0.0);
    final localFile = await _localBackupService.createLocalBackup();
    onProgress?.call(0.3);
    await uploadBackupToDrive(
      localFile,
      onProgress: (p) => onProgress?.call(0.3 + p * 0.7),
    );
  }
}
