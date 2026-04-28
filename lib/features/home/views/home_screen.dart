import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
import 'package:rseed/core/services/settings_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/services/transaction_service.dart';
import '../../../core/services/customer_service.dart';
import '../../../core/services/database_helper.dart';
import '../../../core/theme/colors.dart';
import '../../../core/models/app_transaction.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/product.dart';
import '../../../core/services/product_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/models/app_feature.dart';
import '../../../core/widgets/subscription_dialog.dart';
import '../../../core/widgets/barcode_scanner_view.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/routes/routes.dart';
import '../../../core/widgets/app_bottom_navigation_bar.dart';

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
  bool _isLoading = true;
  int _bottomNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final summary = await _transactionService.getDashboardSummary();
    final recent = await _transactionService.getAllTransactions(limit: 5);
    final nearExpiry = await sl<ProductService>().getNearExpiryProducts();
    
    setState(() {
      _summary = summary;
      _recentTransactions = recent;
      _nearExpiryProducts = nearExpiry;
      _isLoading = false;
    });
  }

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
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(
              context,
              '/settings',
            ).then((_) => _loadData()),
          ),
          IconButton(
            icon: const Icon(Icons.store_mall_directory),
            onPressed: () =>
                Navigator.pushNamed(context, '/store').then((_) => _loadData()),
          ),
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
          padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 20.h, bottom: 100.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAlertsSection(),
              _buildSummaryCards(),
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
                    onTap: () => _showPaymentDialog(
                      context,
                      type: TransactionType.payment,
                    ),
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
    if (_nearExpiryProducts.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(bottom: 20.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.error.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'near_expiry_alert'.tr(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                    fontSize: 14.sp,
                  ),
                ),
                Text(
                  'near_expiry_desc'.tr(args: [_nearExpiryProducts.length.toString()]),
                  style: TextStyle(
                    color: AppColors.error.withOpacity(0.8),
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              _showProductsSheet('near_expiry_products'.tr(), _nearExpiryProducts);
            },
            child: Text('view'.tr(), style: TextStyle(color: AppColors.error)),
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
                          title: Text(p.name,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
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
        SizedBox(width: 12.w),
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
      if (tx.type == TransactionType.sale && tx.amount > tx.paidAmount) return true;
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
                        return _TransactionTile(tx: transactions[index]);
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
                return _TransactionTile(tx: _recentTransactions[index]);
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

                    if (settings.enableWhatsapp && selectedCustomer!.phone.isNotEmpty) {
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
  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isRefund = tx.type == TransactionType.refund;
    final isPayment = tx.type == TransactionType.payment;
    final isSale = tx.type == TransactionType.sale && tx.items.isNotEmpty;
    final isAddDebt = tx.type == TransactionType.sale && tx.items.isEmpty;

    String titleText;
    if (isRefund) titleText = 'refund'.tr();
    else if (isPayment) titleText = 'payment'.tr();
    else if (isAddDebt) titleText = 'add_debt'.tr();
    else titleText = 'cash_sale'.tr();

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

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: iconColor.withOpacity(0.1),
        child: Icon(
          iconData,
          color: iconColor,
          size: 20,
        ),
      ),
      title: Text(
        titleText,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        DateFormat('MMM dd, hh:mm a').format(tx.date),
        style: TextStyle(fontSize: 12.sp, color: Colors.grey),
      ),
      trailing: Text(
        CurrencyHelper.getFormatter(tx.currency).format(tx.amount),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isRefund || isAddDebt ? AppColors.error : AppColors.success,
        ),
      ),
    );
  }
}
