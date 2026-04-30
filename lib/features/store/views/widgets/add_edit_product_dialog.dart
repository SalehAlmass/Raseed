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
import '../../../../core/services/supplier_service.dart';
import '../../../../core/services/supplier_transaction_service.dart';
import '../../../../core/models/supplier.dart';
import '../../../../core/models/supplier_transaction.dart';
import '../../../../core/models/supplier_transaction_item.dart';
import '../../../../core/models/app_settings.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/barcode_scanner_view.dart';

class AddEditProductDialog extends StatefulWidget {
  final Product? product;

  const AddEditProductDialog({super.key, this.product});

  @override
  State<AddEditProductDialog> createState() => _AddEditProductDialogState();
}

class _AddEditProductDialogState extends State<AddEditProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _productService = sl<ProductService>();
  final _categoryService = sl<CategoryService>();
  final _unitService = sl<UnitService>();

  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _conversionController = TextEditingController(text: '1');
  final _purchasePriceController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _wholesalePriceController = TextEditingController();
  final _reorderLevelController = TextEditingController(text: '10');

  // Storage Controllers
  final _totalStockController = TextEditingController();
  final _mainStockController = TextEditingController();
  final _subStockController = TextEditingController();

  List<Category> _categories = [];
  List<Unit> _units = [];

  Category? _selectedCategory;
  Unit? _mainUnit;
  Unit? _subUnit;
  List<Supplier> _suppliers = [];
  Supplier? _selectedSupplier;
  DateTime? _expiryDate;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _showAdvanced = false;
  bool _isSyncing = false;
  double _marginPercentage = 0.0;
  int _lastSuggestedSale = 0;
  int _lastSuggestedWholesale = 0;
  int _initialStock = 0;
  bool _recordAsPurchase = true;
  final _paidAmountController = TextEditingController(text: '0');
  
  late AppSettings _settings;
  ProductFormConfig _formConfig = ProductFormConfig();

  @override
  void initState() {
    super.initState();
    _loadData();

    // Listen to price changes for margin calculation
    _purchasePriceController.addListener(_calculateMargin);
    _salePriceController.addListener(_calculateMargin);
    _conversionController.addListener(_calculateMargin);

    // Quantity Synchronization Logic
    _totalStockController.addListener(_syncFromTotal);
    _mainStockController.addListener(_syncFromDetailed);
    _subStockController.addListener(_syncFromDetailed);
    _conversionController.addListener(
      _syncFromDetailed,
    ); // Re-sync if factor changes

    // Auto-fill paid amount
    _totalStockController.addListener(_updatePaidAmount);
    _purchasePriceController.addListener(_updatePaidAmount);
  }

  @override
  void dispose() {
    _purchasePriceController.dispose();
    _salePriceController.dispose();
    _wholesalePriceController.dispose();
    _reorderLevelController.dispose();
    _nameController.dispose();
    _barcodeController.dispose();
    _conversionController.dispose();
    _totalStockController.dispose();
    _mainStockController.dispose();
    _subStockController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }

  void _syncFromTotal() {
    if (_isSyncing) return;
    _isSyncing = true;

    final total = int.tryParse(_totalStockController.text) ?? 0;
    final factor = int.tryParse(_conversionController.text) ?? 1;

    final main = total ~/ factor;
    final sub = total % factor;

    if (_mainStockController.text != main.toString()) {
      _mainStockController.text = main.toString();
    }
    if (_subStockController.text != sub.toString()) {
      _subStockController.text = sub.toString();
    }

    _isSyncing = false;
  }

  void _syncFromDetailed() {
    if (_isSyncing) return;
    _isSyncing = true;

    final main = int.tryParse(_mainStockController.text) ?? 0;
    final sub = int.tryParse(_subStockController.text) ?? 0;
    final factor = int.tryParse(_conversionController.text) ?? 1;

    final total = (main * factor) + sub;

    if (_totalStockController.text != total.toString()) {
      _totalStockController.text = total.toString();
    }

    _isSyncing = false;
  }

  void _updatePaidAmount() {
    if (!_recordAsPurchase) return;

    String currentStockText = _totalStockController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final currentStock = int.tryParse(currentStockText) ?? 0;
    final diff = currentStock - _initialStock;
    if (diff <= 0) {
      if (_paidAmountController.text != '0') {
        _paidAmountController.text = '0';
      }
      return;
    }

    String purchasePriceText = _purchasePriceController.text.replaceAll(RegExp(r'[^0-9.]'), '');
    String factorText = _conversionController.text.replaceAll(RegExp(r'[^0-9]'), '');

    final purchasePrice = double.tryParse(purchasePriceText) ?? 0.0;
    final factor = int.tryParse(factorText) ?? 1;
    final safeFactor = factor > 0 ? factor : 1;
    final costPerSub = purchasePrice / safeFactor;

    final total = (diff * costPerSub).round();
    final totalStr = total.toString();

    // Only update if it's different to avoid infinite loops or cursor jumps
    if (_paidAmountController.text != totalStr) {
      _paidAmountController.text = totalStr;
    }
  }

  void _calculateMargin() {
    // Keep only digits for calculation to avoid any locale/formatting issues
    String costText = _purchasePriceController.text.replaceAll(RegExp(r'\D'), '');
    String priceText = _salePriceController.text.replaceAll(RegExp(r'\D'), '');
    String wholesalePriceText = _wholesalePriceController.text.replaceAll(RegExp(r'\D'), '');
    String factorText = _conversionController.text.replaceAll(RegExp(r'\D'), '');

    final cost = double.tryParse(costText) ?? 0.0;
    final price = double.tryParse(priceText) ?? 0.0;
    final wholesale = double.tryParse(wholesalePriceText) ?? 0.0;
    final factor = int.tryParse(factorText) ?? 1;
    final safeFactor = factor > 0 ? factor : 1;

    if (cost > 0) {
      final costPerSub = cost / safeFactor;
      
      // Suggest prices if empty, zero, or if it matches the last suggestion we made
      bool updateSale = _salePriceController.text.isEmpty || price == 0 || price == _lastSuggestedSale;
      bool updateWholesale = _wholesalePriceController.text.isEmpty || wholesale == 0 || wholesale == _lastSuggestedWholesale;

      if (updateSale) {
        final suggestedSale = (costPerSub * (1 + _formConfig.autoSaleMargin)).round();
        if (mounted) {
          _salePriceController.text = suggestedSale.toString();
          _lastSuggestedSale = suggestedSale;
        }
      }

      if (updateWholesale) {
        final suggestedWholesale = (costPerSub * (1 + _formConfig.autoWholesaleMargin)).round();
        if (mounted) {
          _wholesalePriceController.text = suggestedWholesale.toString();
          _lastSuggestedWholesale = suggestedWholesale;
        }
      }
      
      // Re-read price after suggestion to update margin
      final currentPriceText = _salePriceController.text.replaceAll(RegExp(r'\D'), '');
      final currentPrice = double.tryParse(currentPriceText) ?? 0.0;

      if (currentPrice > 0 && mounted) {
        setState(() {
          _marginPercentage = ((currentPrice - costPerSub) / currentPrice) * 100;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _marginPercentage = 0.0;
        });
      }
    }
  }

  Future<void> _loadData() async {
    final cats = await _categoryService.getAllCategories();
    final units = await _unitService.getAllUnits();
    final suppliers = await sl<SupplierService>().getAllSuppliers();
    final settings = await sl<SettingsService>().getSettings();

    if (mounted) {
      setState(() {
        _categories = cats;
        _units = units;
        _suppliers = suppliers;
        _settings = settings;
        _formConfig = settings.productFormConfig;
        _isLoading = false;

        if (widget.product != null) {
          final p = widget.product!;
          _nameController.text = p.name;
          _barcodeController.text = p.barcode ?? '';
          _conversionController.text = p.conversionFactor.toString();
          _purchasePriceController.text = p.packagePrice.toStringAsFixed(0);
          _salePriceController.text = p.price.toStringAsFixed(0);
          _wholesalePriceController.text = p.wholesalePrice.toStringAsFixed(0);
          _reorderLevelController.text = p.reorderLevel.toString();

          _selectedCategory =
              _categories.where((c) => c.id == p.categoryId).firstOrNull ??
              _categories.firstOrNull;
          _mainUnit = _units.where((u) => u.id == p.mainUnitId).firstOrNull;
          _subUnit = _units.where((u) => u.id == p.subUnitId).firstOrNull;
          _selectedSupplier = _suppliers
              .where((s) => s.id == p.supplierId)
              .firstOrNull;

          _totalStockController.text = p.stockQuantity.toString();
          _initialStock = p.stockQuantity;
          _recordAsPurchase = false; // Default to false for existing products

          if (p.batches.isNotEmpty) {
            final activeBatches = p.batches
                .where((b) => b.quantity > 0 && b.expiryDate != null)
                .toList();
            if (activeBatches.isNotEmpty) {
              activeBatches.sort(
                (a, b) => a.expiryDate!.compareTo(b.expiryDate!),
              );
              _expiryDate = activeBatches.first.expiryDate;
            } else if (p.batches.firstOrNull?.expiryDate != null) {
              _expiryDate = p.batches.first.expiryDate;
            }
          }

          _syncFromTotal();
          _calculateMargin();
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    final factor = int.tryParse(_conversionController.text) ?? 1;
    final purchasePrice = double.tryParse(_purchasePriceController.text) ?? 0.0;
    final salePrice = double.tryParse(_salePriceController.text) ?? 0.0;
    final wholesalePrice =
        double.tryParse(_wholesalePriceController.text) ?? 0.0;
    final reorderLevel = int.tryParse(_reorderLevelController.text) ?? 0;
    final totalStock = int.tryParse(_totalStockController.text) ?? 0;
    final paidAmount = double.tryParse(_paidAmountController.text) ?? 0.0;

    final product = Product(
      id: widget.product?.id,
      name: _nameController.text,
      price: salePrice.roundToDouble(),
      costPrice: factor > 0 ? (purchasePrice / factor).roundToDouble() : purchasePrice.roundToDouble(),
      stockQuantity: totalStock,
      barcode: _barcodeController.text.isEmpty 
          ? DateTime.now().millisecondsSinceEpoch.toString().substring(5) 
          : _barcodeController.text,
      conversionFactor: factor,
      packagePrice: purchasePrice.roundToDouble(),
      wholesalePrice: wholesalePrice.roundToDouble(),
      reorderLevel: reorderLevel,
      categoryId: _selectedCategory?.id,
      mainUnitId: _mainUnit?.id,
      subUnitId: _subUnit?.id,
      supplierId: _selectedSupplier?.id,
    );

    try {
      int? productId;
      if (widget.product == null) {
        productId = await _productService.addProduct(product);
        if (totalStock > 0) {
          await _productService.addBatch(
            Batch(
              productId: productId,
              quantity: totalStock,
              costPrice: product.costPrice,
              createdAt: DateTime.now(),
              expiryDate: _expiryDate,
            ),
          );
        }
      } else {
        await _productService.updateProduct(product);

        final pBatches = widget.product!.batches;
        if (pBatches.isNotEmpty) {
          final firstBatch = pBatches.first;
          if (firstBatch.expiryDate != _expiryDate) {
            final updatedBatch = firstBatch.copyWith(expiryDate: _expiryDate);
            await _productService.updateBatch(updatedBatch);
          }
        } else if (_expiryDate != null && totalStock > 0) {
          await _productService.addBatch(
            Batch(
              productId: product.id!,
              quantity: totalStock,
              costPrice: product.costPrice,
              createdAt: DateTime.now(),
              expiryDate: _expiryDate,
            ),
          );
        }
      }
      
      // Handle Accounting (Purchase Invoice)
      final diff = totalStock - _initialStock;
      if (_recordAsPurchase && diff > 0 && _selectedSupplier != null) {
        final item = SupplierTransactionItem(
          productId: productId ?? product.id!,
          productName: product.name ,
          quantity: diff,
          costPrice: (factor > 0 ? (purchasePrice / factor) : purchasePrice).roundToDouble(),
        );

        final tx = SupplierTransaction(
          supplierId: _selectedSupplier!.id!,
          type: SupplierTransactionType.purchase,
          amount: (diff * (factor > 0 ? (purchasePrice / factor) : purchasePrice)).roundToDouble(),
          paidAmount: paidAmount.roundToDouble(),
          date: DateTime.now(),
          items: [item],
        );

        await sl<SupplierTransactionService>().addTransaction(tx);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('error_occurred'.tr())));
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
        constraints: BoxConstraints(maxHeight: 1.sh * 0.9),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    children: [
                      _buildTier1Section(),
                      SizedBox(height: 20.h),
                      _buildAdvancedToggle(),
                      if (_showAdvanced) _buildTier2Section(),
                      SizedBox(height: 20.h),
                    ],
                  ),
                ),
              ),
            ),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildTier1Section() {
    return Column(
      children: [
        _buildModernField(
          _nameController,
          'product_name'.tr(),
          Icons.inventory_2_outlined,
          hint: 'product_name_hint'.tr(),
          validator: (v) =>
              v == null || v.isEmpty ? 'required_field'.tr() : null,
        ),
        if (_formConfig.showBarcode) ...[
          SizedBox(height: 12.h),
          _buildBarcodeField(),
        ],
        SizedBox(height: 12.h),
        Row(
          children: [
            if (_formConfig.showPurchasePrice) ...[
              Expanded(
                child: _buildModernField(
                  _purchasePriceController,
                  'purchase_price'.tr(),
                  Icons.shopping_basket_outlined,
                  type: TextInputType.number,
                  validator: (v) {
                    if (v != null && v.isNotEmpty && double.tryParse(v) == null)
                      return 'invalid_number'.tr();
                    return null;
                  },
                ),
              ),
              SizedBox(width: 8.w),
            ],
            Expanded(
              child: _buildModernField(
                _salePriceController,
                'selling_price'.tr(),
                Icons.sell_outlined,
                type: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'required_field'.tr();
                  if (double.tryParse(v) == null) return 'invalid_number'.tr();
                  if (double.parse(v) < 0) return 'cannot_be_negative'.tr();
                  return null;
                },
              ),
            ),
          ],
        ),
        if (!_showAdvanced) ...[
          SizedBox(height: 12.h),
          _buildModernField(
            _totalStockController,
            'stock_quantity'.tr(),
            Icons.inventory_2_outlined,
            type: TextInputType.number,
            validator: (v) {
              if (v == null || v.isEmpty) return 'required_field'.tr();
              if (int.tryParse(v) == null) return 'invalid_number'.tr();
              if (int.parse(v) < 0) return 'cannot_be_negative'.tr();
              return null;
            },
          ),
        ],
      ],
    );
  }

  Widget _buildAdvancedToggle() {
    return InkWell(
      onTap: () => setState(() => _showAdvanced = !_showAdvanced),
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.primary.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _showAdvanced ? Icons.keyboard_arrow_up : Icons.tune,
              size: 20.sp,
              color: AppColors.primary,
            ),
            SizedBox(width: 10.w),
            Text(
              _showAdvanced ? 'hide_details'.tr() : 'more_details'.tr(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                fontSize: 13.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTier2Section() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_formConfig.showUnits) ...[
          SizedBox(height: 20.h),
          _buildSectionTitle('stock_and_units'.tr(), Icons.square_foot_outlined),
          SizedBox(height: 12.h),
          _buildUnitPairSelection(),
          SizedBox(height: 12.h),
          _buildModernField(
            _conversionController,
            'units_per_package'.tr(),
            Icons.unfold_more,
            type: TextInputType.number,
            validator: (v) {
              if (v == null || v.isEmpty) return 'required_field'.tr();
              final val = int.tryParse(v);
              if (val == null) return 'invalid_number'.tr();
              if (val < 1) return 'min_value_1'.tr();
              return null;
            },
          ),
          SizedBox(height: 12.h),
          _buildQuantityGrid(), // Detailed grid
        ],

        if (_formConfig.showReorder) ...[
          SizedBox(height: 12.h),
          _buildModernField(
            _reorderLevelController,
            'reorder_level'.tr(),
            Icons.report_problem_outlined,
            type: TextInputType.number,
            validator: (v) {
              if (v != null && v.isNotEmpty && int.tryParse(v) == null)
                return 'invalid_number'.tr();
              return null;
            },
          ),
        ],

        SizedBox(height: 24.h),
        _buildSectionTitle(
          'pricing_and_organization'.tr(),
          Icons.analytics_outlined,
        ),
        
        if (_formConfig.showCategory) ...[
          SizedBox(height: 12.h),
          _buildCategoryDropdown(),
        ],
        
        if (_formConfig.showWholesale) ...[
          SizedBox(height: 12.h),
          _buildModernField(
            _wholesalePriceController,
            'wholesale_price'.tr(),
            Icons.groups_outlined,
            type: TextInputType.number,
            validator: (v) {
              if (v != null && v.isNotEmpty && double.tryParse(v) == null)
                return 'invalid_number'.tr();
              return null;
            },
          ),
        ],
        
        SizedBox(height: 16.h),
        _buildMarginDisplay(),
        
        if (_formConfig.showSupplier) ...[
          SizedBox(height: 16.h),
          _buildSupplierDropdown(),
          SizedBox(height: 16.h),
          _buildPurchaseSection(),
        ],
        
        if (_formConfig.showExpiry) ...[
          SizedBox(height: 16.h),
          _buildExpirySelector(),
        ],
      ],
    );
  }

  Widget _buildSupplierDropdown() {
    return DropdownButtonFormField<Supplier>(
      value: _selectedSupplier,
      decoration: InputDecoration(
        labelText: 'suppliers'.tr(),
        prefixIcon: const Icon(Icons.business_rounded),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none,
        ),
        isDense: true,
      ),
      items: _suppliers
          .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
          .toList(),
      onChanged: (val) => setState(() => _selectedSupplier = val),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18.sp, color: Colors.grey[700]),
        SizedBox(width: 8.w),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
            fontSize: 13.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildMarginDisplay() {
    final bool isProfit = _marginPercentage >= 0;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: (isProfit ? Colors.green : Colors.red).withOpacity(0.05),
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(
          color: (isProfit ? Colors.green : Colors.red).withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'profit_margin'.tr(),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
          ),
          Text(
            '${_marginPercentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16.sp,
              color: isProfit ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.all(20.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.product == null ? 'add_product'.tr() : 'edit_product'.tr(),
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildModernField(
    TextEditingController controller,
    String label,
    IconData? icon, {
    TextInputType type = TextInputType.text,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8.h, right: 4.w),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: type,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon, size: 20.sp, color: AppColors.primary) : null,
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBarcodeField() {
    return Row(
      children: [
        Expanded(
          child: _buildModernField(
            _barcodeController,
            'barcode'.tr(),
            Icons.qr_code_outlined,
          ),
        ),
        SizedBox(width: 8.w),
        IconButton.filled(
          onPressed: () async {
            final code = await Navigator.push<String>(
              context,
              MaterialPageRoute(builder: (_) => const BarcodeScannerView()),
            );
            if (code != null) setState(() => _barcodeController.text = code);
          },
          icon: const Icon(Icons.qr_code_scanner),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none,
        ),
        isDense: true,
      ),
      items: _categories
          .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
          .toList(),
      onChanged: (val) => setState(() => _selectedCategory = val),
    );
  }

  Widget _buildUnitPairSelection() {
    // Only units with no parent can be "Main Units"
    final mainUnits = _units.where((u) => u.parentId == null).toList();

    // Only units belonging to the selected main unit can be "Sub Units"
    final filteredSubUnits = _mainUnit == null
        ? <Unit>[]
        : _units.where((u) => u.parentId == _mainUnit?.id).toList();

    return Row(
      children: [
        Expanded(
          child: _buildSimpleDropdown(
            label: 'main_unit'.tr(),
            value: _mainUnit,
            units: mainUnits,
            onChanged: (v) {
              setState(() {
                _mainUnit = v;
                // Auto-select sub unit if only one exists for this main unit
                final potentialSubs = _units
                    .where((u) => u.parentId == _mainUnit?.id)
                    .toList();
                if (potentialSubs.length == 1) {
                  _subUnit = potentialSubs.first;
                } else if (_subUnit != null &&
                    _subUnit?.parentId != _mainUnit?.id) {
                  // If the selected sub-unit doesn't belong to the new main unit, clear it
                  _subUnit = null;
                }
              });
            },
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _buildSimpleDropdown(
            label: 'sub_unit'.tr(),
            value: _subUnit,
            units: filteredSubUnits,
            // Disable if no main unit selected or no sub units available
            onChanged: _mainUnit == null || filteredSubUnits.isEmpty
                ? null
                : (v) => setState(() => _subUnit = v),
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleDropdown({
    required String label,
    Unit? value,
    required List<Unit> units,
    void Function(Unit?)? onChanged,
  }) {
    return DropdownButtonFormField<Unit>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none,
        ),
        isDense: true,
      ),
      items: units
          .map((u) => DropdownMenuItem(value: u, child: Text(u.name)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildQuantityGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'detailed_stock'.tr(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13.sp,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildModernField(
                  _mainStockController,
                  _mainUnit?.name ?? 'main_unit'.tr(),
                  null,
                  type: TextInputType.number,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                child: Icon(Icons.add, color: Colors.grey[400], size: 16),
              ),
              Expanded(
                child: _buildModernField(
                  _subStockController,
                  _subUnit?.name ?? 'sub_unit'.tr(),
                  null,
                  type: TextInputType.number,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExpirySelector() {
    final direction = Directionality.of(context);
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now().add(const Duration(days: 365)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 3650)),
          locale: context.locale,
        );
        if (date != null) setState(() => _expiryDate = date);
      },
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined, color: Colors.grey),
            SizedBox(width: 12.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'expiry_date'.tr(),
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                ),
                Text(
                  _expiryDate == null
                      ? 'not_set'.tr()
                      : DateFormat.yMd(
                          context.locale.toString(),
                        ).format(_expiryDate!),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.grey,
              textDirection: direction,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseSection() {
    final currentStock = int.tryParse(_totalStockController.text) ?? 0;
    final hasNewStock = currentStock > _initialStock;

    // Show purchase section if adding new product OR increasing stock of existing product
    if (!hasNewStock && widget.product != null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_outlined, color: AppColors.primary, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'accounting_entry'.tr(),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: AppColors.primary),
              ),
              const Spacer(),
              Switch(
                value: _recordAsPurchase,
                onChanged: (val) => setState(() => _recordAsPurchase = val),
                activeColor: AppColors.primary,
              ),
            ],
          ),
          if (_recordAsPurchase) ...[
            SizedBox(height: 10.h),
            Text(
              'record_as_purchase_desc'.tr(),
              style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
            ),
            SizedBox(height: 12.h),
            _buildModernField(
              _paidAmountController,
              'paid_amount'.tr(),
              Icons.payments_outlined,
              type: TextInputType.number,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: EdgeInsets.all(20.w),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.r),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? SizedBox(
                      height: 20.h,
                      width: 20.h,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'save'.tr(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15.sp,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
