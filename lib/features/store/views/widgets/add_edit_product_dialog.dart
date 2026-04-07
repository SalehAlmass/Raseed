import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/models/product.dart';
import '../../../../core/services/product_service.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/barcode_scanner_view.dart';

class AddEditProductDialog extends StatefulWidget {
  final Product? product;

  const AddEditProductDialog({super.key, this.product});

  @override
  State<AddEditProductDialog> createState() => _AddEditProductDialogState();
}

class _AddEditProductDialogState extends State<AddEditProductDialog> {
  final _productService = sl<ProductService>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _barcodeController = TextEditingController();
  String _selectedCurrency = 'YER';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _nameController.text = widget.product!.name;
      _priceController.text = widget.product!.price.toStringAsFixed(0);
      _stockController.text = widget.product!.stockQuantity.toString();
      _selectedCurrency = widget.product!.currency;
      _barcodeController.text = widget.product!.barcode ?? '';
    }
  }

  Future<void> _save() async {
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) return;

    setState(() => _isLoading = true);

    final name = _nameController.text;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final stock = int.tryParse(_stockController.text) ?? 0;

    final product = Product(
      id: widget.product?.id,
      name: name,
      price: price,
      stockQuantity: stock,
      currency: _selectedCurrency,
      barcode: _barcodeController.text.isEmpty ? null : _barcodeController.text,
    );

    try {
      if (widget.product == null) {
        await _productService.addProduct(product);
      } else {
        await _productService.updateProduct(product);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_occurred'.tr()), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

    return AlertDialog(
      title: Text(isEditing ? 'edit_product'.tr() : 'add_product'.tr()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'product_name'.tr(),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
            ),
            SizedBox(height: 15.h),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'price'.tr(),
                prefixText: 'YER ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
            ),
            SizedBox(height: 15.h),
            TextField(
              controller: _stockController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'stock_quantity'.tr(),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
            ),
            SizedBox(height: 15.h),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcodeController,
                    decoration: InputDecoration(
                      labelText: 'barcode'.tr(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                IconButton.filled(
                  onPressed: () async {
                    final code = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(builder: (_) => const BarcodeScannerView()),
                    );
                    if (code != null) {
                      setState(() => _barcodeController.text = code);
                    }
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        if (isEditing)
          TextButton(
            onPressed: () async {
              await _productService.deleteProduct(widget.product!.id!);
              if (context.mounted) Navigator.pop(context, true);
            },
            child: Text('delete'.tr(), style: const TextStyle(color: AppColors.error)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Text('save'.tr()),
        ),
      ],
    );
  }
}
