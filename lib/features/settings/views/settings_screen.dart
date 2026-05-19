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
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/widgets/pin_auth_dialog.dart';

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
  bool _isDeveloperMode = false;
  int _tapCount = 0;

  final TextEditingController _maxDebtController = TextEditingController();
  final TextEditingController _reminderDaysController = TextEditingController();
  final TextEditingController _vipThresholdController = TextEditingController();
  final TextEditingController _inactiveDaysController = TextEditingController();
  final TextEditingController _deadDaysController = TextEditingController();
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _storePhoneController = TextEditingController();
  final TextEditingController _storeAddressController = TextEditingController();
  final TextEditingController _storeTaxNumberController = TextEditingController();

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
      _storeNameController.text = settings.storeProfile.storeName ?? '';
      _storePhoneController.text = settings.storeProfile.phone ?? '';
      _storeAddressController.text = settings.storeProfile.address ?? '';
      _storeTaxNumberController.text = settings.storeProfile.taxNumber ?? '';
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
      storeProfile: _settings.storeProfile.copyWith(
        storeName: _storeNameController.text,
        phone: _storePhoneController.text,
        address: _storeAddressController.text,
        taxNumber: _storeTaxNumberController.text,
      ),
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
        title: GestureDetector(
          onTap: _handleDevModeTap,
          child: Text('settings'.tr()),
        ),
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
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Merchant Config Section
                  _buildAccordionSection(
                    title: 'merchant_config'.tr(),
                    icon: Icons.storefront_rounded,
                    children: [
                      _buildSettingTile(
                        label: 'max_debt_limit'.tr(),
                        controller: _maxDebtController,
                        icon: Icons.money_off,
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 12.h),
                      _buildSettingTile(
                        label: 'reminder_days'.tr(),
                        controller: _reminderDaysController,
                        icon: Icons.notification_important_outlined,
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        context.locale.languageCode == 'ar' ? 'إجراء تجاوز حد الدين' : 'Action on Exceeding Debt Limit',
                        style: TextStyle(color: Colors.grey, fontSize: 12.sp),
                      ),
                      SizedBox(height: 6.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 5.h),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(15.r),
                          border: Border.all(color: Colors.grey.withOpacity(0.15)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<DebtMode>(
                            value: _settings.debtMode,
                            isExpanded: true,
                            icon: Icon(Icons.security, color: AppColors.primary, size: 20.sp),
                            items: [
                              DropdownMenuItem(
                                value: DebtMode.block,
                                child: Text(
                                  context.locale.languageCode == 'ar' ? 'حظر البيع (منع المعاملة)' : 'Block Sale (Strict)',
                                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
                                ),
                              ),
                              DropdownMenuItem(
                                value: DebtMode.warning,
                                child: Text(
                                  context.locale.languageCode == 'ar' ? 'تحذير فقط (السماح بالبيع)' : 'Warning Only (Allow)',
                                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                            onChanged: (DebtMode? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _settings = _settings.copyWith(debtMode: newValue);
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      _buildInventoryFieldsTile(context),
                      if (_isDeveloperMode) ...[
                        SizedBox(height: 12.h),
                        _buildModuleManagementTile(context),
                      ],
                    ],
                  ),

                  // 2. Store Profile Section
                  _buildAccordionSection(
                    title: 'store_profile'.tr(),
                    icon: Icons.store_rounded,
                    children: [
                      _buildStoreProfileSection(),
                    ],
                  ),

                  // 3. CRM Config Section
                  _buildAccordionSection(
                    title: 'crm_config'.tr(),
                    icon: Icons.people_outline_rounded,
                    children: [
                      _buildSettingTile(
                        label: 'vip_threshold'.tr(),
                        controller: _vipThresholdController,
                        icon: Icons.star_border_rounded,
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 12.h),
                      _buildSettingTile(
                        label: 'inactive_days'.tr(),
                        controller: _inactiveDaysController,
                        icon: Icons.timer_outlined,
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 12.h),
                      _buildSettingTile(
                        label: 'dead_days'.tr(),
                        controller: _deadDaysController,
                        icon: Icons.hourglass_empty,
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),

                  // 4. Print & PDF Settings Section
                  _buildAccordionSection(
                    title: context.locale.languageCode == 'ar' ? 'إعدادات الطباعة والـ PDF' : 'Print & PDF Settings',
                    icon: Icons.print_rounded,
                    children: [
                      Text('pdf_page_format'.tr(), style: TextStyle(color: Colors.grey, fontSize: 12.sp)),
                      SizedBox(height: 6.h),
                      _buildPdfPageFormatDropdown(context),
                      SizedBox(height: 16.h),
                      Text('receipt_width'.tr(), style: TextStyle(color: Colors.grey, fontSize: 12.sp)),
                      SizedBox(height: 6.h),
                      _buildReceiptWidthDropdown(context),
                      SizedBox(height: 12.h),
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
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),

                  // 5. Advanced & Staff Mode Section
                  _buildAccordionSection(
                    title: 'advanced'.tr(),
                    icon: Icons.admin_panel_settings_rounded,
                    children: [
                      _buildStaffModeSection(),
                      SizedBox(height: 16.h),
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
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(),
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
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),

                  // 6. General & Account Section
                  _buildAccordionSection(
                    title: context.locale.languageCode == 'ar' ? 'الإعدادات العامة والحساب' : 'General & Account Settings',
                    icon: Icons.settings_rounded,
                    children: [
                      Text('language'.tr(), style: TextStyle(color: Colors.grey, fontSize: 12.sp)),
                      SizedBox(height: 6.h),
                      _buildLanguageDropdown(context),
                      SizedBox(height: 16.h),
                      _buildBackupTile(context),
                      SizedBox(height: 12.h),
                      _buildAboutTile(context),
                      if (_isDeveloperMode) ...[
                        SizedBox(height: 12.h),
                        _buildSubscriptionTile(context),
                      ],
                      SizedBox(height: 16.h),
                      _buildLogoutTile(context),
                    ],
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

  Widget _buildAccordionSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          leading: Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20.sp),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          iconColor: AppColors.primary,
          collapsedIconColor: AppColors.textSecondary,
          childrenPadding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 20.h),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  Widget _buildStoreProfileSection() {
    return Column(
      children: [
        Center(
          child: Stack(
            children: [
              Container(
                width: 100.w,
                height: 100.w,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 2),
                  image: _settings.storeProfile.logoPath != null
                      ? DecorationImage(
                          image: FileImage(File(_settings.storeProfile.logoPath!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _settings.storeProfile.logoPath == null
                    ? Icon(Icons.store_rounded, size: 40.sp, color: Colors.grey)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickLogo,
                  child: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.camera_alt_rounded, size: 16.sp, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 20.h),
        _buildSettingTile(
          label: 'store_name'.tr(),
          controller: _storeNameController,
          icon: Icons.business_rounded,
        ),
        SizedBox(height: 10.h),
        _buildSettingTile(
          label: 'phone_number'.tr(),
          controller: _storePhoneController,
          icon: Icons.phone_rounded,
          keyboardType: TextInputType.phone,
        ),
        SizedBox(height: 10.h),
        _buildSettingTile(
          label: 'address'.tr(),
          controller: _storeAddressController,
          icon: Icons.location_on_rounded,
        ),
        SizedBox(height: 10.h),
        _buildSettingTile(
          label: 'tax_number'.tr(),
          controller: _storeTaxNumberController,
          icon: Icons.receipt_long_rounded,
        ),
      ],
    );
  }

  Widget _buildStaffModeSection() {
    return Container(
      padding: EdgeInsets.all(15.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15.r),
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: Text('staff_mode'.tr()),
            subtitle: Text('staff_mode_desc'.tr()),
            value: _settings.staffConfig.isEnabled,
            onChanged: (val) async {
              if (val) {
                // When enabling, must set PIN
                _showSetPinDialog();
              } else {
                // When disabling, verify existing PIN
                final verified = await showDialog<bool>(
                  context: context,
                  builder: (context) => PinAuthDialog(correctPin: _settings.staffConfig.pinCode ?? '0000'),
                );
                if (verified == true) {
                  setState(() {
                    _settings = _settings.copyWith(
                      staffConfig: StaffConfig(isEnabled: false, pinCode: _settings.staffConfig.pinCode),
                    );
                  });
                }
              }
            },
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
          ),
          if (_settings.staffConfig.isEnabled) ...[
            const Divider(),
            ListTile(
              title: Text('change_pin'.tr()),
              leading: const Icon(Icons.pin_rounded),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _showSetPinDialog,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _settings = _settings.copyWith(
          storeProfile: _settings.storeProfile.copyWith(logoPath: image.path),
        );
      });
    }
  }

  void _handleDevModeTap() {
    _tapCount++;
    if (_tapCount >= 7) {
      _tapCount = 0;
      _showDevAuthDialog();
    }
  }

  void _showDevAuthDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Developer Portal'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Enter Admin Key'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
          ElevatedButton(
            onPressed: () {
              if (controller.text == '8899') {
                setState(() => _isDeveloperMode = true);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Developer Mode Enabled')),
                );
              }
            },
            child: Text('confirm'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text == '8899') {
                await sl<SubscriptionService>().activateSubscription();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Premium Activated Successfully'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  setState(() {}); // Refresh UI
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800]),
            child: const Text('Activate Premium'),
          ),
        ],
      ),
    );
  }


  void _showSetPinDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('set_staff_pin'.tr()),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'xxxx',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
          ElevatedButton(
            onPressed: () {
              if (controller.text.length == 4) {
                setState(() {
                  _settings = _settings.copyWith(
                    staffConfig: StaffConfig(isEnabled: true, pinCode: controller.text),
                  );
                });
                Navigator.pop(context);
              }
            },
            child: Text('save'.tr()),
          ),
        ],
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

  Widget _buildInventoryFieldsTile(BuildContext context) {
    return InkWell(
      onTap: () => _showInventoryFieldsDialog(context),
      borderRadius: BorderRadius.circular(15.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15.r),
          border: Border.all(color: AppColors.primary.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(Icons.tune_rounded, color: AppColors.primary, size: 24.sp),
            SizedBox(width: 15.w),
            Expanded(
              child: Text(
                'manage_inventory_fields'.tr(),
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: AppColors.primary, size: 16.sp),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleManagementTile(BuildContext context) {
    return InkWell(
      onTap: () => _showModuleManagementDialog(context),
      borderRadius: BorderRadius.circular(15.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15.r),
          border: Border.all(color: AppColors.primary.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(Icons.dashboard_customize_rounded, color: AppColors.primary, size: 24.sp),
            SizedBox(width: 15.w),
            Expanded(
              child: Text(
                'manage_modules_features'.tr(),
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: AppColors.primary, size: 16.sp),
          ],
        ),
      ),
    );
  }

  Future<void> _showModuleManagementDialog(BuildContext context) async {
    final config = _settings.moduleConfig;
    
    bool showInventory = config.showInventory;
    bool showCustomers = config.showCustomers;
    bool showSuppliers = config.showSuppliers;
    bool showSales = config.showSales;
    bool showReports = config.showReports;
    bool showAccounting = config.showAccounting;
    bool enableCloudBackup = config.enableCloudBackup;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
              title: Text('manage_modules_features'.tr(), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('select_template'.tr(), style: TextStyle(fontSize: 12.sp, color: Colors.grey, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: [
                        _templateBtn('template_retail', () => setState(() {
                          showInventory = true; showCustomers = true; showSuppliers = true; showSales = true; showReports = true; showAccounting = true; enableCloudBackup = true;
                        }), setState),
                        _templateBtn('template_services', () => setState(() {
                          showInventory = false; showCustomers = true; showSuppliers = false; showSales = true; showReports = true; showAccounting = true; enableCloudBackup = true;
                        }), setState),
                        _templateBtn('template_cash', () => setState(() {
                          showInventory = true; showCustomers = false; showSuppliers = false; showSales = true; showReports = true; showAccounting = false; enableCloudBackup = true;
                        }), setState),
                        _templateBtn('template_debts', () => setState(() {
                          showInventory = false; showCustomers = true; showSuppliers = false; showSales = false; showReports = false; showAccounting = false; enableCloudBackup = true;
                        }), setState),
                        _templateBtn('template_warehouse', () => setState(() {
                          showInventory = true; showCustomers = false; showSuppliers = true; showSales = false; showReports = false; showAccounting = false; enableCloudBackup = true;
                        }), setState),
                      ],
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: Text('show_inventory'.tr()),
                      value: showInventory,
                      onChanged: (val) => setState(() => showInventory = val),
                      activeColor: AppColors.primary,
                    ),
                    SwitchListTile(
                      title: Text('show_customers'.tr()),
                      value: showCustomers,
                      onChanged: (val) => setState(() => showCustomers = val),
                      activeColor: AppColors.primary,
                    ),
                    SwitchListTile(
                      title: Text('show_suppliers'.tr()),
                      value: showSuppliers,
                      onChanged: (val) => setState(() => showSuppliers = val),
                      activeColor: AppColors.primary,
                    ),
                    SwitchListTile(
                      title: Text('show_sales'.tr()),
                      value: showSales,
                      onChanged: (val) => setState(() => showSales = val),
                      activeColor: AppColors.primary,
                    ),
                    SwitchListTile(
                      title: Text('show_reports'.tr()),
                      value: showReports,
                      onChanged: (val) => setState(() => showReports = val),
                      activeColor: AppColors.primary,
                    ),
                    SwitchListTile(
                      title: Text('show_accounting'.tr()),
                      value: showAccounting,
                      onChanged: (val) => setState(() => showAccounting = val),
                      activeColor: AppColors.primary,
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: Text('enable_cloud_backup'.tr()),
                      subtitle: Text(enableCloudBackup ? 'cloud_mode'.tr() : 'local_mode'.tr()),
                      value: enableCloudBackup,
                      onChanged: (val) => setState(() => enableCloudBackup = val),
                      activeColor: AppColors.primary,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('cancel'.tr(), style: const TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newConfig = ModuleConfig(
                      showInventory: showInventory,
                      showCustomers: showCustomers,
                      showSuppliers: showSuppliers,
                      showSales: showSales,
                      showReports: showReports,
                      showAccounting: showAccounting,
                      enableCloudBackup: enableCloudBackup,
                    );
                    this.setState(() {
                      _settings = _settings.copyWith(moduleConfig: newConfig);
                    });
                    _settingsService.updateSettings(_settings);
                    Navigator.pop(context);
                  },
                  child: Text('save'.tr()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _templateBtn(String label, VoidCallback onSelected, StateSetter setState) {
    return ActionChip(
      label: Text(label.tr(), style: TextStyle(fontSize: 11.sp)),
      onPressed: onSelected,
      backgroundColor: AppColors.primary.withOpacity(0.1),
      labelStyle: const TextStyle(color: AppColors.primary),
      padding: EdgeInsets.zero,
    );
  }
  Future<void> _showInventoryFieldsDialog(BuildContext context) async {
    final config = _settings.productFormConfig;
    
    // We create local state variables for the dialog
    bool showBarcode = config.showBarcode;
    bool showWholesale = config.showWholesale;
    bool showReorder = config.showReorder;
    bool showCategory = config.showCategory;
    bool showExpiry = config.showExpiry;
    bool showUnits = config.showUnits;
    bool showSupplier = config.showSupplier;
    bool showPurchasePrice = config.showPurchasePrice;
    
    final saleMarginCtrl = TextEditingController(text: (config.autoSaleMargin * 100).toStringAsFixed(0));
    final wholesaleMarginCtrl = TextEditingController(text: (config.autoWholesaleMargin * 100).toStringAsFixed(0));

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
              title: Text('manage_inventory_fields'.tr(), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      title: Text('show_barcode_field'.tr()),
                      value: showBarcode,
                      onChanged: (val) => setState(() => showBarcode = val),
                      activeColor: AppColors.primary,
                    ),
                    SwitchListTile(
                      title: Text('show_wholesale_price_field'.tr()),
                      value: showWholesale,
                      onChanged: (val) => setState(() => showWholesale = val),
                      activeColor: AppColors.primary,
                    ),
                    SwitchListTile(
                      title: Text('show_reorder_level_field'.tr()),
                      value: showReorder,
                      onChanged: (val) => setState(() => showReorder = val),
                      activeColor: AppColors.primary,
                    ),
                    SwitchListTile(
                      title: Text('show_category_field'.tr()),
                      value: showCategory,
                      onChanged: (val) => setState(() => showCategory = val),
                      activeColor: AppColors.primary,
                    ),
                    SwitchListTile(
                      title: Text('show_expiry_field'.tr()),
                      value: showExpiry,
                      onChanged: (val) => setState(() => showExpiry = val),
                      activeColor: AppColors.primary,
                    ),
                    SwitchListTile(
                      title: Text('show_units_field'.tr()),
                      value: showUnits,
                      onChanged: (val) => setState(() => showUnits = val),
                      activeColor: AppColors.primary,
                    ),
                    SwitchListTile(
                      title: Text('show_purchase_price_field'.tr()),
                      value: showPurchasePrice,
                      onChanged: (val) => setState(() => showPurchasePrice = val),
                      activeColor: AppColors.primary,
                    ),
                    SwitchListTile(
                      title: Text('show_supplier_field'.tr()),
                      value: showSupplier,
                      onChanged: (val) => setState(() => showSupplier = val),
                      activeColor: AppColors.primary,
                    ),
                    const Divider(),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      child: Row(
                        children: [
                          Expanded(child: Text('auto_sale_margin'.tr())),
                          SizedBox(
                            width: 60.w,
                            child: TextField(
                              controller: saleMarginCtrl,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(isDense: true),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      child: Row(
                        children: [
                          Expanded(child: Text('auto_wholesale_margin'.tr())),
                          SizedBox(
                            width: 60.w,
                            child: TextField(
                              controller: wholesaleMarginCtrl,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(isDense: true),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('cancel'.tr(), style: const TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Update settings state
                    final newConfig = ProductFormConfig(
                      showBarcode: showBarcode,
                      showWholesale: showWholesale,
                      showReorder: showReorder,
                      showCategory: showCategory,
                      showExpiry: showExpiry,
                      showUnits: showUnits,
                      showSupplier: showSupplier,
                      showPurchasePrice: showPurchasePrice,
                      autoSaleMargin: (double.tryParse(saleMarginCtrl.text) ?? 15) / 100.0,
                      autoWholesaleMargin: (double.tryParse(wholesaleMarginCtrl.text) ?? 10) / 100.0,
                    );
                    this.setState(() {
                      _settings = _settings.copyWith(productFormConfig: newConfig);
                    });
                    _saveSettings();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                  ),
                  child: Text('save'.tr()),
                ),
              ],
            );
          },
        );
      },
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
              // Update settings to sync language preference
              final newSettings = _settings.copyWith(languageCode: newLocale.languageCode);
              _settingsService.updateSettings(newSettings);
            }
          },
        ),
      ),
    );
  }

  Widget _buildPdfPageFormatDropdown(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15.r),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _settings.pdfPageFormat,
          isExpanded: true,
          icon: Icon(Icons.picture_as_pdf, color: AppColors.primary, size: 20.sp),
          items: [
            DropdownMenuItem(
              value: 'A4',
              child: Text(
                context.locale.languageCode == 'ar' ? 'A4 (حجم كبير افتراضي)' : 'A4 (Standard Large)',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
              ),
            ),
            DropdownMenuItem(
              value: 'A5',
              child: Text(
                context.locale.languageCode == 'ar' ? 'A5 (حجم متوسط للدفاتر)' : 'A5 (Medium Notebook)',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
              ),
            ),
            DropdownMenuItem(
              value: 'LETTER',
              child: Text(
                context.locale.languageCode == 'ar' ? 'Letter (خطاب)' : 'Letter (US)',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
              ),
            ),
            DropdownMenuItem(
              value: 'LEGAL',
              child: Text(
                context.locale.languageCode == 'ar' ? 'Legal (قانوني طويل)' : 'Legal (Long)',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _settings = _settings.copyWith(pdfPageFormat: newValue);
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildReceiptWidthDropdown(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15.r),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _settings.receiptWidth,
          isExpanded: true,
          icon: Icon(Icons.print, color: AppColors.primary, size: 20.sp),
          items: [
            DropdownMenuItem(
              value: 80,
              child: Text(
                context.locale.languageCode == 'ar' ? '80 ملم (طابعات الكاشير الكبيرة المكتبية)' : '80 mm (Desktop POS Printer)',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
              ),
            ),
            DropdownMenuItem(
              value: 58,
              child: Text(
                context.locale.languageCode == 'ar' ? '58 ملم (طابعات البلوتوث والمحمولة الصغيرة)' : '58 mm (Portable Bluetooth Printer)',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          onChanged: (int? newValue) {
            if (newValue != null) {
              setState(() {
                _settings = _settings.copyWith(receiptWidth: newValue);
              });
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
        subtitle: Text(user.username, style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
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
