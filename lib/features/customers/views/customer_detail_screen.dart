import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:printing/printing.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/app_feature.dart';
import '../../../core/services/customer_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/services/transaction_service.dart';
import '../../reports/services/export_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/desktop_tokens.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/app_transaction.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/widgets/desktop/desktop_scaffold.dart';
import '../../../core/widgets/desktop/desktop_table.dart';
import '../../../core/widgets/desktop/page_header.dart';
import '../../../core/widgets/desktop/responsive.dart';
import '../../../core/widgets/desktop/stat_card.dart';
import '../../../core/widgets/subscription_dialog.dart';
import '../../../core/widgets/transaction_detail_sheet.dart';
import '../../../core/routes/routes.dart';

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

  Future<void> _exportPdf({bool directShare = true}) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false, // Prevent dismissing by back button
          child: Dialog(
            backgroundColor: AppColors.of(context).surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.r),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 24.w),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                  SizedBox(width: 20.w),
                  Text(
                    'loading'.tr(),
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.of(context).textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      final pdf = await _exportService.generateCustomerTransactionsPdf(
        _currentCustomer,
        _transactions,
      );
      if (directShare) {
        await Printing.sharePdf(
          bytes: await pdf.save(),
          filename: 'customer_${_currentCustomer.id}_${DateTime.now().millisecondsSinceEpoch}.pdf',
        );
      } else {
        await Printing.layoutPdf(
          onLayout: (format) async => pdf.save(),
          name: 'customer_${_currentCustomer.id}_${DateTime.now().millisecondsSinceEpoch}.pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('error_occurred'.tr())));
      }
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog
      }
    }
  }

  Future<void> _showExportOptionsDialog() async {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          backgroundColor: theme.colorScheme.surface,
          title: Text(
            'export_statement_title'.tr(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16.sp,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogOption(
                icon: Icons.share_rounded,
                color: const Color(0xFF00B894),
                title: 'send_to_customer'.tr(),
                subtitle: 'send_to_customer_desc'.tr(),
                onTap: () {
                  Navigator.pop(context);
                  _exportPdf(directShare: true);
                },
              ),
              SizedBox(height: 12.h),
              _buildDialogOption(
                icon: Icons.picture_as_pdf_rounded,
                color: const Color(0xFFE74C3C),
                title: 'preview_statement_option'.tr(),
                subtitle: 'preview_statement_desc'.tr(),
                onTap: () {
                  Navigator.pop(context);
                  _exportPdf(directShare: false);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDialogOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15.r),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.15),
          ),
          borderRadius: BorderRadius.circular(15.r),
          color: isDark ? theme.colorScheme.background : Colors.grey[50],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.sp,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DesktopScaffold(
      activeNavIndex: 1,
      title: _currentCustomer.name,
      extendBody: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: () {}, // Implementation later
          tooltip: 'edit'.tr(),
        ),
        IconButton(
          icon: const Icon(Icons.replay, color: Colors.orange),
          tooltip: 'sales_return'.tr(),
          onPressed: () => Navigator.pushNamed(context, Routes.salesReturn),
        ),
      ],
      onNavigate: _onNavTap,
      body: _buildMobileBody(),
      desktopBody: _buildDesktopBody(),
    );
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, Routes.home);
        break;
      case 1:
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

  Widget _buildMobileBody() {
    return _isLoading
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
                    color: AppColors.of(context).textPrimary,
                  ),
                ),
                SizedBox(height: 15.h),
                _buildTransactionList(),
              ],
            ),
          );
  }

  Widget _buildDesktopBody() {
    final colors = AppColors.of(context);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: DesktopMetrics.contentMaxWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: _currentCustomer.name,
                subtitle: _currentCustomer.phone,
                actions: [
                  OutlinedButton.icon(
                    onPressed: _showExportOptionsDialog,
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: Text('export_pdf'.tr()),
                  ),
                  FilledButton.icon(
                    onPressed: _openWhatsApp,
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: Text('whatsapp'.tr()),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              _buildDesktopStats(),
              const SizedBox(height: AppSpace.lg),
              _buildDesktopTransactionsTable(colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopStats() {
    final isDebtor = _currentCustomer.totalDebt > 0;
    return ResponsiveGrid(
      columns: 3,
      children: [
        StatCard(
          title: 'current_balance'.tr(),
          value: CurrencyHelper.getFormatter('YER')
              .format(_currentCustomer.totalDebt),
          icon: Icons.account_balance_wallet_outlined,
          color: isDebtor ? AppColors.error : AppColors.success,
        ),
        StatCard(
          title: 'spent'.tr(),
          value: CurrencyHelper.getFormatter('YER')
              .format(_currentCustomer.totalSpent),
          icon: Icons.payments_outlined,
          color: AppColors.primary,
        ),
        StatCard(
          title: 'transaction_history'.tr(),
          value: '${_transactions.length}',
          icon: Icons.receipt_long_outlined,
          color: AppColors.secondary,
        ),
      ],
    );
  }

  Widget _buildDesktopTransactionsTable(AppColorSet colors) {
    final rows = _transactions.map((tx) {
      final isRefund = tx.type == TransactionType.refund;
      final isSale = tx.type == TransactionType.sale;
      final isVoid = tx.isVoid;
      return <Widget>[
        Row(
          children: [
            Icon(
              isRefund
                  ? Icons.keyboard_return
                  : (isSale ? Icons.shopping_cart : Icons.payment),
              size: 16,
              color: isRefund ? AppColors.error : AppColors.success,
            ),
            const SizedBox(width: AppSpace.xs),
            Text(
              tx.type.name.tr(),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                decoration: isVoid ? TextDecoration.lineThrough : null,
              ),
            ),
            if (isVoid) ...[
              const SizedBox(width: AppSpace.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  'voided'.tr(),
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        Text(
          DateFormat('MMM dd, yyyy').format(tx.date),
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
        Text(
          '${isRefund ? '+' : '-'}${CurrencyHelper.getSymbol(tx.currency)} ${tx.amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isVoid
                ? Colors.grey
                : (isRefund ? AppColors.error : AppColors.success),
            decoration: isVoid ? TextDecoration.lineThrough : null,
          ),
        ),
        IconButton(
          tooltip: 'view'.tr(),
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          onPressed: () async {
            final refresh = await TransactionDetailSheet.show(context, tx);
            if (refresh == true) {
              _loadData();
            }
          },
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ];
    }).toList();
    return DesktopTable(
      headers: [
        'type'.tr(),
        'date'.tr(),
        'amount'.tr(),
        '',
      ],
      flexes: const [4, 2, 2, 1],
      rows: rows,
      emptyMessage: 'no_transactions'.tr(),
      maxHeight: 520,
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
          onTap: _showExportOptionsDialog,
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

        return InkWell(
          onTap: () async {
            final refresh = await TransactionDetailSheet.show(context, tx);
            if (refresh == true) {
              _loadData();
            }
          },
          borderRadius: BorderRadius.circular(15.r),
          child: Container(
            margin: EdgeInsets.only(bottom: 15.h),
            padding: EdgeInsets.all(15.w),
            decoration: BoxDecoration(
              color: AppColors.of(context).surface,
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
          color: AppColors.of(context).surface,
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
                color: AppColors.of(context).textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
