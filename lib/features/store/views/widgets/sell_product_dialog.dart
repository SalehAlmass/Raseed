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
  final _quantityController = TextEditingController(text: '1');
  
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('select_customer'.tr()), backgroundColor: AppColors.error),
      );
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
      if (mounted) {
        String errMsg = 'error_occurred'.tr();
        if (e.toString().contains('uninsufficient_stock')) errMsg = 'not_enough_stock'.tr();
        
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
    if (_dataLoading) return const Center(child: CircularProgressIndicator());

    final inputQty = int.tryParse(_quantityController.text) ?? 1;
    final unitPrice = _sellByMainUnit ? (widget.product.price * widget.product.conversionFactor) : widget.product.price;
    final totalPrice = unitPrice * inputQty;

    return AlertDialog(
      title: Text('${'sale'.tr()}: ${widget.product.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStockInfo(),
            SizedBox(height: 20.h),
            _buildUnitSelector(),
            SizedBox(height: 15.h),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'quantity'.tr(),
                suffixText: _sellByMainUnit ? (_mainUnit?.name ?? 'Main') : (_subUnit?.name ?? 'Sub'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              onChanged: (val) => setState(() {}),
            ),
            SizedBox(height: 15.h),
            SegmentedButton<TransactionType>(
              segments: [
                ButtonSegment(value: TransactionType.sale, label: Text('cash_sale'.tr())),
                ButtonSegment(value: TransactionType.payment, label: Text('debt_sale'.tr())),
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
                  labelText: 'select_customer'.tr(),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
                items: _customers.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                onChanged: (val) => setState(() => _selectedCustomer = val),
              ),
            ],
            SizedBox(height: 20.h),
            _buildTotalDisplay(totalPrice),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('cancel'.tr())),
        ElevatedButton(
          onPressed: _isLoading ? null : _sell,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
          child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text('confirm_sale'.tr()),
        ),
      ],
    );
  }

  Widget _buildStockInfo() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(10.r)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${'stock'.tr()}: ${_productService.formatStock(widget.product.stockQuantity, widget.product.conversionFactor)}', 
               style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildUnitSelector() {
    if (widget.product.conversionFactor <= 1) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12.r)),
      child: Row(
        children: [
          Expanded(
            child: ChoiceChip(
              label: Container(width: double.infinity, alignment: Alignment.center, child: Text(_subUnit?.name ?? 'Sub')),
              selected: !_sellByMainUnit,
              onSelected: (val) => setState(() => _sellByMainUnit = false),
            ),
          ),
          Expanded(
            child: ChoiceChip(
              label: Container(width: double.infinity, alignment: Alignment.center, child: Text(_mainUnit?.name ?? 'Main')),
              selected: _sellByMainUnit,
              onSelected: (val) => setState(() => _sellByMainUnit = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalDisplay(double totalPrice) {
    return Center(
      child: Column(
        children: [
          Text(
            '${'unit_price'.tr()}: ${CurrencyHelper.getFormatter(widget.product.currency).format(_sellByMainUnit ? (widget.product.price * widget.product.conversionFactor) : widget.product.price)}',
            style: TextStyle(fontSize: 14.sp, color: Colors.grey),
          ),
          SizedBox(height: 5.h),
          Text(
            '${'total'.tr()}: ${CurrencyHelper.getFormatter(widget.product.currency).format(totalPrice)} ${widget.product.currency}',
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
