import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/services/customer_service.dart';
import '../../../core/services/transaction_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/app_transaction.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/widgets/date_selector.dart';
import 'package:intl/intl.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;
  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  final TransactionService _transactionService = sl<TransactionService>();
  final CustomerService _customerService = sl<CustomerService>();
  final SettingsService _settingsService = sl<SettingsService>();
  late Customer _currentCustomer;
  List<AppTransaction> _transactions = [];
  AppSettings? _settings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentCustomer = widget.customer;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final transactions = await _transactionService.getCustomerTransactions(_currentCustomer.id!);
    final customer = await _customerService.getCustomer(_currentCustomer.id!);
    final settings = await _settingsService.getSettings();
    setState(() {
      _transactions = transactions;
      if (customer != null) _currentCustomer = customer;
      _settings = settings;
      _isLoading = false;
    });
  }

  Future<void> _openWhatsApp() async {
    final String yerBal = CurrencyHelper.getFormatter('YER').format(_currentCustomer.totalDebt);
    final String sarBal = CurrencyHelper.getFormatter('SAR').format(_currentCustomer.totalDebtSar);
    
    String balanceMsg = "";
    if (_currentCustomer.totalDebt > 0) balanceMsg += yerBal;
    if (_currentCustomer.totalDebtSar > 0) balanceMsg += (balanceMsg.isEmpty ? "" : " & ") + sarBal;
    if (balanceMsg.isEmpty) balanceMsg = yerBal;

    final message = "Hello ${_currentCustomer.name}, your current balance at Raseed is $balanceMsg.";
    final url = "https://wa.me/${_currentCustomer.phone}?text=${Uri.encodeComponent(message)}";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_currentCustomer.name),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {}, // Implementation later
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: EdgeInsets.all(20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCustomerHeader(),
                SizedBox(height: 30.h),
                _buildActionButtons(),
                SizedBox(height: 30.h),
                Text(
                  'transaction_history'.tr(),
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 15.h),
                _buildTransactionList(),
              ],
            ),
          ),
    );
  }

  Widget _buildCustomerHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'current_balance'.tr(),
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13.sp, fontWeight: FontWeight.w500, letterSpacing: 1),
          ),
          SizedBox(height: 15.h),
          if (_currentCustomer.totalDebt > 0 || _currentCustomer.totalDebtSar == 0)
            FittedBox(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    CurrencyHelper.getFormatter('YER').format(_currentCustomer.totalDebt),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'YER',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          if (_currentCustomer.totalDebt > 0 && _currentCustomer.totalDebtSar > 0)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: Container(height: 1, width: 40.w, color: Colors.white24),
            ),
          if (_currentCustomer.totalDebtSar > 0)
            FittedBox(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    CurrencyHelper.getFormatter('SAR').format(_currentCustomer.totalDebtSar),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'SAR',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: 20.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.phone, color: Colors.white70, size: 14),
              SizedBox(width: 8.w),
              Text(
                _currentCustomer.phone,
                style: TextStyle(color: Colors.white70, fontSize: 14.sp, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ActionButton(
          label: 'add_debt'.tr(),
          icon: Icons.add_circle_outline,
          color: AppColors.error,
          onTap: () => _showTransactionDialog(TransactionType.debt),
        ),
        _ActionButton(
          label: 'get_payment'.tr(),
          icon: Icons.check_circle_outline,
          color: AppColors.success,
          onTap: () => _showTransactionDialog(TransactionType.payment),
        ),
        _ActionButton(
          label: 'whatsapp'.tr(),
          icon: Icons.chat_bubble_outline,
          color: AppColors.secondary,
          onTap: _openWhatsApp,
        ),
      ],
    );
  }

  Widget _buildTransactionList() {
    if (_transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.only(top: 40.h),
          child: Text('no_transactions'.tr()),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        final isDebt = tx.type == TransactionType.debt;
        
        return Container(
          margin: EdgeInsets.only(bottom: 15.h),
          padding: EdgeInsets.all(15.w),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(15.r),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: (isDebt ? AppColors.error : AppColors.success).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDebt ? Icons.arrow_upward : Icons.arrow_downward,
                  color: isDebt ? AppColors.error : AppColors.success,
                  size: 20,
                ),
              ),
              SizedBox(width: 15.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDebt ? 'debt'.tr() : 'payment'.tr(),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp),
                    ),
                    Text(
                      DateFormat('MMM dd, yyyy').format(tx.date),
                      style: TextStyle(color: Colors.grey, fontSize: 12.sp),
                    ),
                  ],
                ),
              ),
              Text(
                '${isDebt ? '+' : '-'}${CurrencyHelper.getSymbol(tx.currency)} ${tx.amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16.sp,
                  color: isDebt ? AppColors.error : AppColors.success,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTransactionDialog(TransactionType type) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String selectedCurrency = _settings?.currency ?? 'YER';
    DateTime selectedDate = DateTime.now();
 
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(type == TransactionType.debt ? 'add_debt'.tr() : 'get_payment'.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
 
                try {
                  await _transactionService.addTransaction(AppTransaction(
                    customerId: _currentCustomer.id,
                    type: type,
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

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 100.w,
        padding: EdgeInsets.symmetric(vertical: 15.h),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(15.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28.sp),
            SizedBox(height: 8.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
