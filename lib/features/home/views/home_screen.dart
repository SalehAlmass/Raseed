import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/services/transaction_service.dart';
import '../../../core/services/customer_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/models/app_transaction.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/widgets/date_selector.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TransactionService _transactionService = sl<TransactionService>();
  final SettingsService _settingsService = sl<SettingsService>();
  Map<String, double> _summary = {'daily_sales': 0.0, 'total_debt': 0.0};
  List<AppTransaction> _recentTransactions = [];
  AppSettings? _settings;
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
    final settings = await _settingsService.getSettings();
    setState(() {
      _summary = summary;
      _recentTransactions = recent;
      _settings = settings;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('app_name'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
           IconButton(
            icon: const Icon(Icons.lock_outline),
            onPressed: null,
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
        onPressed: () => _showAddTransactionDialog(context),
        label: Text('new_transaction'.tr()),
        icon: const Icon(Icons.add),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Column(
      children: [
        FadeInDown(
          duration: const Duration(milliseconds: 600),
          child: _SummaryCard(
            title: 'daily_sales'.tr(),
            amounts: {
              'YER': _summary['daily_sales_yer'] ?? 0.0,
              'SAR': _summary['daily_sales_sar'] ?? 0.0,
            },
            icon: Icons.trending_up,
            color: AppColors.success,
          ),
        ),
        SizedBox(height: 15.h),
        FadeInUp(
          duration: const Duration(milliseconds: 600),
          child: _SummaryCard(
            title: 'total_debt'.tr(),
            amounts: {
              'YER': _summary['total_debt_yer'] ?? 0.0,
              'SAR': _summary['total_debt_sar'] ?? 0.0,
            },
            icon: Icons.account_balance_wallet_outlined,
            color: AppColors.error,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _QuickActionBtn(
          label: 'customers'.tr(),
          icon: Icons.people,
          color: AppColors.primary,
          onTap: () => Navigator.pushNamed(context, '/customers'),
        ),
        _QuickActionBtn(
          label: 'cash_sale'.tr(),
          icon: Icons.attach_money,
          color: AppColors.success,
          onTap: () => _showAddTransactionDialog(context, type: TransactionType.cash),
        ),
        _QuickActionBtn(
          label: 'add_debt'.tr(),
          icon: Icons.remove_circle_outline,
          color: AppColors.warning,
          onTap: () => _showAddTransactionDialog(context, type: TransactionType.debt),
        ),
      ],
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
        TextButton(
          onPressed: () {},
          child: Text('see_all'.tr()),
        ),
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
          ? Center(child: Text('no_transactions'.tr(), style: const TextStyle(color: Colors.grey)))
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
                      : (isCash ? AppColors.success.withOpacity(0.1) : AppColors.secondary.withOpacity(0.1)),
                    child: Icon(
                      isDebt ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isDebt ? AppColors.error : (isCash ? AppColors.success : AppColors.secondary),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    isCash ? 'cash_sale'.tr() : (isDebt ? 'debt'.tr() : 'payment'.tr()),
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

  void _showAddTransactionDialog(BuildContext context, {TransactionType type = TransactionType.cash}) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    TransactionType selectedType = type;
    Customer? selectedCustomer;
    String selectedCurrency = _settings?.currency ?? 'YER';
    DateTime selectedDate = DateTime.now();
 
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            selectedType == TransactionType.cash 
              ? 'cash_sale'.tr() 
              : 'add_debt'.tr()
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<TransactionType>(
                  segments: [
                    ButtonSegment(value: TransactionType.cash, label: Text('cash_sale'.tr())),
                    ButtonSegment(value: TransactionType.debt, label: Text('debt'.tr())),
                    ButtonSegment(value: TransactionType.payment, label: Text('payment'.tr())),
                  ],
                  selected: {selectedType},
                  onSelectionChanged: (newSelection) {
                    setState(() => selectedType = newSelection.first);
                  },
                ),
                SizedBox(height: 15.h),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'YER', label: Text('yemeni_rial'.tr())),
                    ButtonSegment(value: 'SAR', label: Text('saudi_riyal'.tr())),
                  ],
                  selected: {selectedCurrency},
                  onSelectionChanged: (newSelection) {
                    setState(() => selectedCurrency = newSelection.first);
                  },
                ),
                SizedBox(height: 20.h),
                if (selectedType != TransactionType.cash) ...[
                  _CustomerDropdown(
                    onChanged: (customer) => setState(() => selectedCustomer = customer),
                  ),
                  SizedBox(height: 20.h),
                ],
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '${CurrencyHelper.getSymbol(selectedCurrency)} ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 15.h),
                TextField(
                  controller: noteController,
                  decoration: InputDecoration(
                    labelText: 'note'.tr(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                ),
                SizedBox(height: 15.h),
                DateSelector(
                  initialDate: selectedDate,
                  onDateSelected: (date) => setState(() => selectedDate = date),
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
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) return;
                
                if (selectedType != TransactionType.cash && selectedCustomer == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a customer'))
                  );
                  return;
                }

                try {
                  await _transactionService.addTransaction(AppTransaction(
                    customerId: selectedType == TransactionType.cash ? null : selectedCustomer!.id,
                    type: selectedType,
                    amount: amount,
                    currency: selectedCurrency,
                    date: selectedDate,
                    note: noteController.text,
                  ));
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    _loadData();
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString().contains('over_limit') 
                          ? 'over_limit_error'.tr() 
                          : 'error_occurred'.tr()),
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
  const _CustomerDropdown({required this.onChanged});

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
        labelText: 'customers'.tr(),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
      ),
      items: _customers.map((c) => DropdownMenuItem(
        value: c,
        child: Text(c.name),
      )).toList(),
      onChanged: (val) {
        setState(() => _selected = val);
        widget.onChanged(val);
      },
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
              if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
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

class _SummaryCard extends StatelessWidget {
  final String title;
  final Map<String, double> amounts;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.amounts,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: color.withOpacity(0.1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(icon, color: color, size: 28.sp),
          ),
          SizedBox(width: 20.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 8.h),
                Wrap(
                  spacing: 15.w,
                  runSpacing: 5.h,
                  children: amounts.entries.map((entry) {
                    final value = entry.value;
                    if (value == 0 && amounts.values.any((v) => v > 0)) {
                      return const SizedBox.shrink();
                    }
                    return Text(
                      CurrencyHelper.getFormatter(entry.key).format(value),
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
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
