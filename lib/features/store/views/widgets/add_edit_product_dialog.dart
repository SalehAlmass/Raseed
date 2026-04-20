import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rseed/core/models/batch.dart';
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
  final _costPriceController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _unitsPerPackageController = TextEditingController(text: '1');
  final _packagePriceController = TextEditingController();
  final _packageStockController = TextEditingController(text: '0');
  final _unitStockController = TextEditingController(text: '0');
  DateTime? _expiryDate;
  String _selectedCurrency = 'YER';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _nameController.text = widget.product!.name;
      _priceController.text = widget.product!.price.toStringAsFixed(0);
      _costPriceController.text = widget.product!.costPrice.toStringAsFixed(0);
      _selectedCurrency = widget.product!.currency;
      _barcodeController.text = widget.product!.barcode ?? '';
      _unitsPerPackageController.text = widget.product!.unitsPerPackage.toString();
      _packagePriceController.text = widget.product!.packagePrice.toStringAsFixed(0);
      
      final totalStock = widget.product!.stockQuantity;
      final upp = widget.product!.unitsPerPackage;
      _packageStockController.text = (totalStock ~/ upp).toString();
      _unitStockController.text = (totalStock % upp).toString();
    }
  }

  Future<void> _save() async {
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) return;

    setState(() => _isLoading = true);

    final name = _nameController.text;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final costPrice = double.tryParse(_costPriceController.text) ?? 0.0;
    final upp = int.tryParse(_unitsPerPackageController.text) ?? 1;
    final packagePrice = double.tryParse(_packagePriceController.text) ?? 0.0;
    
    final pStock = int.tryParse(_packageStockController.text) ?? 0;
    final uStock = int.tryParse(_unitStockController.text) ?? 0;
    final totalStock = (pStock * upp) + uStock;

    final product = Product(
      id: widget.product?.id,
      name: name,
      price: price,
      costPrice: costPrice,
      stockQuantity: totalStock,
      currency: _selectedCurrency,
      barcode: _barcodeController.text.isEmpty ? null : _barcodeController.text,
      unitsPerPackage: upp,
      packagePrice: packagePrice,
    );

    try {
      int productId;
      if (widget.product == null) {
        productId = await _productService.addProduct(product);
      } else {
        await _productService.updateProduct(product);
        productId = widget.product!.id!;
      }

      // If stock was provided, create an initial batch
      if (totalStock > 0 && widget.product == null) {
        await _productService.addBatch(Batch(
          productId: productId,
          quantity: totalStock,
          costPrice: costPrice > 0 ? costPrice : (packagePrice / upp),
          createdAt: DateTime.now(),
          expiryDate: _expiryDate,
        ));
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
                labelText: 'selling_price'.tr(),
                prefixText: 'YER ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
            ),
            SizedBox(height: 15.h),
            TextField(
              controller: _costPriceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'purchase_price'.tr(),
                prefixText: 'YER ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
            ),
            SizedBox(height: 15.h),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _unitsPerPackageController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'units_per_package'.tr(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: TextField(
                    controller: _packagePriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'package_price'.tr(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 15.h),
            _buildStockSection(),
            SizedBox(height: 15.h),
            _buildExpiryPicker(),
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

  Widget _buildStockSection() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('stock_quantity'.tr(), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _packageStockController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'packages'.tr(),
                    isDense: true,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                child: const Text('+'),
              ),
              Expanded(
                child: TextField(
                  controller: _unitStockController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'units'.tr(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpiryPicker() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.calendar_today_outlined, color: AppColors.primary),
      title: Text('expiry_date'.tr()),
      subtitle: Text(_expiryDate == null ? 'not_set'.tr() : DateFormat('dd/MM/yyyy').format(_expiryDate!)),
      trailing: TextButton(
        onPressed: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: DateTime.now().add(const Duration(days: 365)),
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 3650)),
          );
          if (date != null) setState(() => _expiryDate = date);
        },
        child: Text('select'.tr()),
      ),
    );
  }
}
