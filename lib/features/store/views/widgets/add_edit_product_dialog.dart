import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
  final _purchasePriceController = TextEditingController();
  final _salePriceController = TextEditingController();
  
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
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
      packagePrice: purchasePrice,
      categoryId: _selectedCategory?.id,
      mainUnitId: _mainUnit?.id,
      subUnitId: _subUnit?.id,
    );

    try {
      int productId;
      if (widget.product == null) {
        productId = await _productService.addProduct(product);
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('error_occurred'.tr())));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      child: Container(
        constraints: BoxConstraints(maxHeight: 1.sh * 0.85),
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(vertical: 20.h),
                child: Column(
                  children: [
                    _buildSection(
                      title: 'product_identity'.tr(),
                      icon: Icons.info_outline,
                      child: Column(
                        children: [
                          _buildModernField(_nameController, 'product_name'.tr(), Icons.drive_file_rename_outline),
                          SizedBox(height: 12.h),
                          _buildBarcodeField(),
                          SizedBox(height: 12.h),
                          _buildCategoryDropdown(),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                    _buildSection(
                      title: 'stock_and_units'.tr(),
                      icon: Icons.inventory_2_outlined,
                      child: Column(
                        children: [
                          _buildUnitPairSelection(),
                          SizedBox(height: 12.h),
                          _buildModernField(_conversionController, 'units_per_package'.tr(), Icons.unfold_more, type: TextInputType.number),
                          SizedBox(height: 16.h),
                          _buildQuantityGrid(),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                    _buildSection(
                      title: 'pricing_and_expiry'.tr(),
                      icon: Icons.payments_outlined,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: _buildModernField(_purchasePriceController, 'purchase_price'.tr(), Icons.shopping_basket_outlined, type: TextInputType.number)),
                              SizedBox(width: 8.w),
                              Expanded(child: _buildModernField(_salePriceController, 'selling_price'.tr(), Icons.sell_outlined, type: TextInputType.number)),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          _buildExpirySelector(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          widget.product == null ? 'add_product'.tr() : 'edit_product'.tr(),
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
      ],
    );
  }

  Widget _buildSection({required String title, required IconData icon, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18.sp, color: AppColors.primary),
                SizedBox(width: 8.w),
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13.sp)),
              ],
            ),
          ),
          Padding(padding: EdgeInsets.all(16.w), child: child),
        ],
      ),
    );
  }

  Widget _buildModernField(TextEditingController controller, String label, IconData icon, {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20.sp, color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
        isDense: true,
      ),
    );
  }

  Widget _buildBarcodeField() {
    return Row(
      children: [
        Expanded(child: _buildModernField(_barcodeController, 'barcode'.tr(), Icons.qr_code_outlined)),
        SizedBox(width: 8.w),
        IconButton.filled(
          onPressed: () async {
            final code = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const BarcodeScannerView()));
            if (code != null) setState(() => _barcodeController.text = code);
          },
          icon: const Icon(Icons.qr_code_scanner),
          style: IconButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
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
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
        isDense: true,
      ),
      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
      onChanged: (val) => setState(() => _selectedCategory = val),
    );
  }

  Widget _buildUnitPairSelection() {
    return Row(
      children: [
        Expanded(child: _buildSimpleDropdown(label: 'main_unit'.tr(), value: _mainUnit, onChanged: (v) => setState(() => _mainUnit = v))),
        SizedBox(width: 8.w),
        Expanded(child: _buildSimpleDropdown(label: 'sub_unit'.tr(), value: _subUnit, onChanged: (v) => setState(() => _subUnit = v))),
      ],
    );
  }

  Widget _buildSimpleDropdown({required String label, Unit? value, required Function(Unit?) onChanged}) {
    return DropdownButtonFormField<Unit>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
        isDense: true,
      ),
      items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u.name))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildQuantityGrid() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12.r)),
      child: Row(
        children: [
          Expanded(child: _buildModernField(_mainStockController, _mainUnit?.name ?? 'Main', Icons.inventory_2_outlined, type: TextInputType.number)),
          Padding(padding: EdgeInsets.symmetric(horizontal: 8.w), child: Icon(Icons.add, color: Colors.grey[400], size: 16)),
          Expanded(child: _buildModernField(_subStockController, _subUnit?.name ?? 'Sub', Icons.inventory_outlined, type: TextInputType.number)),
        ],
      ),
    );
  }

  Widget _buildExpirySelector() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now().add(const Duration(days: 365)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 3650)),
        );
        if (date != null) setState(() => _expiryDate = date);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12.r)),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined, color: Colors.grey),
            SizedBox(width: 12.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('expiry_date'.tr(), style: TextStyle(fontSize: 11.sp, color: Colors.grey[600])),
                Text(_expiryDate == null ? 'not_set'.tr() : DateFormat('dd/MM/yyyy').format(_expiryDate!), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
            ),
            child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : Text('save'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
