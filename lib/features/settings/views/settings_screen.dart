import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/routes/routes.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = sl<SettingsService>();
  final AuthService _authService = sl<AuthService>();
  late AppSettings _settings;
  bool _isLoading = true;

  final TextEditingController _maxDebtController = TextEditingController();
  final TextEditingController _reminderDaysController = TextEditingController();
  final TextEditingController _vipThresholdController = TextEditingController();
  final TextEditingController _inactiveDaysController = TextEditingController();
  final TextEditingController _deadDaysController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsService.getSettings();
    setState(() {
      _settings = settings;
      _maxDebtController.text = settings.maxDebt.toString();
      _reminderDaysController.text = settings.reminderDays.toString();
      _vipThresholdController.text = settings.vipThreshold.toString();
      _inactiveDaysController.text = settings.inactiveDays.toString();
      _deadDaysController.text = settings.deadDays.toString();
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final newSettings = _settings.copyWith(
      maxDebt: double.tryParse(_maxDebtController.text) ?? _settings.maxDebt,
      reminderDays: int.tryParse(_reminderDaysController.text) ?? _settings.reminderDays,
      vipThreshold: double.tryParse(_vipThresholdController.text) ?? _settings.vipThreshold,
      inactiveDays: int.tryParse(_inactiveDaysController.text) ?? _settings.inactiveDays,
      deadDays: int.tryParse(_deadDaysController.text) ?? _settings.deadDays,
    );
    await _settingsService.updateSettings(newSettings);
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('settings_saved_success'.tr(), style: TextStyle(color: Colors.white),),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          
        ),);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('settings'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: EdgeInsets.all(20.w),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('merchant_config'.tr()),
                  SizedBox(height: 15.h),
                  _buildSettingTile(
                    label: 'max_debt_limit'.tr(),
                    controller: _maxDebtController,
                    icon: Icons.money_off,
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 20.h),
                   _buildSettingTile(
                    label: 'reminder_days'.tr(),
                    controller: _reminderDaysController,
                    icon: Icons.notification_important_outlined,
                    keyboardType: TextInputType.number,
                  ),
              
                  SizedBox(height: 30.h),
                  _buildSectionHeader('crm_config'.tr()),
                  SizedBox(height: 15.h),
                  _buildSettingTile(
                    label: 'vip_threshold'.tr(),
                    controller: _vipThresholdController,
                    icon: Icons.star_border_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 15.h),
                  _buildSettingTile(
                    label: 'inactive_days'.tr(),
                    controller: _inactiveDaysController,
                    icon: Icons.timer_outlined,
                    keyboardType: TextInputType.number,
                  ),
                   SizedBox(height: 15.h),
                  _buildSettingTile(
                    label: 'dead_days'.tr(),
                    controller: _deadDaysController,
                    icon: Icons.hourglass_empty,
                    keyboardType: TextInputType.number,
                  ),
              
                  SizedBox(height: 30.h),
                  _buildSectionHeader('language'.tr()),
                  SizedBox(height: 15.h),
                  _buildLanguageDropdown(context),
                  SizedBox(height: 30.h),
                  _buildSectionHeader('about'.tr()),
                  SizedBox(height: 15.h),
                  _buildAboutTile(context),
                  SizedBox(height: 30.h),
                  _buildSectionHeader('account_backup'.tr()),
                  SizedBox(height: 15.h),
                  _buildBackupTile(context),
              
                  SizedBox(height: 30.h),
                  _buildSectionHeader('subscription'.tr()),
                  SizedBox(height: 15.h),
                  _buildSubscriptionTile(context),
              
                   SizedBox(height: 30.h),
                  _buildSectionHeader('account'.tr()),
                  SizedBox(height: 15.h),
                  _buildLogoutTile(context),
              
                  SizedBox(height: 30.h),
                  _buildSectionHeader('advanced'.tr()),
                  SwitchListTile(
                    title: Text('strict_mode'.tr()),
                    subtitle: Text('strict_mode_desc'.tr()),
                    value: _settings.strictMode,
                    onChanged: (val) {
                      setState(() {
                        _settings = _settings.copyWith(strictMode: val);
                      });
                    },
                    activeColor: AppColors.primary,
                  ),
                  SwitchListTile(
                    title: Text('enable_whatsapp_notification'.tr()),
                    subtitle: Text('enable_whatsapp_notification_desc'.tr()),
                    value: _settings.enableWhatsapp,
                    onChanged: (val) {
                      setState(() {
                        _settings = _settings.copyWith(enableWhatsapp: val);
                      });
                    },
                    activeColor: AppColors.primary,
                  ),
                  SwitchListTile(
                    title: Text('enable_pdf_receipt_prompt'.tr()),
                    subtitle: Text('enable_pdf_receipt_prompt_desc'.tr()),
                    value: _settings.enablePdfReceipt,
                    onChanged: (val) {
                      setState(() {
                        _settings = _settings.copyWith(enablePdfReceipt: val);
                      });
                    },
                    activeColor: AppColors.primary,
                  ),
                  SizedBox(height: 40.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 15.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15.r),
                        ),
                      ),
                      child: Text('save_changes'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildSettingTile({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      padding: EdgeInsets.all(15.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15.r),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary),
          SizedBox(width: 15.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey, fontSize: 12.sp)),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  keyboardType: keyboardType,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildLanguageDropdown(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15.r),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Locale>(
          value: context.locale,
          isExpanded: true,
          icon: Icon(Icons.language, color: AppColors.primary, size: 20.sp),
          items: [
            DropdownMenuItem(
              value: const Locale('en'),
              child: Text('english'.tr(), style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
            ),
            DropdownMenuItem(
              value: const Locale('ar'),
              child: Text('arabic'.tr(), style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
            ),
          ],
          onChanged: (Locale? newLocale) {
            if (newLocale != null) {
              context.setLocale(newLocale);
            }
          },
        ),
      ),
    );
  }

  Widget _buildAboutTile(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15.r),
      ),
      child: ListTile(
        leading: Icon(Icons.info_outline, color: AppColors.primary),
        title: Text('about'.tr(), style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
        trailing: Icon(Icons.arrow_forward_ios, color: AppColors.textSecondary, size: 16.sp),
        onTap: () {
          Navigator.of(context).pushNamed(Routes.about);
        },
      ),
    );
  }

  Widget _buildBackupTile(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15.r),
      ),
      child: ListTile(
        leading: Icon(Icons.cloud_sync_outlined, color: AppColors.primary),
        title: Text('account_backup'.tr(), style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
        trailing: Icon(Icons.arrow_forward_ios, color: AppColors.textSecondary, size: 16.sp),
        onTap: () {
          Navigator.of(context).pushNamed(Routes.backup);
        },
      ),
    );
  }

  Widget _buildSubscriptionTile(BuildContext context) {
    final subService = sl<SubscriptionService>();
    final isPremium = subService.isSubscribed;
    final remaining = subService.remainingDays;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15.r),
      ),
      child: ListTile(
        leading: Icon(
          isPremium ? Icons.star_rounded : Icons.star_outline_rounded,
          color: isPremium ? Colors.amber : AppColors.primary,
        ),
        title: Text('subscription'.tr(), style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
        subtitle: Text(
          isPremium 
            ? 'full_version'.tr() 
            : 'trial_remaining'.tr(namedArgs: {'days': remaining.toString()}),
          style: TextStyle(fontSize: 12.sp, color: isPremium ? Colors.amber : Colors.grey),
        ),
        trailing: Icon(Icons.arrow_forward_ios, color: AppColors.textSecondary, size: 16.sp),
        onTap: () {
          Navigator.of(context).pushNamed(Routes.subscription).then((_) => setState(() {}));
        },
      ),
    );
  }

  Widget _buildLogoutTile(BuildContext context) {
    final user = _authService.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15.r),
      ),
      child: ListTile(
        leading: const Icon(Icons.logout, color: AppColors.error),
        title: Text('logout'.tr(), style:  TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppColors.error)),
        subtitle: Text(user.email ?? '', style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
        onTap: () async {
          await _authService.logout();
          setState(() {});
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('logout_success'.tr())),
            );
          }
        },
      ),
    );
  }
}
