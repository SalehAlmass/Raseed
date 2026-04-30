import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/models/product.dart';
import '../../../../core/models/supplier.dart';
import '../../../../core/models/supplier_transaction.dart';
import '../../../../core/models/supplier_transaction_item.dart';
import '../../../../core/services/supplier_service.dart';
import '../../../../core/services/supplier_transaction_service.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency_helper.dart';

class QuickPurchaseDialog extends StatefulWidget {
  final Product product;

  const QuickPurchaseDialog({super.key, required this.product});

  @override
  State<QuickPurchaseDialog> createState() => _QuickPurchaseDialogState();
}

class _QuickPurchaseDialogState extends State<QuickPurchaseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _supplierService = sl<SupplierService>();
  final _transactionService = sl<SupplierTransactionService>();

  final _qtyController = TextEditingController();
  final _costController = TextEditingController();
  final _paidController = TextEditingController(text: '0');

  List<Supplier> _suppliers = [];
  Supplier? _selectedSupplier;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    _costController.text = widget.product.packagePrice.toStringAsFixed(0);
  }

  Future<void> _loadSuppliers() async {
    final suppliers = await _supplierService.getAllSuppliers();
    setState(() {
      _suppliers = suppliers;
      _selectedSupplier = suppliers.where((s) => s.id == widget.product.supplierId).firstOrNull;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('select_supplier_error'.tr())),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final qty = int.parse(_qtyController.text);
      final cost = double.parse(_costController.text);
      final paid = double.tryParse(_paidController.text) ?? 0;

      final item = SupplierTransactionItem(
        productId: widget.product.id!,
        productName: widget.product.name,
        quantity: qty,
        costPrice: cost,
      );

      final tx = SupplierTransaction(
        supplierId: _selectedSupplier!.id!,
        type: SupplierTransactionType.purchase,
        amount: qty * cost,
        paidAmount: paid,
        date: DateTime.now(),
        items: [item],
      );

      await _transactionService.addTransaction(tx);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_occurred'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return AlertDialog(
      title: Text('quick_purchase'.tr()),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.product.name,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, color: AppColors.primary),
              ),
              SizedBox(height: 20.h),
              DropdownButtonFormField<Supplier>(
                value: _selectedSupplier,
                decoration: InputDecoration(
                  labelText: 'supplier'.tr(),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  prefixIcon: const Icon(Icons.business),
                ),
                items: _suppliers.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                onChanged: (val) => setState(() => _selectedSupplier = val),
                validator: (v) => v == null ? 'required_field'.tr() : null,
              ),
              SizedBox(height: 15.h),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qtyController,
                      decoration: InputDecoration(
                        labelText: 'quantity'.tr(),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || v.isEmpty ? 'required_field'.tr() : null,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: TextFormField(
                      controller: _costController,
                      decoration: InputDecoration(
                        labelText: 'cost_price'.tr(),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || v.isEmpty ? 'required_field'.tr() : null,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 15.h),
              TextFormField(
                controller: _paidController,
                decoration: InputDecoration(
                  labelText: 'paid_amount'.tr(),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  prefixText: 'YER ',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _isSaving 
            ? SizedBox(width: 20.w, height: 20.h, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text('save'.tr()),
        ),
      ],
    );
  }
}
