import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../di/injection_container.dart';
import '../models/app_transaction.dart';
import '../models/customer.dart';
import '../services/customer_service.dart';
import '../services/transaction_service.dart';
import '../services/receipt_service.dart';
import '../services/printer_service.dart';
import '../services/settings_service.dart';
import '../../features/reports/services/export_service.dart';
import '../theme/colors.dart';
import '../utils/currency_helper.dart';

class TransactionDetailSheet extends StatefulWidget {
  final AppTransaction transaction;

  const TransactionDetailSheet({super.key, required this.transaction});

  static Future<bool?> show(BuildContext context, AppTransaction transaction) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransactionDetailSheet(transaction: transaction),
    );
  }

  @override
  State<TransactionDetailSheet> createState() => _TransactionDetailSheetState();
}

class _TransactionDetailSheetState extends State<TransactionDetailSheet> {
  final CustomerService _customerService = sl<CustomerService>();
  final TransactionService _transactionService = sl<TransactionService>();
  final ExportService _exportService = sl<ExportService>();
  final ReceiptService _receiptService = sl<ReceiptService>();
  final PrinterService _printerService = sl<PrinterService>();

  Customer? _customer;
  bool _isLoadingCustomer = false;
  bool _isVoiding = false;

  @override
  void initState() {
    super.initState();
    _loadCustomer();
  }

  Future<void> _loadCustomer() async {
    if (widget.transaction.customerId == null) return;
    setState(() => _isLoadingCustomer = true);
    try {
      final customer = await _customerService.getCustomer(widget.transaction.customerId!);
      if (mounted) {
        setState(() {
          _customer = customer;
          _isLoadingCustomer = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCustomer = false);
    }
  }

  Future<void> _exportA4Invoice(BuildContext context) async {
    _showLoadingDialog(context);
    try {
      final pdf = await _exportService.generateSingleTransactionInvoicePdf(
        widget.transaction,
        customer: _customer,
      );
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        await Printing.layoutPdf(
          onLayout: (format) async => pdf.save(),
          name: 'invoice_${widget.transaction.id ?? "new"}.pdf',
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_occurred'.tr()), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _shareA4Invoice(BuildContext context) async {
    _showLoadingDialog(context);
    try {
      await _exportService.exportSingleTransactionInvoiceToPdf(
        widget.transaction,
        customer: _customer,
      );
      if (context.mounted) {
        Navigator.pop(context); // Close loading
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_occurred'.tr()), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _printPOSReceipt(BuildContext context) async {
    _showLoadingDialog(context);
    try {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        await _receiptService.printReceipt(widget.transaction, customer: _customer);
      }
    } catch (_) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_occurred'.tr()), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _printThermal(BuildContext context) async {
    _showLoadingDialog(context);
    try {
      List<BluetoothDevice> devices = await _printerService.getDevices();
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        if (devices.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('no_bluetooth_devices'.tr()), backgroundColor: AppColors.error),
          );
          return;
        }

        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('select_printer'.tr()),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final d = devices[index];
                  return ListTile(
                    title: Text(d.name ?? 'Unknown'),
                    subtitle: Text(d.address ?? ''),
                    onTap: () async {
                      Navigator.pop(context);
                      await _printerService.printReceipt(
                        device: d,
                        transaction: widget.transaction,
                        customer: _customer,
                        paperSize: PaperSize.mm58,
                      );
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('cancel'.tr()),
              ),
            ],
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
      }
    }
  }

  Future<void> _openWhatsAppReminder() async {
    if (_customer == null || _customer!.phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('customer_phone_missing'.tr()), backgroundColor: AppColors.error),
      );
      return;
    }

    final currency = widget.transaction.currency;
    final formattedTotal = CurrencyHelper.getFormatter(currency).format(widget.transaction.amount);
    final formattedPaid = CurrencyHelper.getFormatter(currency).format(widget.transaction.paidAmount);
    final formattedDebt = CurrencyHelper.getFormatter(currency).format(_customer!.totalDebt);

    String message = 'whatsapp_msg_greeting'.tr(namedArgs: {'name': _customer!.name});
    if (widget.transaction.type == TransactionType.sale) {
      message += 'whatsapp_msg_sale'.tr(namedArgs: {'total': formattedTotal});
      if (widget.transaction.paidAmount > 0) {
        message += 'whatsapp_msg_paid'.tr(namedArgs: {'paid': formattedPaid});
      }
      message += 'whatsapp_msg_balance'.tr(namedArgs: {'balance': formattedDebt});
    } else if (widget.transaction.type == TransactionType.payment) {
      message += 'whatsapp_msg_payment'.tr(namedArgs: {'amount': formattedTotal, 'balance': formattedDebt});
    }

    String phone = _customer!.phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (phone.startsWith('0')) phone = phone.substring(1);
    if (!phone.startsWith('+') && !phone.startsWith('00') && !phone.startsWith('967')) {
      phone = '967$phone';
    }
    phone = phone.replaceAll('+', '').replaceAll('00', '');

    final url = "https://wa.me/$phone?text=${Uri.encodeComponent(message)}";
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('could_not_launch_whatsapp'.tr())),
        );
      }
    }
  }

  Future<void> _voidTransaction(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('void_transaction'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
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
      setState(() => _isVoiding = true);
      try {
        await _transactionService.voidTransaction(widget.transaction);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('void_success'.tr()), backgroundColor: AppColors.success),
          );
          Navigator.pop(context, true); // Pop details sheet and return refresh flag
        }
      } catch (_) {
        if (mounted) {
          setState(() => _isVoiding = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('error_occurred'.tr()), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 24.w),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)),
                SizedBox(width: 20.w),
                Text('loading'.tr(), style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tx = widget.transaction;
    final isSale = tx.type == TransactionType.sale;
    final isRefund = tx.type == TransactionType.refund;
    final isPayment = tx.type == TransactionType.payment;

    String titleText = 'transaction_details'.tr();
    Color statusColor = AppColors.success;
    IconData headerIcon = Icons.receipt_long;

    if (isSale) {
      titleText = tx.items.isNotEmpty ? 'sales_invoice'.tr() : 'add_debt'.tr();
      statusColor = AppColors.success;
      headerIcon = Icons.shopping_cart;
    } else if (isPayment) {
      titleText = 'payment_receipt'.tr();
      statusColor = AppColors.primary;
      headerIcon = Icons.arrow_downward;
    } else if (isRefund) {
      titleText = 'refund_voucher'.tr();
      statusColor = AppColors.error;
      headerIcon = Icons.keyboard_return;
    }

    final currencySymbol = CurrencyHelper.getSymbol(tx.currency);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        children: [
          // Drag handle and top bar
          Container(
            margin: EdgeInsets.only(top: 10.h, bottom: 5.h),
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(headerIcon, color: tx.isVoid ? Colors.grey : statusColor, size: 24.sp),
                    SizedBox(width: 8.w),
                    Text(
                      titleText,
                      style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable body
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Info Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: (tx.isVoid ? AppColors.error : statusColor).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          tx.isVoid ? 'voided'.tr() : 'active'.tr(),
                          style: TextStyle(
                            color: tx.isVoid ? AppColors.error : statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.sp,
                          ),
                        ),
                      ),
                      Text(
                        '#${tx.id ?? "NEW"}',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // Metadata section
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow('date'.tr(), DateFormat('yyyy-MM-dd hh:mm a').format(tx.date)),
                        if (tx.note.isNotEmpty) ...[
                          const Divider(height: 20),
                          _buildInfoRow('note'.tr(), tx.note),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Customer Details Panel
                  if (_isLoadingCustomer)
                    const Center(child: CircularProgressIndicator())
                  else if (_customer != null) ...[
                    Text(
                      'customer'.tr(),
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _customer!.name,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
                              ),
                              if (_customer!.phone.isNotEmpty)
                                Text(
                                  _customer!.phone,
                                  style: TextStyle(color: Colors.grey, fontSize: 13.sp),
                                ),
                            ],
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              '${_customer!.totalDebt.toStringAsFixed(0)} $currencySymbol',
                              style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                  ],

                  // Items List (For Sales / Refunds)
                  if (tx.items.isNotEmpty) ...[
                    Text(
                      'items'.tr(),
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: tx.items.length,
                        separatorBuilder: (context, index) => const Divider(height: 20),
                        itemBuilder: (context, index) {
                          final item = tx.items[index];
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
                                    ),
                                    Text(
                                      '${item.quantity} x ${item.price.toStringAsFixed(0)} $currencySymbol',
                                      style: TextStyle(color: Colors.grey, fontSize: 12.sp),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${item.total.toStringAsFixed(0)} $currencySymbol',
                                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14.sp),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 16.h),
                  ],

                  // Calculation Totals Block
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        _buildCalculationRow('total_amount'.tr(), tx.amount, currencySymbol),
                        if (isSale && tx.paidAmount > 0) ...[
                          const SizedBox(height: 8),
                          _buildCalculationRow('paid_amount'.tr(), tx.paidAmount, currencySymbol),
                        ],
                        if (isSale && (tx.amount - tx.paidAmount) > 0) ...[
                          const SizedBox(height: 8),
                          _buildCalculationRow(
                            'remaining_amount'.tr(),
                            tx.amount - tx.paidAmount,
                            currencySymbol,
                            isBold: true,
                            color: Colors.orange[800],
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Actions Section
                  Text(
                    'actions'.tr(),
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                  SizedBox(height: 12.h),

                  // Modern grid of custom print/export options
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12.w,
                    mainAxisSpacing: 12.h,
                    childAspectRatio: 2.2,
                    children: [
                      // A4 Export Invoice
                      _buildActionButton(
                        icon: Icons.picture_as_pdf,
                        label: 'export_pdf'.tr(),
                        color: const Color(0xFFE74C3C),
                        onTap: () => _exportA4Invoice(context),
                      ),
                      // A4 Share Invoice
                      _buildActionButton(
                        icon: Icons.share,
                        label: 'share'.tr(),
                        color: Colors.blueGrey,
                        onTap: () => _shareA4Invoice(context),
                      ),
                      // POS Receipt
                      _buildActionButton(
                        icon: Icons.receipt,
                        label: 'POS (PDF)',
                        color: const Color(0xFF2C3E50),
                        onTap: () => _printPOSReceipt(context),
                      ),
                      // Thermal Print
                      _buildActionButton(
                        icon: Icons.bluetooth,
                        label: 'Thermal',
                        color: AppColors.primary,
                        onTap: () => _printThermal(context),
                      ),
                      // WhatsApp
                      if (_customer != null && _customer!.phone.isNotEmpty)
                        _buildActionButton(
                          icon: Icons.chat,
                          label: 'WhatsApp',
                          color: AppColors.secondary,
                          onTap: _openWhatsAppReminder,
                        ),
                      // Void Transaction
                      if (!tx.isVoid)
                        _buildActionButton(
                          icon: Icons.delete_forever,
                          label: 'void'.tr(),
                          color: AppColors.error,
                          onTap: () => _voidTransaction(context),
                        ),
                    ],
                  ),
                  SizedBox(height: 30.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildCalculationRow(String label, double value, String symbol, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isBold ? (color ?? AppColors.textPrimary) : AppColors.textSecondary,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 15.sp : 13.sp,
          ),
        ),
        Text(
          '${value.toStringAsFixed(0)} $symbol',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color ?? AppColors.textPrimary,
            fontSize: isBold ? 16.sp : 13.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20.sp),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.sp,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
