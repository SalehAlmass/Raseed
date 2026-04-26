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
    setState(() {
      _summary = summary;
      _recentTransactions = recent;
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
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                  InkWell(
                    onTap: () {
                      if (sl<SubscriptionService>().canUseFeature(
                        AppFeature.addSale,
                      )) {
                        Navigator.pushNamed(context, '/sale').then((result) {
                          if (result == true) _loadData();
                        });
                      } else {
                        SubscriptionDialog.show(context);
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        'new_sale'.tr(),
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
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
          Navigator.pushNamed(context, Routes.sale).then((result) {
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
                final tx = _recentTransactions[index];
                final isRefund = tx.type == TransactionType.refund;
                final isSale = tx.type == TransactionType.sale;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: isRefund
                        ? AppColors.error.withOpacity(0.1)
                        : (isSale
                              ? AppColors.success.withOpacity(0.1)
                              : AppColors.secondary.withOpacity(0.1)),
                    child: Icon(
                      isRefund ? Icons.keyboard_return : Icons.arrow_downward,
                      color: isRefund
                          ? AppColors.error
                          : (isSale ? AppColors.success : AppColors.secondary),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    isSale
                        ? 'cash_sale'.tr()
                        : (isRefund ? 'refund'.tr() : 'payment'.tr()),
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
                      color: isRefund ? AppColors.error : AppColors.success,
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showPaymentDialog(BuildContext context) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    Customer? selectedCustomer;
    TransactionType selectedType = TransactionType.payment;

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
                        amountController.text = c.totalDebt.toStringAsFixed(0);
                      } else {
                        amountController.clear();
                      }
                    });
                  },
                  isRequired: true,
                ),
                SizedBox(height: 15.h),
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(
                    labelText: 'amount'.tr(),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 15.h),
                TextField(
                  controller: noteController,
                  decoration: InputDecoration(
                    labelText: 'note'.tr(),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount <= 0 || selectedCustomer == null) return;

                if (noteController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('note_required'.tr()),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }

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

                  if (amount > selectedCustomer!.totalDebt) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('payment_exceeds_debt'.tr()),
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

                    if (selectedCustomer!.phone.isNotEmpty) {
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
                            'send_notification_desc'.tr(namedArgs: {'name': selectedCustomer!.name}),
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
                          message = 'whatsapp_msg_payment'.tr(namedArgs: {
                            'amount': formattedAmount,
                            'balance': formattedDebt,
                          });
                        } else {
                          message = 'whatsapp_msg_debt'.tr(namedArgs: {
                            'amount': formattedAmount,
                            'balance': formattedDebt,
                          });
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

  const _SummaryCard({
    required this.title,
    required this.amounts,
    required this.icon,
    required this.color,
    this.isGradient = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}
