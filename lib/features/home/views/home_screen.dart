import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/services/transaction_service.dart';
import '../../../core/services/customer_service.dart';
import '../../../core/services/database_helper.dart';
import '../../../core/theme/colors.dart';
import '../../../core/models/app_transaction.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/widgets/pin_auth_dialog.dart';
import '../../../core/models/product.dart';
import '../../../core/services/product_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/models/app_feature.dart';
import '../../../core/widgets/subscription_dialog.dart';
import '../../../core/widgets/barcode_scanner_view.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/routes/routes.dart';
import '../../../core/widgets/app_bottom_navigation_bar.dart';
import '../../marketing/views/whatsapp_marketing_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TransactionService _transactionService = sl<TransactionService>();
  Map<String, double> _summary = {'daily_sales': 0.0, 'total_debt': 0.0};
  List<AppTransaction> _recentTransactions = [];
  List<Product> _nearExpiryProducts = [];
  List<Product> _lowStockProducts = [];
  List<Customer> _overDebtCustomers = [];
  bool _isLoading = true;
  int _bottomNavIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final summary = await _transactionService.getDashboardSummary();
    final recent = await _transactionService.getAllTransactions(limit: 5);
    final nearExpiry = await sl<ProductService>().getNearExpiryProducts();
    final lowStock = await sl<ProductService>().getLowStockProducts();
    final settings = sl<SettingsService>().settings;
    final overDebt = await sl<CustomerService>().getOverDebtCustomers(
      settings.maxDebt,
    );

    setState(() {
      _summary = summary;
      _recentTransactions = recent;
      _nearExpiryProducts = nearExpiry;
      _lowStockProducts = lowStock;
      _overDebtCustomers = overDebt;
      _isLoading = false;
    });
  }

  ModuleConfig get _moduleConfig => sl<SettingsService>().settings.moduleConfig;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'app_name'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        leading: CircleAvatar(
          radius: 40,
          backgroundImage: AssetImage('assets/images/logo.png'),
        ),
        actions: [
          if (_moduleConfig.showSuppliers)
            IconButton(
              icon: const Icon(Icons.business_rounded),
              onPressed: () => Navigator.pushNamed(
                context,
                Routes.suppliers,
              ).then((_) => _loadData()),
              tooltip: 'suppliers'.tr(),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              final settings = sl<SettingsService>().settings;
              if (settings.staffConfig.isEnabled) {
                final verified = await showDialog<bool>(
                  context: context,
                  builder: (context) => PinAuthDialog(
                    correctPin: settings.staffConfig.pinCode ?? '0000',
                  ),
                );
                if (verified != true) return;
              }
              Navigator.pushNamed(
                context,
                '/settings',
              ).then((_) => _loadData());
            },
          ),
          // if (_moduleConfig.showInventory)
          //   IconButton(
          //     icon: const Icon(Icons.store_mall_directory),
          //     onPressed: () => Navigator.pushNamed(
          //       context,
          //       '/store',
          //     ).then((_) => _loadData()),
          //   ),
          // IconButton(
          //   icon: const Icon(Icons.delete_forever),
          //   onPressed: () => _showResetDataConfirmation(context),
          // ),
          // IconButton(
          //   icon: const Icon(Icons.add),
          //   onPressed: () =>
          //   Navigator.pushNamed(context, '/sale').then((_) => _loadData()),
          //   // onPressed: () => _showPaymentDialog(context),
          // ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            top: 20.h,
            bottom: 100.h,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_moduleConfig.showInventory) _buildAlertsSection(),
              if (!_moduleConfig.showCustomers)
                _buildKioskHeader()
              else
                _buildSummaryCards(),
              SizedBox(height: 20.h),
              if (_moduleConfig.showAccounting) _buildAccountingSection(),
              if (_moduleConfig.showCustomers) _buildMarketingSection(),
              SizedBox(height: 30.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'recent_activity'.tr(),
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  _ActionCard(
                    label: 'get_payment'.tr(),
                    icon: Icons.check_circle_outline,
                    color: AppColors.error,
                    onTap: () {
                      if (sl<SubscriptionService>().canUseFeature(
                        AppFeature.addSale,
                      )) {
                        _showPaymentDialog(
                          context,
                          type: TransactionType.payment,
                        );
                      } else {
                        SubscriptionDialog.show(context);
                      }
                    },
                  ),
                ],
              ),
              SizedBox(height: 15.h),
              _buildRecentActivityList(),
            ],
          ),
        ),
      ),

      bottomNavigationBar: AppBottomNavigationBar(
        activeIndex: _bottomNavIndex,
        onTap: _onNavTap,
      ),
    );
  }

  Widget _buildAlertsSection() {
    List<Widget> alerts = [];
    final subService = sl<SubscriptionService>();

    // 0. Subscription Alert (Developer Contact)
    if (!subService.isPremiumActive) {
      alerts.add(
        _buildAlertItem(
          title: 'trial_expired_home'.tr(),
          desc: 'contact_dev_msg'.tr(),
          icon: Icons.lock_clock_rounded,
          color: AppColors.error,
          onTap: _contactDev,
        ),
      );
    } else if (!subService.isSubscribed && !subService.isClockTampered) {
      final remaining = subService.remainingDays;
      alerts.add(
        _buildAlertItem(
          title: 'trial_active'.tr(),
          desc: 'trial_remaining'.tr(namedArgs: {'days': remaining.toString()}),
          icon: Icons.timer_outlined,
          color: AppColors.primary,
          onTap: () {},
        ),
      );
    }

    // 1. Near Expiry Alert
    if (_nearExpiryProducts.isNotEmpty) {
      alerts.add(
        _buildAlertItem(
          title: 'near_expiry_alert'.tr(),
          desc: 'near_expiry_desc'.tr(
            args: [_nearExpiryProducts.length.toString()],
          ),
          icon: Icons.history_toggle_off_rounded,
          color: AppColors.error,
          onTap: () => _showProductsSheet(
            'near_expiry_products'.tr(),
            _nearExpiryProducts,
          ),
        ),
      );
    }

    // 2. Low Stock Alert
    if (_lowStockProducts.isNotEmpty) {
      alerts.add(
        _buildAlertItem(
          title: 'low_stock_alert'.tr(),
          desc: 'low_stock_desc'.tr(
            args: [_lowStockProducts.length.toString()],
          ),
          icon: Icons.inventory_2_outlined,
          color: Colors.orange,
          onTap: () =>
              _showProductsSheet('low_stock_products'.tr(), _lowStockProducts),
        ),
      );
    }

    // 3. Over Debt Alert
    if (_overDebtCustomers.isNotEmpty && _moduleConfig.showCustomers) {
      alerts.add(
        _buildAlertItem(
          title: 'over_debt_alert'.tr(),
          desc: 'over_debt_desc'.tr(
            args: [_overDebtCustomers.length.toString()],
          ),
          icon: Icons.person_pin_circle_outlined,
          color: AppColors.primary,
          onTap: () => _showOverDebtCustomersSheet(),
        ),
      );
    }

    if (alerts.isEmpty) return const SizedBox.shrink();

    return Column(children: alerts);
  }

  Widget _buildAlertItem({
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14.sp,
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(
                    color: color.withOpacity(0.8),
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            child: Text('view'.tr(), style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }

  void _showOverDebtCustomersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Text(
                'over_debt_customers'.tr(),
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _overDebtCustomers.length,
                itemBuilder: (context, index) {
                  final c = _overDebtCustomers[index];
                  return ListTile(
                    leading: CircleAvatar(child: Text(c.name[0])),
                    title: Text(c.name),
                    subtitle: Text(c.phone),
                    trailing: Text(
                      '${c.totalDebt.toStringAsFixed(0)} ${CurrencyHelper.getSymbol('YER')}',
                      style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketingSection() {
    return Container(
      margin: EdgeInsets.only(top: 20.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.green.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.rocket_launch, color: Colors.white, size: 28.sp),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'marketing'.tr(),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                  ),
                ),
                Text(
                  'marketing_desc'.tr(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const WhatsappMarketingScreen(),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.green.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16.w),
            ),
            child: Text('open'.tr()),
          ),
        ],
      ),
    );
  }

  void _showProductsSheet(String title, List<Product> products) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: products.isEmpty
                  ? Center(
                      child: Text(
                        'no_products'.tr(),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      itemCount: products.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final p = products[index];
                        final expiry = p.batches
                            .where((b) => b.isNearExpiry)
                            .firstOrNull
                            ?.expiryDate;
                        return ListTile(
                          title: Text(
                            p.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            expiry != null
                                ? '${'expiry_date'.tr()}: ${DateFormat.yMd(context.locale.toString()).format(expiry)}'
                                : '',
                            style: TextStyle(color: AppColors.error),
                          ),
                          trailing: Text(
                            '${p.stockQuantity} ${'units'.tr()}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _onNavTap(int index) {
    setState(() => _bottomNavIndex = index);
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, Routes.home);
        break;
      case 1:
        Navigator.pushReplacementNamed(context, Routes.customers);
        break;
      case 2:
        if (sl<SubscriptionService>().canUseFeature(AppFeature.addSale)) {
          Navigator.pushNamed(
            context,
            Routes.sale,
            arguments: TransactionType.payment,
          ).then((result) {
            if (result == true) _loadData();
          });
        } else {
          SubscriptionDialog.show(context);
        }
        break;
      case 3:
        if (sl<SubscriptionService>().canUseFeature(AppFeature.viewReports)) {
          Navigator.pushReplacementNamed(context, Routes.reports);
        } else {
          SubscriptionDialog.show(context);
        }
        break;
      case 4:
        Navigator.pushReplacementNamed(context, Routes.store);
        break;
    }
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: _ActionCard(
            label: 'get_payment'.tr(),
            icon: Icons.check_circle_outline,
            color: AppColors.success,
            onTap: () =>
                _showPaymentDialog(context, type: TransactionType.payment),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        if (_moduleConfig.showSales) ...[
          Expanded(
            child: FadeInDown(
              duration: const Duration(milliseconds: 600),
              child: _SummaryCard(
                title: 'daily_sales'.tr(),
                amounts: {'YER': _summary['daily_sales_yer'] ?? 0.0},
                icon: Icons.trending_up_rounded,
                color: AppColors.success,
                onTap: () {
                  _showDailySalesSheet();
                },
              ),
            ),
          ),
          if (_moduleConfig.showCustomers) SizedBox(width: 12.w),
        ],
        if (_moduleConfig.showCustomers) ...[
          Expanded(
            child: FadeInUp(
              duration: const Duration(milliseconds: 600),
              child: _SummaryCard(
                title: 'total_debt'.tr(),
                amounts: {'YER': _summary['total_debt_yer'] ?? 0.0},
                icon: Icons.account_balance_wallet_rounded,
                color: AppColors.error,
                onTap: () {
                  _showDebtTransactionsSheet();
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildKioskHeader() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'daily_sales'.tr(),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14.sp,
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    CurrencyHelper.getFormatter(
                      'YER',
                    ).format(_summary['daily_sales_yer'] ?? 0.0),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              if (_recentTransactions.isNotEmpty)
                _buildUndoButton(_recentTransactions.first),
            ],
          ),
          SizedBox(height: 25.h),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _onNavTap(2), // Open Sale
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
                  label: Text(
                    'new_sale'.tr(),
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.r),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUndoButton(AppTransaction tx) {
    return Tooltip(
      message: 'undo_last_sale'.tr(),
      child: InkWell(
        onTap: () => _confirmVoidTransaction(tx),
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.undo_rounded, color: Colors.white, size: 18),
              SizedBox(width: 6.w),
              Text(
                'undo'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmVoidTransaction(AppTransaction tx) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('void_transaction'.tr()),
        content: Text('void_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _transactionService.voidTransaction(tx);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('void_success'.tr())));
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('error_occurred'.tr()),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildAccountingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'accounting'.tr(),
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 15.h),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                label: 'daily_journal'.tr(),
                icon: Icons.assignment_rounded,
                color: Colors.blue,
                onTap: () => Navigator.pushNamed(context, Routes.journal),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _QuickActionCard(
                label: 'chart_of_accounts'.tr(),
                icon: Icons.account_tree_rounded,
                color: Colors.orange,
                onTap: () =>
                    Navigator.pushNamed(context, Routes.chartOfAccounts),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showResetDataConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: AppColors.error,
          size: 48.sp,
        ),
        title: Text(
          'reset_data'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('reset_data_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _resetAllData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _resetAllData() async {
    try {
      await DatabaseHelper.instance.deleteAllData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('data_reset_success'.tr()),
            backgroundColor: AppColors.success,
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error_occurred'.tr()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _contactDev() async {
    const phone = '967777359678';
    final message = 'trial_expired_whatsapp_msg'.tr();
    final url = "https://wa.me/$phone?text=${Uri.encodeComponent(message)}";

    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('could_not_launch_whatsapp'.tr())),
        );
      }
    }
  }

  Future<void> _showDailySalesSheet() async {
    final allTx = await sl<TransactionService>().getAllTransactions(limit: 500);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final dailyTx = allTx.where((tx) {
      final txDate = DateTime(tx.date.year, tx.date.month, tx.date.day);
      return txDate.isAtSameMomentAs(today) && tx.type == TransactionType.sale;
    }).toList();

    if (mounted) _showTransactionsSheet('daily_sales'.tr(), dailyTx);
  }

  Future<void> _showDebtTransactionsSheet() async {
    final allTx = await sl<TransactionService>().getAllTransactions(limit: 500);

    final debtTx = allTx.where((tx) {
      if (tx.type == TransactionType.sale && tx.amount > tx.paidAmount)
        return true;
      if (tx.type == TransactionType.payment) return true;
      return false;
    }).toList();

    if (mounted) _showTransactionsSheet('total_debt'.tr(), debtTx);
  }

  void _showTransactionsSheet(String title, List<AppTransaction> transactions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: transactions.isEmpty
                  ? Center(
                      child: Text(
                        'no_transactions'.tr(),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      itemCount: transactions.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        return _TransactionTile(
                          tx: transactions[index],
                          onVoid: _confirmVoidTransaction,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'recent_activity'.tr(),
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        TextButton(onPressed: () {}, child: Text('see_all'.tr())),
      ],
    );
  }

  Widget _buildRecentActivityList() {
    return Container(
      padding: EdgeInsets.all(15.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recentTransactions.isEmpty
          ? Center(
              child: Text(
                'no_transactions'.tr(),
                style: const TextStyle(color: Colors.grey),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentTransactions.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                return _TransactionTile(
                  tx: _recentTransactions[index],
                  onVoid: _confirmVoidTransaction,
                );
              },
            ),
    );
  }

  void _showPaymentDialog(
    BuildContext context, {
    TransactionType type = TransactionType.payment,
  }) {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    Customer? selectedCustomer;
    TransactionType selectedType = type;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            selectedType == TransactionType.payment
                ? 'get_payment'.tr()
                : 'add_debt'.tr(),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<TransactionType>(
                    segments: [
                      ButtonSegment(
                        value: TransactionType.payment,
                        label: Text('payment'.tr()),
                        icon: const Icon(Icons.payment),
                      ),
                      ButtonSegment(
                        value: TransactionType.sale,
                        label: Text('add_debt'.tr()),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                    selected: {selectedType},
                    onSelectionChanged: (val) {
                      setState(() {
                        selectedType = val.first;
                        if (selectedType == TransactionType.payment &&
                            selectedCustomer != null) {
                          amountController.text = selectedCustomer!.totalDebt
                              .toStringAsFixed(0);
                        } else {
                          amountController.clear();
                        }
                      });
                    },
                  ),
                  SizedBox(height: 20.h),
                  _CustomerDropdown(
                    onChanged: (c) {
                      setState(() {
                        selectedCustomer = c;
                        if (selectedType == TransactionType.payment &&
                            c != null) {
                          amountController.text = c.totalDebt.toStringAsFixed(
                            0,
                          );
                        } else {
                          amountController.clear();
                        }
                      });
                    },
                    isRequired: true,
                  ),
                  SizedBox(height: 15.h),
                  TextFormField(
                    controller: amountController,
                    decoration: InputDecoration(
                      labelText: 'amount'.tr(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'amount_required'.tr();
                      }
                      final amount = double.tryParse(value) ?? 0;
                      if (amount <= 0) {
                        return 'amount_must_be_positive'.tr();
                      }
                      if (selectedType == TransactionType.payment &&
                          selectedCustomer != null) {
                        if (amount > selectedCustomer!.totalDebt) {
                          return 'payment_exceeds_debt'.tr();
                        }
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 15.h),
                  TextFormField(
                    controller: noteController,
                    decoration: InputDecoration(
                      labelText: 'note'.tr() + ' ' + 'optional'.tr(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;

                final amount = double.tryParse(amountController.text) ?? 0;

                if (selectedType == TransactionType.payment) {
                  if (selectedCustomer!.totalDebt <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('no_debt_to_repay'.tr()),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }
                }

                final tx = AppTransaction(
                  customerId: selectedCustomer!.id,
                  type: selectedType,
                  amount: amount,
                  date: DateTime.now(),
                  note: noteController.text.trim(),
                );

                try {
                  await sl<TransactionService>().addTransaction(tx);
                  if (context.mounted) {
                    Navigator.pop(context);
                    _loadData();

                    final settings = await sl<SettingsService>().getSettings();

                    if (settings.enableWhatsapp &&
                        selectedCustomer!.phone.isNotEmpty) {
                      double currentDebt = selectedCustomer!.totalDebt;
                      if (selectedType == TransactionType.payment) {
                        currentDebt -= amount;
                      } else {
                        currentDebt += amount;
                      }

                      final formattedAmount = CurrencyHelper.getFormatter(
                        'YER',
                      ).format(amount);
                      final formattedDebt = CurrencyHelper.getFormatter(
                        'YER',
                      ).format(currentDebt);

                      final bool? sendWa = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('send_notification_wa'.tr()),
                          content: Text(
                            'send_notification_desc'.tr(
                              namedArgs: {'name': selectedCustomer!.name},
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text('no'.tr()),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text('yes'.tr()),
                            ),
                          ],
                        ),
                      );

                      if (sendWa == true) {
                        String message = "";
                        if (selectedType == TransactionType.payment) {
                          message = 'whatsapp_msg_payment'.tr(
                            namedArgs: {
                              'amount': formattedAmount,
                              'balance': formattedDebt,
                            },
                          );
                        } else {
                          message = 'whatsapp_msg_debt'.tr(
                            namedArgs: {
                              'amount': formattedAmount,
                              'balance': formattedDebt,
                            },
                          );
                        }

                        String phone = selectedCustomer!.phone.replaceAll(
                          RegExp(r'[^\d+]'),
                          '',
                        );
                        if (phone.startsWith('0')) phone = phone.substring(1);
                        if (!phone.startsWith('+') &&
                            !phone.startsWith('00') &&
                            !phone.startsWith('967')) {
                          phone = '967$phone';
                        }
                        phone = phone.replaceAll('+', '').replaceAll('00', '');

                        final url =
                            "https://wa.me/$phone?text=${Uri.encodeComponent(message)}";
                        try {
                          await launchUrl(
                            Uri.parse(url),
                            mode: LaunchMode.externalApplication,
                          );
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('could_not_launch_whatsapp'.tr()),
                              ),
                            );
                          }
                        }
                      }
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    String msg = 'error_occurred'.tr();
                    if (e.toString().contains('no_debt_to_repay'))
                      msg = 'no_debt_to_repay'.tr();
                    if (e.toString().contains('payment_exceeds_debt'))
                      msg = 'payment_exceeds_debt'.tr();
                    if (e.toString().contains('over_limit'))
                      msg = 'over_limit_error'.tr();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(msg),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: Text('save'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerDropdown extends StatefulWidget {
  final Function(Customer?) onChanged;
  final bool isRequired;

  const _CustomerDropdown({required this.onChanged, this.isRequired = false});

  @override
  State<_CustomerDropdown> createState() => _CustomerDropdownState();
}

class _CustomerDropdownState extends State<_CustomerDropdown> {
  final CustomerService _customerService = sl<CustomerService>();
  List<Customer> _customers = [];
  Customer? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _customerService.getAllCustomers();
    setState(() => _customers = list);
  }

  Widget _buildDropdown() {
    return DropdownButtonFormField<Customer>(
      value: _selected,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'select_customer'.tr(),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
      ),
      items: _customers
          .map(
            (c) => DropdownMenuItem(
              value: c,
              child: Text(
                '${c.name} - ${CurrencyHelper.getFormatter('YER').format(c.totalDebt)} YER',
              ),
            ),
          )
          .toList(),
      onChanged: (val) {
        setState(() => _selected = val);
        widget.onChanged(val);
      },
      validator: widget.isRequired
          ? (value) {
              if (value == null) {
                return 'please_select_customer'.tr();
              }
              return null;
            }
          : null,
    );
  }

  void _showQuickAddDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('add_new_customer'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'name'.tr()),
            ),
            TextField(
              controller: phoneController,
              decoration: InputDecoration(labelText: 'phone_number'.tr()),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty &&
                  phoneController.text.isNotEmpty) {
                final customer = Customer(
                  name: nameController.text,
                  phone: phoneController.text,
                );
                await _customerService.createCustomer(customer);
                if (context.mounted) {
                  Navigator.pop(context);
                  _load(); // Reload the list
                }
              }
            },
            child: Text('save'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildDropdown()),
        SizedBox(width: 10.w),
        Container(
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: IconButton(
            icon: const Icon(Icons.person_add_alt_1, color: AppColors.primary),
            onPressed: _showQuickAddDialog,
          ),
        ),
      ],
    );
  }
}

class _ProductDropdown extends StatefulWidget {
  final Function(Product?) onChanged;
  const _ProductDropdown({required this.onChanged});

  @override
  State<_ProductDropdown> createState() => _ProductDropdownState();
}

class _ProductDropdownState extends State<_ProductDropdown> {
  final ProductService _productService = sl<ProductService>();
  List<Product> _products = [];
  Product? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _productService.getAllProducts();
    setState(() => _products = list);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<Product>(
            value: _selected,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'select_product'.tr(),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            items: [
              DropdownMenuItem<Product>(
                value: null,
                child: Text('none_manual'.tr()),
              ),
              ..._products.map(
                (p) => DropdownMenuItem(
                  value: p,
                  child: Text(
                    '${p.name} - ${CurrencyHelper.getFormatter(p.currency).format(p.price)} ${p.currency}',
                  ),
                ),
              ),
            ],
            onChanged: (val) {
              setState(() => _selected = val);
              widget.onChanged(val);
            },
          ),
        ),
        SizedBox(width: 8.w),
        IconButton.filled(
          onPressed: () async {
            final code = await Navigator.push<String>(
              context,
              MaterialPageRoute(builder: (_) => const BarcodeScannerView()),
            );
            if (code != null) {
              final product = _products.cast<Product?>().firstWhere(
                (p) => p?.barcode == code,
                orElse: () => null,
              );
              if (product != null) {
                setState(() => _selected = product);
                widget.onChanged(product);
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('product_not_found'.tr()),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            }
          },
          icon: const Icon(Icons.qr_code_scanner),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final Map<String, double> amounts;
  final IconData icon;
  final Color color;
  final bool isGradient;
  final VoidCallback? onTap;

  const _SummaryCard({
    required this.title,
    required this.amounts,
    required this.icon,
    required this.color,
    this.isGradient = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(icon, color: color, size: 20.sp),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 4.h,
              children: amounts.entries.map((entry) {
                final value = entry.value;
                if (value == 0 && amounts.values.any((v) => v > 0)) {
                  return const SizedBox.shrink();
                }
                return Text(
                  CurrencyHelper.getFormatter(entry.key).format(value),
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18.sp),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final AppTransaction tx;
  final Function(AppTransaction) onVoid;
  const _TransactionTile({required this.tx, required this.onVoid});

  @override
  Widget build(BuildContext context) {
    final isRefund = tx.type == TransactionType.refund;
    final isPayment = tx.type == TransactionType.payment;
    final isSale = tx.type == TransactionType.sale && tx.items.isNotEmpty;
    final isAddDebt = tx.type == TransactionType.sale && tx.items.isEmpty;

    String titleText;
    if (isRefund)
      titleText = 'refund'.tr();
    else if (isPayment)
      titleText = 'payment'.tr();
    else if (isAddDebt)
      titleText = 'add_debt'.tr();
    else
      titleText = 'cash_sale'.tr();

    Color iconColor;
    IconData iconData;

    if (isRefund) {
      iconColor = AppColors.error;
      iconData = Icons.keyboard_return;
    } else if (isPayment) {
      iconColor = AppColors.success;
      iconData = Icons.arrow_downward;
    } else if (isAddDebt) {
      iconColor = AppColors.error;
      iconData = Icons.arrow_upward;
    } else {
      iconColor = AppColors.success;
      iconData = Icons.shopping_cart_outlined;
    }

    final remaining = tx.amount - tx.paidAmount;
    final hasDebt = tx.type == TransactionType.sale && remaining > 0;

    return InkWell(
      onLongPress: () => onVoid(tx),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(iconData, color: iconColor, size: 20),
        ),
        title: Text(
          titleText,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('MMM dd, hh:mm a').format(tx.date),
              style: TextStyle(fontSize: 12.sp, color: Colors.grey),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              CurrencyHelper.getFormatter(tx.currency).format(tx.amount),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isRefund || isAddDebt
                    ? AppColors.error
                    : AppColors.success,
              ),
            ),
            if (hasDebt)
              Text(
                '${'remmining'.tr()}: ${CurrencyHelper.getFormatter(tx.currency).format(remaining)}',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.orange[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(15.w),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(15.r),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24.sp),
            ),
            SizedBox(height: 10.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
