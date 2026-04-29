import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/supplier.dart';
import '../../../core/models/supplier_transaction.dart';
import '../../../core/services/supplier_service.dart';
import '../../../core/services/supplier_transaction_service.dart';
import '../../reports/services/report_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/currency_helper.dart';
import 'purchase_screen.dart';

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
    
    setState(() {
      if (updatedSupplier != null) _supplier = updatedSupplier;
      _transactions = transactions;
      _lowStockItems = lowStock;
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
          : SingleChildScrollView(
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
                  Text(
                    'account_statement'.tr(),
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

  Widget _buildDebtCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.error, AppColors.error.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'supplier_debt'.tr(),
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            CurrencyHelper.getFormatter('YER').format(_supplier.totalDebt),
            style: TextStyle(
              color: Colors.white,
              fontSize: 28.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_supplier.company != null) ...[
            SizedBox(height: 12.h),
            Text(
              _supplier.company!,
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13.sp),
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
    return Row(
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
          onLongPress: () {
             if (!tx.isVoid) _showVoidConfirmation(tx);
          },
        );
      },
    );
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
      borderRadius: BorderRadius.circular(15.r),
      child: Container(
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
