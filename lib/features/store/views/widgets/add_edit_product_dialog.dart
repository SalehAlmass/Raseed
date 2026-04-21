import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rseed/core/services/unit_service.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/models/product.dart';
import '../../../../core/models/batch.dart';
import '../../../../core/models/category.dart';
import '../../../../core/models/unit.dart';
import '../../../../core/services/product_service.dart';
import '../../../../core/services/category_service.dart';
import '../../../../core/services/unit_service.dart';
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
  final _categoryService = sl<CategoryService>();
  final _unitService = sl<UnitService>();

  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _conversionController = TextEditingController(text: '1');
  final _purchasePriceController = TextEditingController(); // Price for Main Unit
  final _salePriceController = TextEditingController();     // Price for Sub Unit (per piece)
  
  final _mainStockController = TextEditingController(text: '0');
  final _subStockController = TextEditingController(text: '0');

  List<Category> _categories = [];
  List<Unit> _units = [];
  
  Category? _selectedCategory;
  Unit? _mainUnit;
  Unit? _subUnit;
  DateTime? _expiryDate;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final cats = await _categoryService.getAllCategories();
    final units = await _unitService.getAllUnits();
    
    if (mounted) {
      setState(() {
        _categories = cats;
        _units = units;
        _isLoading = false;

        if (widget.product != null) {
          final p = widget.product!;
          _nameController.text = p.name;
          _barcodeController.text = p.barcode ?? '';
          _conversionController.text = p.conversionFactor.toString();
          _purchasePriceController.text = p.packagePrice.toStringAsFixed(0);
          _salePriceController.text = p.price.toStringAsFixed(0);
          
          _selectedCategory = _categories.where((c) => c.id == p.categoryId).firstOrNull;
          _mainUnit = _units.where((u) => u.id == p.mainUnitId).firstOrNull;
          _subUnit = _units.where((u) => u.id == p.subUnitId).firstOrNull;

          final totalStock = p.stockQuantity;
          final factor = p.conversionFactor;
          _mainStockController.text = (totalStock ~/ factor).toString();
          _subStockController.text = (totalStock % factor).toString();
        }
      });
    }
  }

  Future<void> _save() async {
    if (_nameController.text.isEmpty || _mainUnit == null || _subUnit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final factor = int.tryParse(_conversionController.text) ?? 1;
    final purchasePrice = double.tryParse(_purchasePriceController.text) ?? 0.0;
    final salePrice = double.tryParse(_salePriceController.text) ?? 0.0;
    
    final mStock = int.tryParse(_mainStockController.text) ?? 0;
    final sStock = int.tryParse(_subStockController.text) ?? 0;
    final totalStock = (mStock * factor) + sStock;

    final product = Product(
      id: widget.product?.id,
      name: _nameController.text,
      price: salePrice,
      costPrice: factor > 0 ? (purchasePrice / factor) : purchasePrice,
      stockQuantity: totalStock,
      barcode: _barcodeController.text.isEmpty ? null : _barcodeController.text,
      conversionFactor: factor,
      packagePrice: purchasePrice, // We use packagePrice field for Main unit price
      categoryId: _selectedCategory?.id,
      mainUnitId: _mainUnit?.id,
      subUnitId: _subUnit?.id,
    );

    try {
      int productId;
      if (widget.product == null) {
        productId = await _productService.addProduct(product);
        // Add initial batch if quantity > 0
        if (totalStock > 0) {
          await _productService.addBatch(Batch(
            productId: productId,
            quantity: totalStock,
            costPrice: product.costPrice,
            createdAt: DateTime.now(),
            expiryDate: _expiryDate,
          ));
        }
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return AlertDialog(
      title: Text(widget.product == null ? 'add_product'.tr() : 'edit_product'.tr()),
      contentPadding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
      content: SingleChildScrollView(
        child: Column(
          children: [
            _buildTextField(_nameController, 'product_name'.tr(), Icons.shopping_basket_outlined),
            SizedBox(height: 12.h),
            _buildBarcodeField(),
            SizedBox(height: 12.h),
            _buildCategoryDropdown(),
            const Divider(height: 30),
            _buildSectionHeader('stock_and_units'.tr()),
            SizedBox(height: 12.h),
            _buildUnitSelection(),
            SizedBox(height: 12.h),
            _buildQuantitySection(),
            const Divider(height: 30),
            _buildSectionHeader('pricing_and_expiry'.tr()),
            SizedBox(height: 12.h),
            _buildPriceSection(),
            SizedBox(height: 12.h),
            _buildExpiryPicker(),
            SizedBox(height: 20.h),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : Text('save'.tr()),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 14.sp)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20.sp),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
        isDense: true,
      ),
    );
  }

  Widget _buildBarcodeField() {
    return Row(
      children: [
        Expanded(child: _buildTextField(_barcodeController, 'barcode'.tr(), Icons.qr_code_outlined)),
        SizedBox(width: 8.w),
        IconButton.filled(
          onPressed: () async {
            final code = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const BarcodeScannerView()));
            if (code != null) setState(() => _barcodeController.text = code);
          },
          icon: const Icon(Icons.qr_code_scanner),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<Category>(
      value: _selectedCategory,
      decoration: InputDecoration(
        labelText: 'category'.tr(),
        prefixIcon: const Icon(Icons.category_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
        isDense: true,
      ),
      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
      onChanged: (val) => setState(() => _selectedCategory = val),
    );
  }

  Widget _buildUnitSelection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildUnitDropdown(label: 'main_unit'.tr(), value: _mainUnit, onChanged: (v) => setState(() => _mainUnit = v))),
            SizedBox(width: 8.w),
            Expanded(child: _buildUnitDropdown(label: 'sub_unit'.tr(), value: _subUnit, onChanged: (v) => setState(() => _subUnit = v))),
          ],
        ),
        SizedBox(height: 12.h),
        _buildTextField(_conversionController, 'units_per_package'.tr(), Icons.swap_horiz, type: TextInputType.number),
      ],
    );
  }

  Widget _buildUnitDropdown({required String label, Unit? value, required Function(Unit?) onChanged}) {
    return DropdownButtonFormField<Unit>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
        isDense: true,
      ),
      items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u.name))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildQuantitySection() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12.r)),
      child: Row(
        children: [
          Expanded(child: _buildTextField(_mainStockController, _mainUnit?.name ?? 'Main', Icons.inventory_2_outlined, type: TextInputType.number)),
          Padding(padding: EdgeInsets.symmetric(horizontal: 8.w), child: const Text('+')),
          Expanded(child: _buildTextField(_subStockController, _subUnit?.name ?? 'Sub', Icons.inventory_outlined, type: TextInputType.number)),
        ],
      ),
    );
  }

  Widget _buildPriceSection() {
    return Row(
      children: [
        Expanded(child: _buildTextField(_purchasePriceController, 'purchase_price'.tr(), Icons.shopping_cart_outlined, type: TextInputType.number)),
        SizedBox(width: 8.w),
        Expanded(child: _buildTextField(_salePriceController, 'selling_price'.tr(), Icons.sell_outlined, type: TextInputType.number)),
      ],
    );
  }

  Widget _buildExpiryPicker() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.calendar_month_outlined, color: AppColors.primary),
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
