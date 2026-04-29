import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/models/app_transaction.dart';
import '../../../../core/models/customer.dart';
import '../../../../core/models/product.dart';
import '../../../../core/models/unit.dart';
import '../../../../core/services/customer_service.dart';
import '../../../../core/services/product_service.dart';
import '../../../../core/services/unit_service.dart';
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
  final _unitService = sl<UnitService>();
  final _quantityController = TextEditingController();
  
  TransactionType _selectedType = TransactionType.sale;
  List<Customer> _customers = [];
  Customer? _selectedCustomer;
  Unit? _mainUnit;
  Unit? _subUnit;
  bool _sellByMainUnit = false;
  bool _isLoading = false;
  bool _dataLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final customers = await _customerService.getAllCustomers();
    final allUnits = await _unitService.getAllUnits();
    
    if (mounted) {
      setState(() {
        _customers = customers;
        _mainUnit = allUnits.where((u) => u.id == widget.product.mainUnitId).firstOrNull;
        _subUnit = allUnits.where((u) => u.id == widget.product.subUnitId).firstOrNull;
        _dataLoading = false;
      });
    }
  }

  Future<void> _sell() async {
    final inputQty = int.tryParse(_quantityController.text) ?? 0;
    if (inputQty <= 0) return;
    final realQuantity = _sellByMainUnit ? inputQty * widget.product.conversionFactor : inputQty;

    if (_selectedType == TransactionType.sale && _selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('select_customer'.tr())));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _productService.sellProduct(
        product: widget.product,
        quantity: realQuantity,
        type: _selectedType,
        customerId: _selectedType == TransactionType.sale ? _selectedCustomer!.id : null,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('error_occurred'.tr())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dataLoading) return const Center(child: CircularProgressIndicator());

    final inputQty = int.tryParse(_quantityController.text) ?? 1;
    final unitPrice = _sellByMainUnit ? (widget.product.price * widget.product.conversionFactor) : widget.product.price;
    final totalPrice = unitPrice * inputQty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildReceiptHeader(),
            const Divider(height: 32),
            _buildStockBadge(),
            SizedBox(height: 20.h),
            _buildCustomUnitToggle(),
            SizedBox(height: 16.h),
            _buildQuantityInput(),
            SizedBox(height: 16.h),
            _buildTypeSelector(),
            if (_selectedType == TransactionType.sale) ...[
              SizedBox(height: 16.h),
              _buildCustomerDropdown(),
            ],
            SizedBox(height: 32.h),
            _buildBillSummary(unitPrice, totalPrice),
            SizedBox(height: 24.h),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptHeader() {
    return Column(
      children: [
        Icon(Icons.receipt_long_outlined, size: 40.sp, color: AppColors.primary),
        SizedBox(height: 8.h),
        Text('sale'.tr(), style: TextStyle(fontSize: 14.sp, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(widget.product.name, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildStockBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(20.r)),
      child: Text(
        '${'stock'.tr()}: ${_productService.formatStock(widget.product.stockQuantity, widget.product.conversionFactor)}',
        style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12.sp),
      ),
    );
  }

  Widget _buildCustomUnitToggle() {
    if (widget.product.conversionFactor <= 1) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(15.r)),
      child: Row(
        children: [
          _buildToggleButton(label: _subUnit?.name ?? 'Sub', isSelected: !_sellByMainUnit, onTap: () => setState(() => _sellByMainUnit = false)),
          _buildToggleButton(label: _mainUnit?.name ?? 'Main', isSelected: _sellByMainUnit, onTap: () => setState(() => _sellByMainUnit = true)),
        ],
      ),
    );
  }

  Widget _buildToggleButton({required String label, required bool isSelected, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          margin: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11.r),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? AppColors.primary : Colors.grey[600]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityInput() {
    return TextField(
      controller: _quantityController,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: 'quantity'.tr(),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        suffixText: _sellByMainUnit ? (_mainUnit?.name ?? 'Main') : (_subUnit?.name ?? 'Sub'),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15.r), borderSide: BorderSide.none),
      ),
      onChanged: (val) => setState(() {}),
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(15.r)),
      child: Row(
        children: [
          _buildTypeButton(TransactionType.sale, 'cash'.tr(), Icons.payments_outlined),
          _buildTypeButton(TransactionType.payment, 'debt'.tr(), Icons.pending_actions_outlined),
        ],
      ),
    );
  }

  Widget _buildTypeButton(TransactionType type, String label, IconData icon) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedType = type),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16.sp, color: isSelected ? Colors.white : Colors.grey),
              SizedBox(width: 8.w),
              Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerDropdown() {
    return DropdownButtonFormField<Customer>(
      value: _selectedCustomer,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'select_customer'.tr(),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15.r), borderSide: BorderSide.none),
        isDense: true,
      ),
      items: _customers.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
      onChanged: (val) => setState(() => _selectedCustomer = val),
    );
  }

  Widget _buildBillSummary(double unitPrice, double totalPrice) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('unit_price'.tr(), style: TextStyle(color: Colors.grey[600], fontSize: 12.sp)),
              Text(CurrencyHelper.getFormatter(widget.product.currency).format(unitPrice), style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('total'.tr(), style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Text(
                '${CurrencyHelper.getFormatter(widget.product.currency).format(totalPrice)} ${widget.product.currency}',
                style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w900, color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _sell,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
              elevation: 0,
            ),
            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text('confirm_sale'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
