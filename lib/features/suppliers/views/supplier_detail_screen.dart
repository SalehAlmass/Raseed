import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/supplier.dart';
import '../../../core/models/supplier_transaction.dart';
import '../../../core/models/product.dart';
import '../../../core/services/product_service.dart';
import '../../../core/services/supplier_service.dart';
import '../../../core/services/supplier_transaction_service.dart';
import '../../reports/services/report_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/currency_helper.dart';
import 'purchase_screen.dart';
import 'create_purchase_order_screen.dart';

class SupplierDetailScreen extends StatefulWidget {
  final Supplier supplier;
  const SupplierDetailScreen({super.key, required this.supplier});

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  final SupplierService _supplierService = sl<SupplierService>();
  final SupplierTransactionService _transactionService = sl<SupplierTransactionService>();
  
  late Supplier _supplier;
  List<SupplierTransaction> _transactions = [];
  List<Product> _products = [];
  List<Map<String, dynamic>> _lowStockItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _supplier = widget.supplier;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final updatedSupplier = await _supplierService.getSupplierById(_supplier.id!);
    final transactions = await _transactionService.getTransactionsBySupplier(_supplier.id!);
    final lowStock = await sl<ReportService>().getLowStockBySupplier(_supplier.id!);
    final products = await sl<ProductService>().getProductsBySupplier(_supplier.id!);
    
    setState(() {
      if (updatedSupplier != null) _supplier = updatedSupplier;
      _transactions = transactions;
      _lowStockItems = lowStock;
      _products = products;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_supplier.name),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(20.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDebtCard(),
                          SizedBox(height: 20.h),
                          _buildActionButtons(),
                          if (_lowStockItems.isNotEmpty) ...[
                            SizedBox(height: 30.h),
                            _buildLowStockSection(),
                          ],
                          SizedBox(height: 30.h),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(15.r),
                            ),
                            child: TabBar(
                              labelColor: AppColors.primary,
                              unselectedLabelColor: Colors.grey,
                              indicatorColor: AppColors.primary,
                              indicatorSize: TabBarIndicatorSize.label,
                              tabs: [
                                Tab(text: 'account_statement'.tr()),
                                Tab(text: 'products'.tr()),
                              ],
                            ),
                          ),
                          SizedBox(height: 20.h),
                          SizedBox(
                            height: 500.h, // Fixed height for tab content
                            child: TabBarView(
                              children: [
                                _buildTransactionList(),
                                _buildProductList(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDebtCard() {
    return Container(
      width: double.infinity,
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
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_supplier.rating > 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10.r)),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                      SizedBox(width: 4.w),
                      Text(_supplier.rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              else
                const SizedBox.shrink(),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                onPressed: () => _showEditRatingDialog(),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    'total_paid'.tr(),
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13.sp),
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    CurrencyHelper.getFormatter('YER').format(_supplier.totalPaid),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(height: 40.h, width: 1, color: Colors.white24),
              Column(
                children: [
                  Text(
                    'remaining'.tr(),
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13.sp),
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    CurrencyHelper.getFormatter('YER').format(_supplier.totalDebt),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_supplier.company != null) ...[
            SizedBox(height: 15.h),
            Text(
              _supplier.company!,
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13.sp, fontWeight: FontWeight.w500),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildLowStockSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8.w),
            Text(
              'low_stock_alerts'.tr(),
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.orange[800]),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Container(
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.05),
            borderRadius: BorderRadius.circular(15.r),
            border: Border.all(color: Colors.orange.withOpacity(0.2)),
          ),
          child: Column(
            children: _lowStockItems.map((item) {
              return ListTile(
                dense: true,
                title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Text(
                  '${item['stock_quantity']} / ${item['reorder_level']}',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'purchase'.tr(),
                icon: Icons.add_shopping_cart,
                color: AppColors.primary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PurchaseScreen(initialSupplier: _supplier),
                  ),
                ).then((_) => _loadData()),
              ),
            ),
            SizedBox(width: 15.w),
            Expanded(
              child: _ActionButton(
                label: 'pay_supplier'.tr(),
                icon: Icons.payment,
                color: AppColors.success,
                onTap: () => _showPaymentDialog(),
              ),
            ),
          ],
        ),
        SizedBox(height: 15.h),
        _ActionButton(
          label: 'create_po'.tr(),
          icon: Icons.assignment_outlined,
          color: Colors.orange,
          isFullWidth: true,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreatePurchaseOrderScreen(initialSupplier: _supplier),
            ),
          ).then((_) => _loadData()),
        ),
      ],
    );
  }

  void _showEditRatingDialog() {
    double currentRating = _supplier.rating;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('rating'.tr()),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < currentRating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: Colors.amber,
                  size: 32.sp,
                ),
                onPressed: () => setDialogState(() => currentRating = index + 1.0),
              );
            }),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
            ElevatedButton(
              onPressed: () async {
                await _supplierService.updateSupplierRating(_supplier.id!, currentRating);
                if (mounted) {
                  Navigator.pop(context);
                  _loadData();
                }
              },
              child: Text('save'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentDialog() {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('pay_supplier'.tr()),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountController,
                decoration: InputDecoration(labelText: 'amount'.tr()),
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'required_field'.tr();
                  if (double.tryParse(val) == null) return 'invalid_number'.tr();
                  return null;
                },
              ),
              TextFormField(
                controller: noteController,
                decoration: InputDecoration(labelText: 'note'.tr()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final amount = double.parse(amountController.text);
                final tx = SupplierTransaction(
                  supplierId: _supplier.id!,
                  type: SupplierTransactionType.payment,
                  amount: amount,
                  date: DateTime.now(),
                  note: noteController.text,
                );
                await _transactionService.addTransaction(tx);
                if (mounted) {
                  Navigator.pop(context);
                  _loadData();
                }
              }
            },
            child: Text('save'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    if (_transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.only(top: 40.h),
          child: Text('no_transactions'.tr(), style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _transactions.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        final isPurchase = tx.type == SupplierTransactionType.purchase;
        
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: (isPurchase ? AppColors.error : AppColors.success).withOpacity(0.1),
            child: Icon(
              isPurchase ? Icons.arrow_upward : Icons.arrow_downward,
              color: isPurchase ? AppColors.error : AppColors.success,
              size: 20,
            ),
          ),
          title: Text(
            isPurchase ? 'purchase'.tr() : 'payment'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            DateFormat('MMM dd, yyyy').format(tx.date),
            style: TextStyle(fontSize: 12.sp, color: Colors.grey),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyHelper.getFormatter(tx.currency).format(tx.amount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isPurchase ? AppColors.error : AppColors.success,
                ),
              ),
              if (tx.isVoid)
                Text(
                  'voided'.tr(),
                  style: TextStyle(color: Colors.red, fontSize: 10.sp, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          onTap: () {
            if (isPurchase) _showPurchaseInvoice(tx);
          },
          onLongPress: () {
             if (!tx.isVoid) _showVoidConfirmation(tx);
          },
        );
      },
    );
  }

  void _showPurchaseInvoice(SupplierTransaction tx) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Row(
          children: [
            const Icon(Icons.receipt_long_outlined, color: AppColors.primary),
            SizedBox(width: 10.w),
            Text('purchase_invoice'.tr()),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${'date'.tr()}: ${DateFormat('yyyy/MM/dd HH:mm').format(tx.date)}',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey),
              ),
              const Divider(),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: tx.items.length,
                  itemBuilder: (context, i) {
                    final item = tx.items[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${item.quantity} x ${CurrencyHelper.getFormatter(tx.currency).format(item.costPrice)}'),
                      trailing: Text(
                        CurrencyHelper.getFormatter(tx.currency).format(item.total),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
              _buildInvoiceRow('total_amount'.tr(), tx.amount, isBold: true),
              _buildInvoiceRow('paid_amount'.tr(), tx.paidAmount, color: AppColors.success),
              _buildInvoiceRow('remaining'.tr(), tx.amount - tx.paidAmount, color: AppColors.error, isBold: true),
              if (tx.note != null && tx.note!.isNotEmpty) ...[
                SizedBox(height: 10.h),
                Text('${'note'.tr()}: ${tx.note}', style: TextStyle(fontSize: 12.sp, fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('done'.tr())),
          ElevatedButton.icon(
            onPressed: () => _shareInvoice(tx),
            icon: const Icon(Icons.share, size: 18),
            label: Text('whatsapp'.tr()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceRow(String label, double value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13.sp, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            CurrencyHelper.getFormatter('YER').format(value),
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _shareInvoice(SupplierTransaction tx) async {
    String phone = _supplier.phone;
    phone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (phone.startsWith('0')) phone = phone.substring(1);
    if (!phone.startsWith('+') && !phone.startsWith('00') && !phone.startsWith('967')) {
      phone = '967$phone';
    }
    phone = phone.replaceAll('+', '').replaceAll('00', '');

    String message = '📦 *${'purchase_invoice'.tr()}*\n';
    message += '📅 ${DateFormat('yyyy/MM/dd').format(tx.date)}\n';
    message += '👤 ${'supplier'.tr()}: ${_supplier.name}\n';
    message += '--------------------------\n';
    for (var item in tx.items) {
      message += '🔹 ${item.productName}: ${item.quantity} x ${item.costPrice} = ${item.total}\n';
    }
    message += '--------------------------\n';
    message += '💰 *${'total_amount'.tr()}: ${tx.amount}*\n';
    message += '✅ ${'paid_amount'.tr()}: ${tx.paidAmount}\n';
    message += '⏳ *${'remaining'.tr()}: ${tx.amount - tx.paidAmount}*\n';
    
    final url = "https://wa.me/$phone?text=${Uri.encodeComponent(message)}";
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _showVoidConfirmation(SupplierTransaction tx) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('void_transaction'.tr()),
        content: Text('void_confirmation_desc'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
          ElevatedButton(
            onPressed: () async {
              await _transactionService.voidTransaction(tx.id!);
              if (mounted) {
                Navigator.pop(context);
                _loadData();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );
  }
  Widget _buildProductList() {
    if (_products.isEmpty) {
      return Center(
        child: Text('no_products'.tr(), style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.separated(
      itemCount: _products.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final product = _products[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
          ),
          title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
            sl<ProductService>().formatStock(product.stockQuantity, product.conversionFactor),
            style: TextStyle(fontSize: 12.sp),
          ),
          trailing: Text(
            CurrencyHelper.getFormatter(product.currency).format(product.price),
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
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
  final bool isFullWidth;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.isFullWidth = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15.r),
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: EdgeInsets.all(15.w),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15.r),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24.sp),
            SizedBox(height: 8.h),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
