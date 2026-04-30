import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/services/customer_service.dart';
import '../../../core/services/transaction_service.dart';
import '../../reports/services/export_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/app_transaction.dart';
import '../../../core/utils/currency_helper.dart';
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
  final ExportService _exportService = sl<ExportService>();
  late Customer _currentCustomer;
  List<AppTransaction> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentCustomer = widget.customer;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final transactions = await _transactionService.getCustomerTransactions(
      _currentCustomer.id!,
    );
    final customer = await _customerService.getCustomer(_currentCustomer.id!);
    setState(() {
      _transactions = transactions;
      if (customer != null) _currentCustomer = customer;
      _isLoading = false;
    });
  }

  Future<void> _openWhatsApp() async {
    final String yerBal = CurrencyHelper.getFormatter(
      'YER',
    ).format(_currentCustomer.totalDebt);
    String balanceMsg = yerBal;

    String phone = _currentCustomer.phone;
    phone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (phone.startsWith('0')) phone = phone.substring(1);
    if (!phone.startsWith('+') &&
        !phone.startsWith('00') &&
        !phone.startsWith('967')) {
      phone = '967$phone';
    }
    phone = phone.replaceAll('+', '').replaceAll('00', '');
    if (phone.startsWith('967') && phone.length == 12 && phone[3] == '0') {
      phone = '967${phone.substring(4)}';
    }

    final message = 'whatsapp_reminder_msg'.tr(
      namedArgs: {'name': _currentCustomer.name, 'balance': balanceMsg},
    );
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

  Future<void> _exportPdf() async {
    try {
      await _exportService.exportCustomerTransactionsToPdf(
        _currentCustomer,
        _transactions,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('error_occurred'.tr())));
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
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 15.h),
          FittedBox(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  CurrencyHelper.getFormatter(
                    'YER',
                  ).format(_currentCustomer.totalDebt),
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
          SizedBox(height: 20.h),
          InkWell(
            onTap: _openWhatsApp,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.phone, color: Colors.white70, size: 14),
                SizedBox(width: 8.w),
                Text(
                  _currentCustomer.phone,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ActionButton(
          label: 'export_pdf'.tr(),
          icon: Icons.picture_as_pdf_outlined,
          color: Colors.redAccent,
          onTap: _exportPdf,
        ),
        SizedBox(width: 20.w),
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
        final isRefund = tx.type == TransactionType.refund;
        final isSale = tx.type == TransactionType.sale;

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
                  color: (isRefund ? AppColors.error : AppColors.success)
                      .withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isRefund
                      ? Icons.keyboard_return
                      : (isSale ? Icons.shopping_cart : Icons.payment),
                  color: isRefund ? AppColors.error : AppColors.success,
                  size: 20,
                ),
              ),
              SizedBox(width: 15.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          tx.type.name.tr(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                            decoration: tx.isVoid ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (tx.isVoid) ...[
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              'voided'.tr(),
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      DateFormat('MMM dd, yyyy').format(tx.date),
                      style: TextStyle(color: Colors.grey, fontSize: 12.sp),
                    ),
                  ],
                ),
              ),
              Text(
                '${isRefund ? '+' : '-'}${CurrencyHelper.getSymbol(tx.currency)} ${tx.amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16.sp,
                  color: tx.isVoid ? Colors.grey : (isRefund ? AppColors.error : AppColors.success),
                  decoration: tx.isVoid ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
        );
      },
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
        width: 120.w,
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
