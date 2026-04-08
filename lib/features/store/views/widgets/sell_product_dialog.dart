import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/models/app_transaction.dart';
import '../../../../core/models/customer.dart';
import '../../../../core/models/product.dart';
import '../../../../core/services/customer_service.dart';
import '../../../../core/services/product_service.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency_helper.dart';

class SellProductDialog extends StatefulWidget {
  final Product product;

  const SellProductDialog({super.key, required this.product});

  @override
  State<SellProductDialog> createState() => _SellProductDialogState();
}

class _SellProductDialogState extends State<SellProductDialog> {
  final _productService = sl<ProductService>();
  final _customerService = sl<CustomerService>();
  final _quantityController = TextEditingController(text: '1');
  
  TransactionType _selectedType = TransactionType.sale;
  List<Customer> _customers = [];
  Customer? _selectedCustomer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final list = await _customerService.getAllCustomers();
    if (mounted) setState(() => _customers = list);
  }

  Future<void> _sell() async {
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    if (quantity <= 0) return;
    
    if (_selectedType == TransactionType.sale && _selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a customer'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _productService.sellProduct(
        product: widget.product,
        quantity: quantity,
        type: _selectedType,
        customerId: _selectedType == TransactionType.sale ? _selectedCustomer!.id : null,
      );
      
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        String errMsg = 'error_occurred'.tr();
        if (e.toString().contains('uninsufficient_stock')) errMsg = 'Not enough stock!';
        if (e.toString().contains('over_limit')) errMsg = 'over_limit_error'.tr();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errMsg), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quantity = int.tryParse(_quantityController.text) ?? 1;
    final totalPrice = widget.product.price * quantity;

    return AlertDialog(
      title: Text('Sell ${widget.product.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Price: ${CurrencyHelper.getFormatter('YER').format(widget.product.price)} YER'),
                  Text('Stock: ${widget.product.stockQuantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            SizedBox(height: 20.h),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              onChanged: (val) => setState(() {}),
            ),
            SizedBox(height: 15.h),
            SegmentedButton<TransactionType>(
              segments: [
                ButtonSegment(value: TransactionType.sale, label: Text('cash_sale'.tr())),
                ButtonSegment(value: TransactionType.payment, label: Text('payment'.tr())),
              ],
              selected: {_selectedType},
              onSelectionChanged: (set) => setState(() => _selectedType = set.first),
            ),
            if (_selectedType == TransactionType.sale) ...[
              SizedBox(height: 15.h),
              DropdownButtonFormField<Customer>(
                value: _selectedCustomer,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'customers'.tr(),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
                items: _customers.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                onChanged: (val) => setState(() => _selectedCustomer = val),
              ),
            ],
            SizedBox(height: 20.h),
            Center(
              child: Text(
                'Total: ${CurrencyHelper.getFormatter('YER').format(totalPrice)} YER',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _sell,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
          child: _isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text('confirm_sale'.tr()),
        ),
      ],
    );
  }
}
