import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/services/transaction_service.dart';
import '../../../core/services/customer_service.dart';
import '../../../core/services/database_helper.dart';
import '../../../core/theme/colors.dart';
import '../../../core/models/app_transaction.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/product.dart';
import '../../../core/services/product_service.dart';
import '../../../core/widgets/barcode_scanner_view.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/routes/routes.dart';

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'app_name'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.store_mall_directory),
            onPressed: () => Navigator.pushNamed(context, '/store'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () => _showResetDataConfirmation(context),
          ),
        
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
              
              Text(
                'quick_actions'.tr(),
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 15.h),
              _buildQuickActions(context),
              SizedBox(height: 30.h),
              _buildRecentActivityHeader(),
              SizedBox(height: 15.h),
              _buildRecentActivityList(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, Routes.sale);
          if (result == true) _loadData();
        },
        label: Text('new_sale'.tr()),
        icon: const Icon(Icons.add),
        backgroundColor: AppColors.primary,
      ),
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
              amounts: {
                'YER': _summary['daily_sales_yer'] ?? 0.0,
              },
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
              amounts: {
                'YER': _summary['total_debt_yer'] ?? 0.0,
              },
              icon: Icons.account_balance_wallet_rounded,
              color: AppColors.error,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _QuickActionBtn(
              label: 'customers'.tr(),
              icon: Icons.people,
              color: AppColors.primary,
              onTap: () => Navigator.pushNamed(context, Routes.customers),
            ),
            _QuickActionBtn(
              label: 'cash_sale'.tr(),
              icon: Icons.attach_money,
              color: AppColors.success,
              onTap: () async {
                final result = await Navigator.pushNamed(
                  context, 
                  Routes.sale, 
                  arguments: TransactionType.cash
                );
                if (result == true) _loadData();
              },
            ),
            _QuickActionBtn(
              label: 'add_debt'.tr(),
              icon: Icons.remove_circle_outline,
              color: AppColors.warning,
              onTap: () async {
                final result = await Navigator.pushNamed(
                  context, 
                  Routes.sale, 
                  arguments: TransactionType.debt
                );
                if (result == true) _loadData();
              },
            ),
          ],
        ),
        SizedBox(height: 15.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _QuickActionBtn(
              label: 'get_payment'.tr(),
              icon: Icons.account_balance_wallet,
              color: AppColors.primary,
              onTap: () => _showPaymentDialog(context),
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
                final isDebt = tx.type == TransactionType.debt;
                final isCash = tx.type == TransactionType.cash;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: isDebt
                        ? AppColors.error.withOpacity(0.1)
                        : (isCash
                              ? AppColors.success.withOpacity(0.1)
                              : AppColors.secondary.withOpacity(0.1)),
                    child: Icon(
                      isDebt ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isDebt
                          ? AppColors.error
                          : (isCash ? AppColors.success : AppColors.secondary),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    isCash
                        ? 'cash_sale'.tr()
                        : (isDebt ? 'debt'.tr() : 'payment'.tr()),
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
                      color: isDebt ? AppColors.error : AppColors.success,
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showPaymentDialog(BuildContext context) {
    // New simplified dialog for standalone customer payments (collections)
    final amountController = TextEditingController();
    Customer? selectedCustomer;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('get_payment'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CustomerDropdown(
                onChanged: (c) => setState(() => selectedCustomer = c),
                isRequired: true,
              ),
              SizedBox(height: 15.h),
              TextField(
                controller: amountController,
                decoration: InputDecoration(
                  labelText: 'amount'.tr(),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
                keyboardType: TextInputType.number,
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
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount <= 0 || selectedCustomer == null) return;

                if (selectedCustomer!.totalDebt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('no_debt_to_repay'.tr()), backgroundColor: AppColors.error),
                  );
                  return;
                }

                if (amount > selectedCustomer!.totalDebt) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('payment_exceeds_debt'.tr()), backgroundColor: AppColors.error),
                  );
                  return;
                }

                final tx = AppTransaction(
                  customerId: selectedCustomer!.id,
                  type: TransactionType.payment,
                  amount: amount,
                  date: DateTime.now(),
                  note: 'Payment received',
                );

                try {
                  await sl<TransactionService>().addTransaction(tx);
                  if (context.mounted) {
                    Navigator.pop(context);
                    _loadData();
                  }
                } catch (e) {
                   if (context.mounted) {
                     String msg = 'error_occurred'.tr();
                     if (e.toString().contains('no_debt_to_repay')) msg = 'no_debt_to_repay'.tr();
                     if (e.toString().contains('payment_exceeds_debt')) msg = 'payment_exceeds_debt'.tr();
                     
                     ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(content: Text(msg), backgroundColor: AppColors.error),
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
  
  const _CustomerDropdown({
    required this.onChanged,
    this.isRequired = false,
  });

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
          .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            items: [
              DropdownMenuItem<Product>(
                value: null,
                child: Text('none_manual'.tr()),
              ),
              ..._products.map((p) => DropdownMenuItem(
                    value: p,
                    child: Text('${p.name} - ${CurrencyHelper.getFormatter(p.currency).format(p.price)} ${p.currency}'),
                  )),
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
                    SnackBar(content: Text('product_not_found'.tr()), backgroundColor: AppColors.error),
                  );
                }
              }
            }
          },
          icon: const Icon(Icons.qr_code_scanner),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
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
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
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
                child: Icon(
                  icon,
                  color: color,
                  size: 20.sp,
                ),
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

class _QuickActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(15.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
