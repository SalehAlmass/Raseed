
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/routes/routes.dart';

class BackupDashboardScreen extends StatefulWidget {
  const BackupDashboardScreen({super.key});

  @override
  State<BackupDashboardScreen> createState() => _BackupDashboardScreenState();
}

class _BackupDashboardScreenState extends State<BackupDashboardScreen> {
  final BackupService _backupService = sl<BackupService>();
  final AuthService _authService = sl<AuthService>();
  bool _isLoading = false;
  double _progress = 0;
  bool _isDriveAuthorized = false;
  bool _checkingStatus = true;

  @override
  void initState() {
    super.initState();
    _checkDriveStatus();
  }

  Future<void> _checkDriveStatus() async {
    final status = await _authService.isGoogleDriveAuthorized();
    if (mounted) {
      setState(() {
        _isDriveAuthorized = status;
        _checkingStatus = false;
      });
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
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserSection(user),
            SizedBox(height: 30.h),
            _buildDriveSection(user != null),
            SizedBox(height: 30.h),
            _buildLocalSection(),
            SizedBox(height: 30.h),
            _buildAutoBackupToggle(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserSection(user) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25.r,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.person, color: Colors.white, size: 30.sp),
          ),
          SizedBox(width: 15.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user != null ? user.email ?? 'Connected Account' : 'guest_mode'.tr(),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
                ),
                if (_checkingStatus)
                  SizedBox(height: 5.h, child: LinearProgressIndicator(minHeight: 2.h))
                else
                  Text(
                    _isDriveAuthorized ? 'drive_active'.tr() : 'drive_disconnected'.tr(),
                    style: TextStyle(color: _isDriveAuthorized ? Colors.green : Colors.orange, fontSize: 12.sp),
                  ),
              ],
            ),
          ),
          if (user == null)
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, Routes.auth),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: Text('login'.tr()),
            )
          else 
            Row(
              children: [
                if (!_isDriveAuthorized && !_checkingStatus)
                   IconButton(
                    icon: const Icon(Icons.link_off, color: Colors.orange),
                    onPressed: _handleConnectDrive,
                    tooltip: 'connect_drive'.tr(),
                  ),
                IconButton(
                  icon: const Icon(Icons.logout, color: AppColors.error),
                  onPressed: () async {
                    await _authService.logout();
                    setState(() {});
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDriveSection(bool isLogged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('cloud_backup'.tr(), Icons.add_to_drive_outlined),
        if (!isLogged) ...[
          SizedBox(height: 10.h),
          Text('login_to_sync'.tr(), style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
        ] else if (!_isDriveAuthorized && !_checkingStatus) ...[
           SizedBox(height: 15.h),
           SizedBox(
             width: double.infinity,
             child: ElevatedButton.icon(
               onPressed: _handleConnectDrive,
               icon: const Icon(Icons.add_to_drive),
               label: Text('connect_drive'.tr()),
               style: ElevatedButton.styleFrom(
                 backgroundColor: Colors.orange,
                 foregroundColor: Colors.white,
                 padding: EdgeInsets.symmetric(vertical: 12.h),
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
               ),
             ),
           ),
        ],
        SizedBox(height: 15.h),
        _buildActionCard(
          title: 'backup_cloud_drive'.tr(),
          subtitle: 'backup_drive_desc'.tr(),
          icon: Icons.cloud_upload_outlined,
          onTap: (isLogged && _isDriveAuthorized) ? _handleDriveBackup : null,
          color: AppColors.success,
          loading: _isLoading,
          progress: _progress,
        ),
        SizedBox(height: 12.h),
        _buildActionCard(
          title: 'restore_latest'.tr(),
          subtitle: 'restore_drive_desc'.tr(),
          icon: Icons.cloud_download_outlined,
          onTap: (isLogged && _isDriveAuthorized) ? _handleDriveRestore : null,
          color: AppColors.info,
        ),
        if (isLogged && _backupService.lastBackupTime != null)
          Padding(
            padding: EdgeInsets.only(top: 10.h, left: 10.w),
            child: Text(
              '${'last_sync'.tr()}: ${DateFormat('yyyy-MM-dd HH:mm').format(_backupService.lastBackupTime!)}',
              style: TextStyle(fontSize: 11.sp, color: Colors.grey),
            ),
          ),
      ],
    );
  }

  Widget _buildLocalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('local_backup'.tr(), Icons.sd_storage_outlined),
        SizedBox(height: 15.h),
        _buildActionCard(
          title: 'export_to_phone'.tr(),
          subtitle: 'export_local_desc'.tr(),
          icon: Icons.share_rounded,
          onTap: _handleLocalExport,
          color: Colors.blueGrey,
        ),
        SizedBox(height: 12.h),
        _buildActionCard(
          title: 'import_from_phone'.tr(),
          subtitle: 'import_local_desc'.tr(),
          icon: Icons.file_open_outlined,
          onTap: _handleLocalImport,
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildAutoBackupToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15.r),
      ),
      child: SwitchListTile(
        title: Text('auto_sync_daily'.tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
        subtitle: Text('auto_sync_desc'.tr(), style: TextStyle(fontSize: 12.sp)),
        value: _backupService.isAutoBackupEnabled,
        onChanged: (val) async {
          await _backupService.setAutoBackup(val);
          setState(() {});
        },
        activeColor: AppColors.primary,
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
    required Color color,
    bool loading = false,
    double progress = 0,
  }) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(15.r),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
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
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12.r)),
                  child: Icon(icon, color: color),
                ),
                SizedBox(width: 15.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                      Text(subtitle, style: TextStyle(fontSize: 11.sp, color: Colors.grey)),
                      if (loading && progress > 0)
                        Padding(
                          padding: EdgeInsets.only(top: 8.h),
                          child: LinearProgressIndicator(value: progress, color: color, backgroundColor: color.withOpacity(0.2)),
                        ),
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18.sp, color: AppColors.primary),
        SizedBox(width: 8.w),
        Text(title, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: AppColors.primary)),
      ],
    );
  }

  // Action Handlers
  Future<void> _handleConnectDrive() async {
    try {
      final success = await _authService.connectGoogleDrive();
      if (success) {
        await _checkDriveStatus();
      }
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('google_api_config_error')) {
        _showError(errorMsg.replaceAll('Exception: ', '').tr());
      } else {
        _showError(errorMsg);
      }
    }
  }

  Future<void> _handleDriveBackup() async {
    setState(() {
      _isLoading = true;
      _progress = 0.1;
    });
    try {
      await _backupService.backupToCloud(onProgress: (p) => setState(() => _progress = p));
      _showSuccess('backup_success'.tr());
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('google_drive_disconnected') || errorMsg.contains('drive_permission_denied')) {
        _showError(errorMsg.replaceAll('Exception: ', '').tr());
        await _checkDriveStatus();
      } else {
        _showError(errorMsg);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDriveRestore() async {
    final confirm = await _showConfirmDialog('restore_cloud_confirm'.tr(), 'restore_warning'.tr());
    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      await _backupService.restoreFromCloud();
      _showSuccess('restore_success'.tr());
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLocalExport() async {
    try {
      await _backupService.exportLocalBackup();
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _handleLocalImport() async {
    final confirm = await _showConfirmDialog('restore_local_confirm'.tr(), 'restore_warning'.tr());
    if (!confirm) return;

    try {
      await _backupService.importLocalBackup();
      _showSuccess('restore_success'.tr());
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.error));

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
    ) ?? false;
  }
}
