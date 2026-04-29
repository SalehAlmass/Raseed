import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import 'local_backup_service.dart';

class FirebaseBackupService {
  static const String _lastCloudBackupKey = 'last_cloud_backup_time';
  static const String _dbFileName = 'raseed.db';
  static const int _keepLast = 7;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final SharedPreferences _prefs;
  final LocalBackupService _localBackupService;

  FirebaseBackupService(this._prefs, this._localBackupService);

  // ─── Auth Helpers ─────────────────────────────────────────────────────────

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw Exception('user_not_authenticated');
    return user.uid;
  }

  bool get isLoggedIn => _auth.currentUser != null;
  User? get currentUser => _auth.currentUser;

  // ─── Upload ───────────────────────────────────────────────────────────────

  /// Uploads a local backup zip [file] to Firebase Storage.
  /// Path: backups/{userId}/backup_yyyy_MM_dd_HH_mm.zip
  Future<void> uploadBackupToFirebase(
    File localBackupFile, {
    Function(double)? onProgress,
  }) async {
    final uid = _uid;
    if (!await localBackupFile.exists()) throw Exception('Backup file not found');

    final fileName = p.basename(localBackupFile.path);
    final ref = _storage.ref('backups/$uid/$fileName');

    final task = ref.putFile(localBackupFile);

    task.snapshotEvents.listen((snapshot) {
      if (onProgress != null) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress(progress);
      }
    });

    await task;
    await _prefs.setString(_lastCloudBackupKey, DateTime.now().toIso8601String());

    // Prune old cloud backups
    await deleteOldFirebaseBackups();
  }

  // ─── List ─────────────────────────────────────────────────────────────────

  /// Lists all cloud backup files for the current user, newest-first.
  Future<List<Reference>> listFirebaseBackups() async {
    final uid = _uid;
    final result = await _storage.ref('backups/$uid').listAll();
    final items = result.items.toList();
    // Sort newest-first using metadata
    final withMeta = await Future.wait(
      items.map((ref) async => MapEntry(ref, await ref.getMetadata())),
    );
    withMeta.sort((a, b) =>
        (b.value.updated ?? DateTime(0)).compareTo(a.value.updated ?? DateTime(0)));
    return withMeta.map((e) => e.key).toList();
  }

  // ─── Download & Restore ───────────────────────────────────────────────────

  /// Downloads a Firebase backup [ref] and restores the database from it.
  Future<void> restoreFromFirebaseBackup(
    Reference ref, {
    Function(double)? onProgress,
  }) async {
    // Step 1: Download to a temp file
    final tempDir = await getTemporaryDirectory();
    final tempZip = File(p.join(tempDir.path, 'firebase_restore.zip'));

    final task = ref.writeToFile(tempZip);
    task.snapshotEvents.listen((snapshot) {
      if (onProgress != null) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress(progress * 0.7); // 70% for download
      }
    });
    await task;

    // Step 2: Extract and restore
    await _localBackupService.restoreLocalBackup(tempZip);
    onProgress?.call(1.0);

    // Step 3: Clean up temp
    await tempZip.delete();
  }

  // ─── Delete Old ───────────────────────────────────────────────────────────

  /// Deletes old Firebase backups keeping only the latest [keepLast].
  Future<void> deleteOldFirebaseBackups({int keepLast = _keepLast}) async {
    try {
      final backups = await listFirebaseBackups();
      if (backups.length > keepLast) {
        for (final old in backups.sublist(keepLast)) {
          await old.delete();
        }
      }
    } catch (_) {
      // Don't fail the backup process if cleanup fails
    }
  }

  // ─── Convenience ─────────────────────────────────────────────────────────

  /// Last cloud backup timestamp.
  DateTime? getLastCloudBackupDate() {
    final str = _prefs.getString(_lastCloudBackupKey);
    return str != null ? DateTime.parse(str) : null;
  }

  /// Creates a local backup then uploads it to Firebase in one call.
  Future<void> createAndUpload({Function(double)? onProgress}) async {
    onProgress?.call(0.0);
    final localFile = await _localBackupService.createLocalBackup();
    onProgress?.call(0.3); // 30% after local backup done
    await uploadBackupToFirebase(
      localFile,
      onProgress: (p) => onProgress?.call(0.3 + p * 0.7),
    );
  }
}
