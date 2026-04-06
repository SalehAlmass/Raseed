import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/models/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = sl<SettingsService>();
  late AppSettings _settings;
  bool _isLoading = true;

  final TextEditingController _maxDebtController = TextEditingController();
  final TextEditingController _reminderDaysController = TextEditingController();

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
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final newSettings = _settings.copyWith(
      maxDebt: double.tryParse(_maxDebtController.text) ?? _settings.maxDebt,
      reminderDays: int.tryParse(_reminderDaysController.text) ?? _settings.reminderDays,
    );
    await _settingsService.updateSettings(newSettings);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
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
                SizedBox(height: 20.h),
                _buildSectionHeader('currency'.tr()),
                SizedBox(height: 15.h),
                _buildCurrencyDropdown(),
                SizedBox(height: 30.h),
                _buildSectionHeader('language'.tr()),
                SizedBox(height: 15.h),
                _buildLanguageDropdown(context),
                SizedBox(height: 30.h),
                _buildSectionHeader('Advanced'),
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
                const Spacer(),
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

  Widget _buildCurrencyDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15.r),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _settings.currency,
          isExpanded: true,
          icon: Icon(Icons.money, color: AppColors.primary, size: 20.sp),
          items: [
            DropdownMenuItem(
              value: 'YER',
              child: Text('yemeni_rial'.tr(), style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
            ),
            DropdownMenuItem(
              value: 'SAR',
              child: Text('saudi_riyal'.tr(), style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
            ),
          ],
          onChanged: (String? newVal) {
            if (newVal != null) {
              setState(() {
                _settings = _settings.copyWith(currency: newVal);
              });
            }
          },
        ),
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
}
