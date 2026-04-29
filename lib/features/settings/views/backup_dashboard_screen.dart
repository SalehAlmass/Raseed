import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firebase_backup_service.dart';
import '../../../core/services/local_backup_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/routes/routes.dart';

class BackupDashboardScreen extends StatefulWidget {
  const BackupDashboardScreen({super.key});

  @override
  State<BackupDashboardScreen> createState() => _BackupDashboardScreenState();
}

class _BackupDashboardScreenState extends State<BackupDashboardScreen> {
  final LocalBackupService _localBackup = sl<LocalBackupService>();
  final FirebaseBackupService _firebaseBackup = sl<FirebaseBackupService>();
  final AuthService _authService = sl<AuthService>();

  bool _isLoading = false;
  double _progress = 0;
  String _statusMsg = '';

  List<File> _localBackups = [];
  List<Reference> _cloudBackups = [];

  @override
  void initState() {
    super.initState();
    // Defer to after the first frame so the UI renders immediately (avoids ANR)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadBackupLists();
    });
  }

  Future<void> _loadBackupLists() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // Local I/O — fast
      _localBackups = await _localBackup.listLocalBackups();

      // Firebase network call — add timeout to avoid blocking UI for too long
      if (_firebaseBackup.isLoggedIn) {
        try {
          _cloudBackups = await _firebaseBackup
              .listFirebaseBackups()
              .timeout(const Duration(seconds: 8));
        } catch (_) {
          _cloudBackups = [];
        }
      }
    } catch (e) {
      debugPrint('[BackupScreen] load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('backup_management'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: _isLoading
          ? Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(value: _progress > 0 ? _progress : null),
                if (_statusMsg.isNotEmpty) ...[
                  SizedBox(height: 12.h),
                  Text(_statusMsg, style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
                ],
              ],
            ))
          : RefreshIndicator(
              onRefresh: _loadBackupLists,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 20.h, bottom: 100.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUserSection(user),
                    SizedBox(height: 24.h),
                    _buildQuickActions(user),
                    SizedBox(height: 24.h),
                    _buildLocalBackupSection(),
                    SizedBox(height: 24.h),
                    _buildCloudBackupSection(user != null),
                  ],
                ),
              ),
            ),
    );
  }

  // ─── User Section ──────────────────────────────────────────────────────────

  Widget _buildUserSection(user) {
    final isLoggedIn = user != null;
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLoggedIn
              ? [AppColors.primary.withOpacity(0.15), AppColors.primary.withOpacity(0.05)]
              : [Colors.orange.withOpacity(0.15), Colors.orange.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: (isLoggedIn ? AppColors.primary : Colors.orange).withOpacity(0.25),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24.r,
            backgroundColor: isLoggedIn ? AppColors.primary : Colors.orange,
            child: Icon(
              isLoggedIn ? Icons.person : Icons.person_off_outlined,
              color: Colors.white, size: 26.sp,
            ),
          ),
          SizedBox(width: 15.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoggedIn ? (user.email ?? 'signed_in'.tr()) : 'guest_mode'.tr(),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp),
                ),
                SizedBox(height: 2.h),
                Text(
                  isLoggedIn ? 'cloud_backup_enabled'.tr() : 'login_to_enable_cloud_backup'.tr(),
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: isLoggedIn ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          if (!isLoggedIn)
            ElevatedButton(
              onPressed: () async {
                await Navigator.pushNamed(context, Routes.auth);
                _loadBackupLists();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: Text('login'.tr(), style: TextStyle(fontSize: 12.sp)),
            )
          else
            IconButton(
              icon: const Icon(Icons.logout, color: AppColors.error),
              tooltip: 'logout'.tr(),
              onPressed: () async {
                await _authService.logout();
                if (mounted) setState(() => _cloudBackups = []);
              },
            ),
        ],
      ),
    );
  }

  // ─── Quick Actions ─────────────────────────────────────────────────────────

  Widget _buildQuickActions(user) {
    final isLoggedIn = user != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('quick_actions'.tr(), Icons.bolt_outlined),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.save_alt_outlined,
                label: 'create_local_backup'.tr(),
                color: Colors.blueGrey,
                onTap: _handleLocalBackup,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.cloud_sync_outlined,
                label: 'local_and_cloud'.tr(),
                color: AppColors.primary,
                enabled: isLoggedIn,
                onTap: isLoggedIn ? _handleCreateAndUpload : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Local Backup Section ──────────────────────────────────────────────────

  Widget _buildLocalBackupSection() {
    final lastDate = _localBackup.getLastBackupDate();
    final customPath = _localBackup.customBackupPath;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('local_backup'.tr(), Icons.sd_storage_outlined),
        if (lastDate != null)
          Padding(
            padding: EdgeInsets.only(top: 4.h, bottom: 8.h, left: 4.w),
            child: Text(
              '${'last_sync'.tr()}: ${DateFormat('yyyy-MM-dd HH:mm').format(lastDate)}',
              style: TextStyle(fontSize: 11.sp, color: Colors.grey),
            ),
          )
        else
          SizedBox(height: 12.h),
        // ── Save Location Card ──
        _buildSaveLocationCard(customPath),
        SizedBox(height: 10.h),
        _ActionCard(
          title: 'create_local_backup'.tr(),
          subtitle: 'create_local_backup_desc'.tr(),
          icon: Icons.save_outlined,
          color: Colors.blueGrey,
          onTap: _handleLocalBackup,
        ),
        SizedBox(height: 10.h),
        _ActionCard(
          title: 'save_to_custom_location'.tr(),
          subtitle: customPath != null
              ? _shortenPath(customPath)
              : 'save_to_custom_location_desc'.tr(),
          icon: Icons.drive_folder_upload_outlined,
          color: Colors.teal,
          onTap: _handleBackupToCustomLocation,
        ),
        SizedBox(height: 10.h),
        _ActionCard(
          title: 'export_backup_share'.tr(),
          subtitle: 'export_backup_share_desc'.tr(),
          icon: Icons.share_outlined,
          color: Colors.deepPurple,
          onTap: _handleExportWithShare,
        ),
        SizedBox(height: 10.h),
        _ActionCard(
          title: 'restore_from_local'.tr(),
          subtitle: 'restore_from_local_desc'.tr(),
          icon: Icons.settings_backup_restore_outlined,
          color: Colors.orange,
          onTap: () => _showRestoreOptions(),
        ),
        if (_localBackups.isNotEmpty) ...[
          SizedBox(height: 12.h),
          _buildLocalBackupList(),
        ],
      ],
    );
  }

  Widget _buildSaveLocationCard(String? customPath) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: customPath != null
              ? Colors.teal.withOpacity(0.35)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: (customPath != null ? Colors.teal : Colors.grey).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              customPath != null ? Icons.folder_special_outlined : Icons.folder_outlined,
              color: customPath != null ? Colors.teal : Colors.grey,
              size: 20.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'backup_save_location'.tr(),
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2.h),
                Text(
                  customPath != null ? _shortenPath(customPath) : 'backup_default_location'.tr(),
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: customPath != null ? Colors.teal : Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: _handlePickBackupFolder,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  foregroundColor: Colors.teal,
                ),
                child: Text(
                  customPath != null ? 'change'.tr() : 'choose'.tr(),
                  style: TextStyle(fontSize: 11.sp),
                ),
              ),
              if (customPath != null)
                IconButton(
                  icon: Icon(Icons.close, size: 16.sp, color: Colors.grey),
                  onPressed: () async {
                    await _localBackup.clearCustomBackupPath();
                    setState(() {});
                  },
                  tooltip: 'reset_to_default'.tr(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _shortenPath(String path) {
    final parts = path.replaceAll('\\', '/').split('/');
    if (parts.length <= 3) return path;
    return '.../${parts.sublist(parts.length - 2).join('/')}';
  }

  Widget _buildLocalBackupList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8.h),
          child: Text(
            'available_backups'.tr(),
            style: TextStyle(fontSize: 12.sp, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ),
        ..._localBackups.take(5).map((f) {
          final name = f.path.split('/').last;
          final stat = f.statSync();
          final sizeKb = (stat.size / 1024).toStringAsFixed(1);
          return Container(
            margin: EdgeInsets.only(bottom: 6.h),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.folder_zip_outlined, color: Colors.blueGrey),
              title: Text(name, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500)),
              subtitle: Text('$sizeKb KB  •  ${DateFormat('dd/MM/yyyy HH:mm').format(stat.modified)}',
                  style: TextStyle(fontSize: 10.sp)),
              trailing: IconButton(
                icon: const Icon(Icons.restore, color: AppColors.primary, size: 20),
                onPressed: () => _handleRestoreLocal(f),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ─── Cloud Backup Section ──────────────────────────────────────────────────

  Widget _buildCloudBackupSection(bool isLoggedIn) {
    final lastDate = _firebaseBackup.getLastCloudBackupDate();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('cloud_backup'.tr(), Icons.cloud_outlined),
        if (!isLoggedIn)
          Container(
            margin: EdgeInsets.only(top: 10.h),
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.orange.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, color: Colors.orange),
                SizedBox(width: 10.w),
                Expanded(child: Text('login_to_enable_cloud_backup'.tr(),
                    style: TextStyle(fontSize: 12.sp, color: Colors.orange))),
              ],
            ),
          )
        else ...[
          if (lastDate != null)
            Padding(
              padding: EdgeInsets.only(top: 4.h, bottom: 8.h, left: 4.w),
              child: Text(
                '${'last_sync'.tr()}: ${DateFormat('yyyy-MM-dd HH:mm').format(lastDate)}',
                style: TextStyle(fontSize: 11.sp, color: Colors.grey),
              ),
            )
          else
            SizedBox(height: 12.h),
          _ActionCard(
            title: 'upload_to_firebase'.tr(),
            subtitle: 'upload_to_firebase_desc'.tr(),
            icon: Icons.cloud_upload_outlined,
            color: AppColors.success,
            onTap: _handleFirebaseUpload,
          ),
          SizedBox(height: 10.h),
          _ActionCard(
            title: 'restore_from_cloud'.tr(),
            subtitle: 'restore_from_cloud_desc'.tr(),
            icon: Icons.cloud_download_outlined,
            color: AppColors.info,
            onTap: _cloudBackups.isEmpty ? null : () => _showCloudRestoreSheet(),
          ),
          if (_cloudBackups.isNotEmpty) ...[
            SizedBox(height: 12.h),
            _buildCloudBackupList(),
          ],
        ],
      ],
    );
  }

  Widget _buildCloudBackupList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8.h),
          child: Text(
            'available_cloud_backups'.tr(),
            style: TextStyle(fontSize: 12.sp, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ),
        ..._cloudBackups.take(5).map((ref) {
          final name = ref.name;
          return Container(
            margin: EdgeInsets.only(bottom: 6.h),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.cloud_circle_outlined, color: AppColors.primary),
              title: Text(name, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500)),
              trailing: IconButton(
                icon: const Icon(Icons.restore, color: AppColors.primary, size: 20),
                onPressed: () => _handleRestoreCloud(ref),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ─── Action Handlers ───────────────────────────────────────────────────────

  Future<void> _handleLocalBackup() async {
    await _runWithLoading(() async {
      setState(() => _statusMsg = 'creating_backup'.tr());
      await _localBackup.createLocalBackup();
      _showSuccess('backup_success'.tr());
      await _loadBackupLists();
    });
  }

  Future<void> _handlePickBackupFolder() async {
    final chosen = await _localBackup.pickAndSaveBackupPath();
    if (chosen != null && mounted) {
      setState(() {});
      _showSuccess('backup_folder_saved'.tr());
    }
  }

  Future<void> _handleBackupToCustomLocation() async {
    await _runWithLoading(() async {
      setState(() => _statusMsg = 'creating_backup'.tr());
      final file = await _localBackup.createBackupToCustomLocation();
      _showSuccess('${'backup_success'.tr()} → ${_shortenPath(file.path)}');
      await _loadBackupLists();
    });
  }

  Future<void> _handleExportWithShare() async {
    await _runWithLoading(() async {
      setState(() => _statusMsg = 'creating_backup'.tr());
      await _localBackup.exportBackupWithShare();
    });
  }

  void _showRestoreOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Text('restore_from_local'.tr(),
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.list_alt_outlined, color: Colors.blueGrey),
            title: Text('restore_from_saved_list'.tr()),
            onTap: () {
              Navigator.pop(context);
              if (_localBackups.isNotEmpty) _showLocalRestoreSheet();
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_open_outlined, color: Colors.orange),
            title: Text('restore_from_file'.tr()),
            onTap: () {
              Navigator.pop(context);
              _handlePickFileAndRestore();
            },
          ),
          SizedBox(height: 10.h),
        ],
      ),
    );
  }

  Future<void> _handlePickFileAndRestore() async {
    final file = await _localBackup.pickBackupFileForRestore();
    if (file == null) return;
    final confirm = await _showConfirmDialog(
        'restore_local_confirm'.tr(), 'restore_warning'.tr());
    if (!confirm) return;
    await _runWithLoading(() async {
      await _localBackup.restoreLocalBackup(file);
      _showRestartMessage();
    });
  }

  Future<void> _handleFirebaseUpload() async {
    final localFiles = await _localBackup.listLocalBackups();
    if (localFiles.isEmpty) {
      // Create a fresh local backup first then upload
      await _handleCreateAndUpload();
      return;
    }
    await _runWithLoading(() async {
      setState(() => _statusMsg = 'uploading_to_cloud'.tr());
      await _firebaseBackup.uploadBackupToFirebase(
        localFiles.first,
        onProgress: (p) => setState(() => _progress = p),
      );
      _showSuccess('backup_success'.tr());
      await _loadBackupLists();
    });
  }

  Future<void> _handleCreateAndUpload() async {
    await _runWithLoading(() async {
      setState(() => _statusMsg = 'creating_backup'.tr());
      await _firebaseBackup.createAndUpload(
        onProgress: (p) => setState(() {
          _progress = p;
          _statusMsg = p < 0.35 ? 'creating_backup'.tr() : 'uploading_to_cloud'.tr();
        }),
      );
      _showSuccess('backup_success'.tr());
      await _loadBackupLists();
    });
  }

  Future<void> _handleRestoreLocal(File file) async {
    final confirm = await _showConfirmDialog(
        'restore_local_confirm'.tr(), 'restore_warning'.tr());
    if (!confirm) return;
    await _runWithLoading(() async {
      await _localBackup.restoreLocalBackup(file);
      _showRestartMessage();
    });
  }

  Future<void> _handleRestoreCloud(Reference ref) async {
    final confirm = await _showConfirmDialog(
        'restore_cloud_confirm'.tr(), 'restore_warning'.tr());
    if (!confirm) return;
    await _runWithLoading(() async {
      setState(() => _statusMsg = 'downloading_backup'.tr());
      await _firebaseBackup.restoreFromFirebaseBackup(
        ref,
        onProgress: (p) => setState(() => _progress = p),
      );
      _showRestartMessage();
    });
  }

  void _showLocalRestoreSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (_) => _BackupListSheet(
        title: 'restore_from_local'.tr(),
        items: _localBackups.map((f) => f.path.split('/').last).toList(),
        onSelect: (idx) {
          Navigator.pop(context);
          _handleRestoreLocal(_localBackups[idx]);
        },
      ),
    );
  }

  void _showCloudRestoreSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (_) => _BackupListSheet(
        title: 'restore_from_cloud'.tr(),
        items: _cloudBackups.map((r) => r.name).toList(),
        onSelect: (idx) {
          Navigator.pop(context);
          _handleRestoreCloud(_cloudBackups[idx]);
        },
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _runWithLoading(Future<void> Function() action) async {
    setState(() {
      _isLoading = true;
      _progress = 0;
      _statusMsg = '';
    });
    try {
      await action();
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      _showError(msg);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _progress = 0;
          _statusMsg = '';
        });
      }
    }
  }

  void _showRestartMessage() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('restore_success'.tr()),
        content: Text('restart_required'.tr()),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ok'.tr()),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text('cancel'.tr())),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: Text('proceed'.tr()),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.green),
      );

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.error),
      );

  Widget _sectionHeader(String title, IconData icon) => Row(
        children: [
          Icon(icon, size: 18.sp, color: AppColors.primary),
          SizedBox(width: 8.w),
          Text(title, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: AppColors.primary)),
        ],
      );
}

// ─── Sub-Widgets ──────────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(15.r),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15.r),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12.r)),
                  child: Icon(icon, color: color),
                ),
                SizedBox(width: 15.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                      Text(subtitle, style: TextStyle(fontSize: 11.sp, color: Colors.grey)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool enabled;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Container(
        height: 85.h,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15.r),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15.r),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28.sp),
              SizedBox(height: 6.h),
              Text(label, textAlign: TextAlign.center, style: TextStyle(
                fontSize: 11.sp, fontWeight: FontWeight.bold, color: color,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackupListSheet extends StatelessWidget {
  final String title;
  final List<String> items;
  final void Function(int index) onSelect;

  const _BackupListSheet({required this.title, required this.items, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.8,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Text(title, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
          ),
          const Divider(),
          Expanded(
            child: ListView.separated(
              controller: controller,
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: Text(items[i], style: TextStyle(fontSize: 13.sp)),
                onTap: () => onSelect(i),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
