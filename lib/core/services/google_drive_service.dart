
import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:path/path.dart' as p;

class GoogleDriveService {
  final GoogleSignIn _googleSignIn;

  GoogleDriveService(this._googleSignIn);

  Future<drive.DriveApi?> _getDriveApi() async {
    // 1. Silent sign in to ensure we have the latest tokens
    var account = _googleSignIn.currentUser;
    account ??= await _googleSignIn.signInSilently();
    
    if (account == null) {
      throw Exception('google_drive_disconnected');
    }

    // 2. Verify if the required scope was granted
    final String driveScope = 'https://www.googleapis.com/auth/drive.file';
    final hasScope = await _googleSignIn.canAccessScopes([driveScope]);
    if (!hasScope) {
      throw Exception('drive_permission_denied');
    }

    final client = await _googleSignIn.authenticatedClient();
    if (client == null) return null;
    return drive.DriveApi(client);
  }

  /// Uploads the database file to Google Drive.
  /// Overwrites the previous backup if it exists to keep it "Latest Only"
  Future<void> uploadBackup(File file) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) throw Exception('Failed to get Drive API client');

    // 1. Check if a backup already exists
    final query = "name = 'raseed_backup.db' and mimeType = 'application/x-sqlite3' and trashed = false";
    final fileList = await driveApi.files.list(q: query, spaces: 'drive');
    
    final driveFile = drive.File()
      ..name = 'raseed_backup.db'
      ..description = 'Raseed Application Database Backup';

    final media = drive.Media(file.openRead(), file.lengthSync());

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      // Update existing file
      final existingFileId = fileList.files!.first.id!;
      await driveApi.files.update(driveFile, existingFileId, uploadMedia: media);
    } else {
      // Create new file
      await driveApi.files.create(driveFile, uploadMedia: media);
    }
  }

  /// Downloads the latest backup file from Google Drive to a destination file.
  Future<void> downloadLatestBackup(File destinationFile) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) throw Exception('Failed to get Drive API client');

    // 1. Find the file
    final query = "name = 'raseed_backup.db' and trashed = false";
    final fileList = await driveApi.files.list(q: query, spaces: 'drive');

    if (fileList.files == null || fileList.files!.isEmpty) {
      throw Exception('No backup found on Google Drive');
    }

    final fileId = fileList.files!.first.id!;
    
    // 2. Download content
    final media = await driveApi.files.get(fileId, downloadOptions: drive.DownloadOptions.metadata) as drive.Media;
    
    final List<int> content = [];
    await for (final data in media.stream) {
      content.addAll(data);
    }
    
    await destinationFile.writeAsBytes(content);
  }

  /// Returns info about the latest backup
  Future<Map<String, dynamic>?> getLatestBackupInfo() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) return null;

    final query = "name = 'raseed_backup.db' and trashed = false";
    final fileList = await driveApi.files.list(q: query, spaces: 'drive', $fields: 'files(id, name, modifiedTime, size)');

    if (fileList.files == null || fileList.files!.isEmpty) return null;

    final file = fileList.files!.first;
    return {
      'id': file.id,
      'name': file.name,
      'modifiedTime': file.modifiedTime,
      'size': file.size,
    };
  }
}
