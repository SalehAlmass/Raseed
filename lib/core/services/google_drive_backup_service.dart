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
  static const String _backupFolderName = 'تاجر ماس Backups';
  static const int _keepLast = 7;

  final SharedPreferences _prefs;
  final LocalBackupService _localBackupService;
  final AuthService _authService;

  GoogleDriveBackupService(this._prefs, this._localBackupService, this._authService);

  bool get isLoggedIn => _authService.googleUser != null;

  Future<drive.DriveApi?> _getDriveApi({bool forceSignIn = false}) async {
    try {
      var user = _authService.googleUser;
      
      debugPrint('[DriveBackup] Checking Google User: Current user is ${user?.email}');
      
      // Attempt silent sign-in if no current user
      if (user == null) {
        debugPrint('[DriveBackup] Google User is null. Attempting silent sign-in...');
        user = await _authService.googleSignIn.signInSilently();
        debugPrint('[DriveBackup] Silent sign-in result: ${user?.email}');
      }
      
      // Force UI sign-in if requested and still null
      if (user == null && forceSignIn) {
        debugPrint('[DriveBackup] Google User still null. Forcing interactive sign-in UI...');
        user = await _authService.googleSignIn.signIn();
        debugPrint('[DriveBackup] Interactive sign-in UI result: ${user?.email}');
      }
      
      if (user == null) {
        debugPrint('[DriveBackup] Error: User cancelled or failed to log in to Google (user is null).');
        throw Exception('فشل تسجيل الدخول: لم يتم اختيار حساب أو تم إلغاء العملية (Google user is null)');
      }

      debugPrint('[DriveBackup] User successfully authenticated. Fetching authHeaders...');
      final headers = await user.authHeaders;
      debugPrint('[DriveBackup] authHeaders successfully fetched. Initializing DriveApi...');
      final client = GoogleAuthClient(headers);
      return drive.DriveApi(client);
    } catch (e) {
      debugPrint('[DriveBackup] _getDriveApi error: $e');
      final errorStr = e.toString();
      if (errorStr.contains('ApiException: 10') || errorStr.contains('10:')) {
        throw Exception('خطأ في إعدادات المطور (ApiException 10): بصمة الـ SHA-1 الخاصة بجهازك غير مسجلة في Google Cloud Console أو أن اسم الحزمة com.example.rseed غير متطابق.');
      } else if (errorStr.contains('ApiException: 7') || errorStr.contains('7:')) {
        throw Exception('خطأ في الشبكة (ApiException 7): يرجى التحقق من اتصالك بالإنترنت.');
      } else if (errorStr.contains('ApiException: 12500') || errorStr.contains('12500:')) {
        throw Exception('تم إلغاء عملية تسجيل الدخول أو فشلت تهيئة الخدمات (ApiException 12500).');
      } else if (errorStr.contains('sign_in_failed')) {
        throw Exception('فشل تسجيل الدخول بجوجل (sign_in_failed): تأكد من صحة إعدادات مشروع جوجل كلاود وربط بصمة الـ SHA-1.');
      }
      rethrow;
    }
  }

  /// Finds or creates the app backup folder in Google Drive
  Future<String?> _getOrCreateBackupFolder(drive.DriveApi driveApi) async {
    try {
      debugPrint('[DriveBackup] Checking for folder named "$_backupFolderName" in Google Drive...');
      final query = "mimeType='application/vnd.google-apps.folder' and name='$_backupFolderName' and trashed=false";
      final folderList = await driveApi.files.list(q: query, spaces: 'drive');
      
      if (folderList.files != null && folderList.files!.isNotEmpty) {
        final folderId = folderList.files!.first.id;
        debugPrint('[DriveBackup] Found existing backup folder in Google Drive. ID: $folderId');
        return folderId;
      }

      debugPrint('[DriveBackup] Backup folder not found. Creating a new one...');
      // Create folder
      final folder = drive.File()
        ..name = _backupFolderName
        ..mimeType = 'application/vnd.google-apps.folder';
      
      final createdFolder = await driveApi.files.create(folder);
      debugPrint('[DriveBackup] Successfully created new backup folder in Google Drive. ID: ${createdFolder.id}');
      return createdFolder.id;
    } catch (e) {
      debugPrint('[DriveBackup] Folder management error: $e');
      if (e is drive.DetailedApiRequestError) {
        throw Exception('خطأ خوادم جوجل كلاود [${e.status}]: ${e.message}');
      }
      throw Exception('فشل الوصول أو إنشاء مجلد النسخ الاحتياطي في جوجل درايف: $e');
    }
  }

  // ─── Upload ───────────────────────────────────────────────────────────────

  Future<void> uploadBackupToDrive(
    File localBackupFile, {
    Function(double)? onProgress,
  }) async {
    try {
      debugPrint('[DriveBackup] Starting upload sequence for: ${localBackupFile.path}');
      final driveApi = await _getDriveApi(forceSignIn: true);
      if (driveApi == null) throw Exception('Google Drive not authenticated');

      if (!await localBackupFile.exists()) {
        debugPrint('[DriveBackup] Error: Local backup file not found at ${localBackupFile.path}');
        throw Exception('ملف النسخة الاحتياطية المحلية غير موجود');
      }

      final folderId = await _getOrCreateBackupFolder(driveApi);
      if (folderId == null) throw Exception('Could not access or create backup folder');

      final fileName = p.basename(localBackupFile.path);
      debugPrint('[DriveBackup] Uploading file named "$fileName" to folder ID: $folderId...');

      final fileToUpload = drive.File()
        ..name = fileName
        ..parents = [folderId];

      final fileLength = await localBackupFile.length();
      debugPrint('[DriveBackup] File length to upload: $fileLength bytes');
      final media = drive.Media(localBackupFile.openRead(), fileLength);

      onProgress?.call(0.5);
      debugPrint('[DriveBackup] Transferring bytes to Google Drive...');
      final uploadedFile = await driveApi.files.create(fileToUpload, uploadMedia: media);
      debugPrint('[DriveBackup] Successfully uploaded! File ID in Google Drive: ${uploadedFile.id}');
      
      onProgress?.call(1.0);
      await _prefs.setString(_lastDriveBackupKey, DateTime.now().toIso8601String());

      // Prune old
      debugPrint('[DriveBackup] Cleaning up old backups in Google Drive...');
      await deleteOldDriveBackups();
    } catch (e) {
      debugPrint('[DriveBackup] upload error: $e');
      if (e is drive.DetailedApiRequestError) {
        throw Exception('فشل الرفع لجوجل درايف [كود ${e.status}]: ${e.message}');
      }
      final errorStr = e.toString();
      if (errorStr.contains('ApiException: 7') || errorStr.contains('7:')) {
        throw Exception('خطأ في الشبكة (ApiException 7): يرجى التحقق من اتصالك بالإنترنت.');
      } else if (errorStr.contains('ApiException: 10') || errorStr.contains('10:')) {
        throw Exception('خطأ في إعدادات المطور (ApiException 10): بصمة الـ SHA-1 الخاصة بجهازك غير مسجلة في Google Cloud Console.');
      }
      rethrow;
    }
  }

  // ─── List ─────────────────────────────────────────────────────────────────

  Future<List<drive.File>> listDriveBackups() async {
    try {
      debugPrint('[DriveBackup] Fetching backup list from Google Drive...');
      final driveApi = await _getDriveApi();
      if (driveApi == null) {
        debugPrint('[DriveBackup] Cannot list backups: DriveApi is null (user is not logged in).');
        return [];
      }

      final folderId = await _getOrCreateBackupFolder(driveApi);
      if (folderId == null) {
        debugPrint('[DriveBackup] Cannot list backups: FolderId is null.');
        return [];
      }

      final query = "'$folderId' in parents and trashed=false and mimeType!='application/vnd.google-apps.folder'";
      
      debugPrint('[DriveBackup] Listing files in folder ID: $folderId...');
      final fileList = await driveApi.files.list(
        q: query, 
        spaces: 'drive',
        orderBy: 'createdTime desc',
        $fields: 'files(id, name, createdTime, size)',
      );

      debugPrint('[DriveBackup] Found ${(fileList.files ?? []).length} backups in Google Drive.');
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
      debugPrint('[DriveBackup] Starting download/restore sequence for file: ${driveFile.name} (ID: ${driveFile.id})');
      final driveApi = await _getDriveApi(forceSignIn: true);
      if (driveApi == null) throw Exception('Google Drive not authenticated');

      final tempDir = await getTemporaryDirectory();
      final tempZip = File(p.join(tempDir.path, 'drive_restore.zip'));
      debugPrint('[DriveBackup] Created temporary restore file at: ${tempZip.path}');

      onProgress?.call(0.2);
      debugPrint('[DriveBackup] Fetching file stream from Google Drive...');
      final media = await driveApi.files.get(driveFile.id!, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
      
      debugPrint('[DriveBackup] Writing stream to temporary file...');
      final sink = tempZip.openWrite();
      await media.stream.pipe(sink);
      debugPrint('[DriveBackup] Download complete. Restoring database...');

      onProgress?.call(0.7);

      await _localBackupService.restoreLocalBackup(tempZip);
      onProgress?.call(1.0);

      debugPrint('[DriveBackup] Database successfully restored! Cleaning up temp ZIP...');
      await tempZip.delete();
    } catch (e) {
      debugPrint('[DriveBackup] restore error: $e');
      if (e is drive.DetailedApiRequestError) {
        throw Exception('فشل التنزيل من جوجل درايف [كود ${e.status}]: ${e.message}');
      }
      final errorStr = e.toString();
      if (errorStr.contains('ApiException: 7') || errorStr.contains('7:')) {
        throw Exception('خطأ في الشبكة (ApiException 7): يرجى التحقق من اتصالك بالإنترنت.');
      }
      rethrow;
    }
  }

  // ─── Delete Old ───────────────────────────────────────────────────────────

  Future<void> deleteOldDriveBackups({int keepLast = _keepLast}) async {
    try {
      debugPrint('[DriveBackup] Checking for old cloud backups to prune. Keeping last $keepLast...');
      final driveApi = await _getDriveApi();
      if (driveApi == null) return;

      final backups = await listDriveBackups();
      if (backups.length > keepLast) {
        final toDelete = backups.sublist(keepLast);
        debugPrint('[DriveBackup] Found ${toDelete.length} old backups to prune.');
        for (final old in toDelete) {
          if (old.id != null) {
            debugPrint('[DriveBackup] Pruning old backup from Google Drive: ${old.name} (ID: ${old.id})');
            await driveApi.files.delete(old.id!);
          }
        }
        debugPrint('[DriveBackup] Pruning complete.');
      } else {
        debugPrint('[DriveBackup] No old backups to prune.');
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
    debugPrint('[DriveBackup] Triggered createAndUpload. Creating fresh local backup...');
    final localFile = await _localBackupService.createLocalBackup();
    onProgress?.call(0.3);
    await uploadBackupToDrive(
      localFile,
      onProgress: (p) => onProgress?.call(0.3 + p * 0.7),
    );
  }
}
