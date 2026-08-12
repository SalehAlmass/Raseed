import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rseed/core/routes/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/models/app_feature.dart';
import '../../../../core/models/product.dart';
import '../../../../core/models/batch.dart';
import '../../../../core/models/category.dart';
import '../../../../core/models/unit.dart';
import '../../../../core/services/product_service.dart';
import '../../../../core/services/category_service.dart';
import '../../../../core/services/unit_service.dart';
import '../../../../core/services/subscription_service.dart';
import '../../../../core/services/supplier_service.dart';
import '../../../../core/services/supplier_transaction_service.dart';
import '../../../../core/models/supplier.dart';
import '../../../../core/models/supplier_transaction.dart';
import '../../../../core/models/supplier_transaction_item.dart';
import '../../../../core/models/app_settings.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/desktop_tokens.dart';
import '../../../../core/utils/currency_helper.dart';
import '../../../../core/widgets/barcode_scanner_view.dart';
import '../../../../core/widgets/desktop/desktop_scaffold.dart';
import '../../../../core/widgets/desktop/page_header.dart';
import '../../../../core/widgets/subscription_dialog.dart';

class AddEditProductScreen extends StatefulWidget {
  final Product? product;

  const AddEditProductScreen({super.key, this.product});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productService = sl<ProductService>();
  final _categoryService = sl<CategoryService>();
  final _unitService = sl<UnitService>();

  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _conversionController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _wholesalePriceController = TextEditingController();
  final _reorderLevelController = TextEditingController(text: '10');

  final _salePriceFocusNode = FocusNode();
  final _wholesalePriceFocusNode = FocusNode();

  // Storage Controllers
  final _totalStockController = TextEditingController();
  final _mainStockController = TextEditingController();
  final _subStockController = TextEditingController();

  // SAR Currency Converter Controllers
  final _sarPurchasePriceController = TextEditingController();
  final _exchangeRateController = TextEditingController();
  bool _useSarConversion = false;
  String _converterCurrency = 'SAR';

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
  bool _isSyncing = false;
  double _marginPercentage = 0.0;
  int _lastSuggestedSale = 0;
  int _lastSuggestedWholesale = 0;
  int _initialStock = 0;
  bool _recordAsPurchase = true;
  final _paidAmountController = TextEditingController(text: '0');
  
  late AppSettings _settings;
  ProductFormConfig _formConfig = ProductFormConfig();
  double? _lastPurchasePrice;

  @override
  void initState() {
    super.initState();
    _loadData();

    // Listen to price changes for margin calculation
    _purchasePriceController.addListener(_calculateMargin);
    _salePriceController.addListener(_calculateMargin);
    _conversionController.addListener(_calculateMargin);

    // SAR Currency Conversion listeners
    _sarPurchasePriceController.addListener(_updateSarToYemeniConversion);
    _exchangeRateController.addListener(_updateSarToYemeniConversion);

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
    _salePriceFocusNode.dispose();
    _wholesalePriceFocusNode.dispose();
    _nameController.dispose();
    _barcodeController.dispose();
    _conversionController.dispose();
    _totalStockController.dispose();
    _mainStockController.dispose();
    _subStockController.dispose();
    _paidAmountController.dispose();
    _sarPurchasePriceController.dispose();
    _exchangeRateController.dispose();
    super.dispose();
  }

  void _updateSarToYemeniConversion() {
    if (!_useSarConversion) return;

    final foreignCost = double.tryParse(_sarPurchasePriceController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    final rate = double.tryParse(_exchangeRateController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;

    if (foreignCost > 0 && rate > 0) {
      final yemeniCost = (foreignCost * rate).round();
      if (_purchasePriceController.text != yemeniCost.toString()) {
        _purchasePriceController.text = yemeniCost.toString();
        // Save the rate to prefs so it persists for the next products
        final prefs = sl<SharedPreferences>();
        if (_converterCurrency == 'SAR') {
          prefs.setDouble('last_sar_exchange_rate', rate);
        } else {
          prefs.setDouble('last_usd_exchange_rate', rate);
        }
      }
    }
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
      // AND the user is not currently focused on the field (to allow manual clearing/editing)
      bool updateSale = (_salePriceController.text.isEmpty || price == 0 || price == _lastSuggestedSale) && !_salePriceFocusNode.hasFocus;
      bool updateWholesale = (_wholesalePriceController.text.isEmpty || wholesale == 0 || wholesale == _lastSuggestedWholesale) && !_wholesalePriceFocusNode.hasFocus;

      if (updateSale) {
        final suggestedSale = (costPerSub * (1 + _formConfig.autoSaleMargin)).round();
        if (mounted) {
          _salePriceController.text = suggestedSale.toString();
          _lastSuggestedSale = suggestedSale;
        }
      }

      if (updateWholesale) {
        // Calculate wholesale price based on the larger unit (carton/package price)
        final suggestedWholesale = (cost * (1 + _formConfig.autoWholesaleMargin)).round();
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
    final prefs = sl<SharedPreferences>();
    final lastSarRate = prefs.getDouble('last_sar_exchange_rate') ?? 400.0;
    final lastUsdRate = prefs.getDouble('last_usd_exchange_rate') ?? 1500.0;

    if (mounted) {
      setState(() {
        _categories = cats;
        _units = units;
        _suppliers = suppliers;
        _settings = settings;
        _formConfig = settings.productFormConfig;
        _exchangeRateController.text = _converterCurrency == 'SAR' 
            ? lastSarRate.toStringAsFixed(0) 
            : lastUsdRate.toStringAsFixed(0);
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

          if (_selectedSupplier != null) {
            sl<ProductService>().getLastPurchaseInfo(p.id!, _selectedSupplier!.id!).then((info) {
              if (mounted) setState(() {
                _lastPurchasePrice = info != null ? (info['cost_price'] as num).toDouble() : null;
              });
            });
          }

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
    
    final factor = int.tryParse(_conversionController.text.replaceAll(RegExp(r'\D'), '')) ?? 1;
    final purchasePrice = double.tryParse(_purchasePriceController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    final salePrice = double.tryParse(_salePriceController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    final wholesalePrice = double.tryParse(_wholesalePriceController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    final reorderLevel = int.tryParse(_reorderLevelController.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
    final totalStock = int.tryParse(_totalStockController.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
    final paidAmount = double.tryParse(_paidAmountController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;

    // Validation: Paid amount cannot exceed total purchase amount for new stock
    final diffStock = totalStock - _initialStock;
    if (_recordAsPurchase && diffStock > 0 && _selectedSupplier != null) {
      final unitCost = factor > 0 ? (purchasePrice / factor) : purchasePrice;
      final totalRequired = (diffStock * unitCost).roundToDouble();
      
      if (paidAmount > totalRequired) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('warning'.tr(), style: const TextStyle(color: Colors.orange)),
              content: Text('paid_amount_exceeds'.tr()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('confirm'.tr()),
                ),
              ],
            ),
          );
        }
        setState(() => _isSaving = false);
        return;
      }
    }

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
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return DesktopScaffold(
      activeNavIndex: 4,
      title: widget.product == null ? 'add_product'.tr() : 'edit_product'.tr(),
      extendBody: true,
      onNavigate: _onNavTap,
      body: _buildMobileBody(),
      desktopBody: _buildDesktopBody(),
    );
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, Routes.home);
        break;
      case 1:
        Navigator.pushReplacementNamed(context, Routes.customers);
        break;
      case 2:
        if (sl<SubscriptionService>().canUseFeature(AppFeature.addSale)) {
          Navigator.pushNamed(context, Routes.sale).then((result) {
            if (result == true) setState(() {});
          });
        } else {
          SubscriptionDialog.show(context);
        }
        break;
      case 3:
        if (sl<SubscriptionService>().canUseFeature(AppFeature.viewReports)) {
          Navigator.pushReplacementNamed(context, Routes.reports);
        } else {
          SubscriptionDialog.show(context);
        }
        break;
      case 4:
        break;
    }
  }

  Widget _buildMobileBody() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              child: Column(
                children: [
                  _buildTier1Section(),
                  _buildTier2Section(),
                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildDesktopBody() {
    final colors = AppColors.of(context);
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: DesktopMetrics.contentMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(
                  title: widget.product == null
                      ? 'add_product'.tr()
                      : 'edit_product'.tr(),
                  subtitle: widget.product?.name,
                  actions: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('cancel'.tr()),
                    ),
                    const SizedBox(width: AppSpace.xs),
                    SizedBox(
                      height: 40,
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check, size: 18),
                        label: Text('save'.tr()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.lg),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide =
                        constraints.maxWidth >= AppBreakpoints.desktop;
                    final left = _buildDesktopTier1Section(colors);
                    final right = _buildDesktopTier2Section(colors);
                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: left),
                          const SizedBox(width: AppSpace.lg),
                          Expanded(flex: 6, child: right),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        left,
                        const SizedBox(height: AppSpace.lg),
                        right,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopSectionCard(
    AppColorSet colors,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
        boxShadow: AppShadow.soft(Colors.black),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colors.textSecondary),
              const SizedBox(width: AppSpace.xs),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDesktopField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
    FocusNode? focusNode,
    String? Function(String?)? validator,
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      focusNode: focusNode,
      validator: validator,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        prefixIcon: Icon(icon, size: 20, color: AppColors.primary),
        isDense: true,
        filled: true,
        fillColor: AppColors.of(context).surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.of(context).border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.of(context).border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDesktopTier1Section(AppColorSet colors) {
    return _buildDesktopSectionCard(
      colors,
      'product_name'.tr(),
      Icons.inventory_2_outlined,
      [
        _buildDesktopField(
          _nameController,
          'product_name'.tr(),
          Icons.inventory_2_outlined,
          required: true,
          validator: (v) =>
              v == null || v.isEmpty ? 'required_field'.tr() : null,
        ),
        if (_formConfig.showBarcode) ...[
          const SizedBox(height: AppSpace.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildDesktopField(
                  _barcodeController,
                  'barcode'.tr(),
                  Icons.qr_code_outlined,
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              SizedBox(
                height: 44,
                child: IconButton.filled(
                  onPressed: () async {
                    final code = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BarcodeScannerView(),
                      ),
                    );
                    if (code != null) {
                      setState(() => _barcodeController.text = code);
                    }
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
        if (_formConfig.showPurchasePrice) ...[
          const SizedBox(height: AppSpace.sm),
          _buildDesktopSarConverterCard(),
        ],
        const SizedBox(height: AppSpace.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_formConfig.showPurchasePrice) ...[
              Expanded(
                child: _buildDesktopField(
                  _purchasePriceController,
                  'purchase_price'.tr(),
                  Icons.shopping_basket_outlined,
                  type: TextInputType.number,
                  validator: (v) {
                    if (v != null &&
                        v.isNotEmpty &&
                        double.tryParse(v) == null) {
                      return 'invalid_number'.tr();
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: AppSpace.sm),
            ],
            Expanded(
              child: _buildDesktopField(
                _salePriceController,
                'selling_price'.tr(),
                Icons.sell_outlined,
                type: TextInputType.number,
                focusNode: _salePriceFocusNode,
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
        if (!_formConfig.showUnits) ...[
          const SizedBox(height: AppSpace.sm),
          _buildDesktopField(
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

  Widget _buildDesktopTier2Section(AppColorSet colors) {
    return _buildDesktopSectionCard(
      colors,
      'pricing_and_organization'.tr(),
      Icons.analytics_outlined,
      [
        if (_formConfig.showCategory) ...[
          _buildDesktopCategoryDropdown(),
          const SizedBox(height: AppSpace.sm),
        ],
        if (_formConfig.showWholesale) ...[
          _buildDesktopField(
            _wholesalePriceController,
            'wholesale_price'.tr(),
            Icons.groups_outlined,
            type: TextInputType.number,
            focusNode: _wholesalePriceFocusNode,
            validator: (v) {
              if (v != null &&
                  v.isNotEmpty &&
                  double.tryParse(v) == null) {
                return 'invalid_number'.tr();
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpace.sm),
        ],
        if (_formConfig.showPurchasePrice) ...[
          _buildDesktopMarginDisplay(),
          const SizedBox(height: AppSpace.sm),
        ],
        if (_formConfig.showSupplier) ...[
          _buildDesktopSupplierDropdown(),
          if (_selectedSupplier != null) ...[
            const SizedBox(height: AppSpace.sm),
            _buildDesktopPurchaseSection(colors),
          ],
        ],
        if (_formConfig.showExpiry) ...[
          const SizedBox(height: AppSpace.sm),
          _buildDesktopExpirySelector(),
        ],
        if (_formConfig.showUnits) ...[
          const SizedBox(height: AppSpace.md),
          Divider(height: 1, color: colors.border),
          const SizedBox(height: AppSpace.md),
          _buildDesktopUnitPairSelection(),
          const SizedBox(height: AppSpace.sm),
          _buildDesktopField(
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
          const SizedBox(height: AppSpace.sm),
          _buildDesktopQuantityGrid(),
        ],
        if (_formConfig.showReorder) ...[
          const SizedBox(height: AppSpace.sm),
          _buildDesktopField(
            _reorderLevelController,
            'reorder_level'.tr(),
            Icons.report_problem_outlined,
            type: TextInputType.number,
            validator: (v) {
              if (v != null &&
                  v.isNotEmpty &&
                  int.tryParse(v) == null) {
                return 'invalid_number'.tr();
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  Widget _buildDesktopCategoryDropdown() {
    final isArabic = context.locale.languageCode == 'ar';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DropdownButtonFormField<Category>(
            value: _selectedCategory,
            decoration: InputDecoration(
              labelText: 'category'.tr(),
              prefixIcon: const Icon(Icons.category_outlined),
              filled: true,
              fillColor: AppColors.of(context).surfaceContainer,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: AppColors.of(context).border),
              ),
            ),
            items: _categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                .toList(),
            onChanged: (val) => setState(() => _selectedCategory = val),
          ),
        ),
        const SizedBox(width: AppSpace.xs),
        SizedBox(
          height: 44,
          child: IconButton.filled(
            onPressed: () async {
              await Navigator.pushNamed(context, Routes.categories);
              final cats = await _categoryService.getAllCategories();
              setState(() {
                _categories = cats;
                if (_selectedCategory != null &&
                    !cats.any((c) => c.id == _selectedCategory!.id)) {
                  _selectedCategory = null;
                }
              });
            },
            icon: const Icon(Icons.add),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            tooltip: isArabic ? 'إدارة الأصناف' : 'Manage Categories',
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopSupplierDropdown() {
    final isArabic = context.locale.languageCode == 'ar';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DropdownButtonFormField<Supplier>(
            value: _selectedSupplier,
            decoration: InputDecoration(
              labelText: 'suppliers'.tr(),
              prefixIcon: const Icon(Icons.business_rounded),
              filled: true,
              fillColor: AppColors.of(context).surfaceContainer,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: AppColors.of(context).border),
              ),
            ),
            items: _suppliers
                .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                .toList(),
            onChanged: (val) {
              setState(() {
                _selectedSupplier = val;
                _lastPurchasePrice = null;
              });
              if (val != null && widget.product != null) {
                sl<ProductService>()
                    .getLastPurchaseInfo(widget.product!.id!, val.id!)
                    .then((info) {
                  if (mounted) {
                    setState(() {
                      _lastPurchasePrice = info != null
                          ? (info['cost_price'] as num).toDouble()
                          : null;
                    });
                  }
                });
              }
            },
          ),
        ),
        const SizedBox(width: AppSpace.xs),
        SizedBox(
          height: 44,
          child: IconButton.filled(
            onPressed: () async {
              await Navigator.pushNamed(context, Routes.suppliers);
              final suppliers = await sl<SupplierService>().getAllSuppliers();
              setState(() {
                _suppliers = suppliers;
                if (_selectedSupplier != null &&
                    !suppliers.any((s) => s.id == _selectedSupplier!.id)) {
                  _selectedSupplier = null;
                }
              });
            },
            icon: const Icon(Icons.add),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            tooltip: isArabic ? 'إدارة الموردين' : 'Manage Suppliers',
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopSimpleDropdown({
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
        fillColor: AppColors.of(context).surfaceContainer,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.of(context).border),
        ),
      ),
      items: units
          .map((u) => DropdownMenuItem(value: u, child: Text(u.name)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDesktopUnitPairSelection() {
    final mainUnits = _units.where((u) => u.parentId == null).toList();
    final filteredSubUnits = _mainUnit == null
        ? <Unit>[]
        : _units.where((u) => u.parentId == _mainUnit?.id).toList();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildDesktopSimpleDropdown(
            label: 'main_unit'.tr(),
            value: _mainUnit,
            units: mainUnits,
            onChanged: (v) {
              setState(() {
                _mainUnit = v;
                final potentialSubs = _units
                    .where((u) => u.parentId == _mainUnit?.id)
                    .toList();
                if (potentialSubs.length == 1) {
                  _subUnit = potentialSubs.first;
                } else if (_subUnit != null &&
                    _subUnit?.parentId != _mainUnit?.id) {
                  _subUnit = null;
                }
              });
            },
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: _buildDesktopSimpleDropdown(
            label: 'sub_unit'.tr(),
            value: _subUnit,
            units: filteredSubUnits,
            onChanged: _mainUnit == null || filteredSubUnits.isEmpty
                ? null
                : (v) => setState(() => _subUnit = v),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopQuantityGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'detailed_stock'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: AppSpace.xs),
        Container(
          padding: const EdgeInsets.all(AppSpace.sm),
          decoration: BoxDecoration(
            color: AppColors.of(context).surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildDesktopField(
                  _mainStockController,
                  _mainUnit?.name ?? 'main_unit'.tr(),
                  Icons.inventory_2_outlined,
                  type: TextInputType.number,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
                child: Icon(Icons.add, color: AppColors.of(context).textLight, size: 16),
              ),
              Expanded(
                child: _buildDesktopField(
                  _subStockController,
                  _subUnit?.name ?? 'sub_unit'.tr(),
                  Icons.inventory_2_outlined,
                  type: TextInputType.number,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopMarginDisplay() {
    final bool isProfit = _marginPercentage >= 0;
    return Container(
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: (isProfit ? Colors.green : Colors.red).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: (isProfit ? Colors.green : Colors.red).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'profit_margin'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Text(
            '${_marginPercentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isProfit ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopExpirySelector() {
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
        padding: const EdgeInsets.all(AppSpace.sm),
        decoration: BoxDecoration(
          color: AppColors.of(context).surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_outlined, color: AppColors.of(context).textLight),
            const SizedBox(width: AppSpace.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'expiry_date'.tr(),
                  style: TextStyle(fontSize: 11, color: AppColors.of(context).textSecondary),
                ),
                Text(
                  _expiryDate == null
                      ? 'not_set'.tr()
                      : DateFormat.yMd(context.locale.toString())
                          .format(_expiryDate!),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppColors.of(context).textLight,
              textDirection: direction,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopPurchaseSection(AppColorSet colors) {
    final currentStock = int.tryParse(_totalStockController.text) ?? 0;
    final hasNewStock = currentStock > _initialStock;
    if (!hasNewStock && widget.product != null) return const SizedBox.shrink();

    final currentPurchasePrice =
        double.tryParse(_purchasePriceController.text) ?? 0;
    final hasPriceDiff = _lastPurchasePrice != null &&
        _lastPurchasePrice! > 0 &&
        currentPurchasePrice > 0;
    final priceDiff =
        hasPriceDiff ? currentPurchasePrice - _lastPurchasePrice! : 0.0;
    final diffPercent = hasPriceDiff
        ? ((priceDiff / _lastPurchasePrice!) * 100).abs()
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_outlined,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: AppSpace.xs),
              Text(
                'accounting_entry'.tr(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              Switch(
                value: _recordAsPurchase,
                onChanged: (val) => setState(() => _recordAsPurchase = val),
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
          if (_recordAsPurchase) ...[
            const SizedBox(height: AppSpace.sm),
            if (_lastPurchasePrice != null && _lastPurchasePrice! > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.sm,
                  vertical: AppSpace.xs,
                ),
                decoration: BoxDecoration(
                  color: hasPriceDiff && priceDiff > 0
                      ? Colors.red.withValues(alpha: 0.05)
                      : Colors.green.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: hasPriceDiff && priceDiff > 0
                        ? Colors.red.withValues(alpha: 0.2)
                        : Colors.green.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasPriceDiff && priceDiff > 0
                          ? Icons.trending_up
                          : Icons.trending_down,
                      size: 16,
                      color:
                          hasPriceDiff && priceDiff > 0
                          ? Colors.red
                          : Colors.green,
                    ),
                    const SizedBox(width: AppSpace.xs),
                    Expanded(
                      child: Text(
                        '${'last_purchase'.tr()}: ${CurrencyHelper.getFormatter('YER').format(_lastPurchasePrice!)}  '
                        '(${hasPriceDiff ? '${priceDiff > 0 ? "+" : ""}${CurrencyHelper.getFormatter('YER').format(priceDiff)}' : "0"} '
                        '| ${diffPercent.toStringAsFixed(1)}%)',
                        style: TextStyle(fontSize: 10, color: AppColors.of(context).textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpace.sm),
            Text(
              'record_as_purchase_desc'.tr(),
              style: TextStyle(fontSize: 11, color: AppColors.of(context).textSecondary),
            ),
            const SizedBox(height: AppSpace.sm),
            _buildDesktopField(
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

  Widget _buildDesktopSarConverterCard() {
    final isArabic = context.locale.languageCode == 'ar';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            Colors.amber.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.currency_exchange_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: AppSpace.xs),
              Expanded(
                child: Text(
                  isArabic ? 'حاسبة الشراء بالعملات الأجنبية' : 'Foreign Currency Calculator',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Switch(
                value: _useSarConversion,
                activeThumbColor: AppColors.primary,
                onChanged: (val) {
                  setState(() {
                    _useSarConversion = val;
                    if (!val) {
                      _sarPurchasePriceController.clear();
                    } else {
                      _updateSarToYemeniConversion();
                    }
                  });
                },
              ),
            ],
          ),
          if (_useSarConversion) ...[
            const SizedBox(height: AppSpace.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _buildDesktopCurrencyChoiceChip(
                  'SAR',
                  isArabic ? 'ريال سعودي 🇸🇦' : 'SAR 🇸🇦',
                ),
                const SizedBox(width: AppSpace.xs),
                _buildDesktopCurrencyChoiceChip(
                  'USD',
                  isArabic ? 'دولار أمريكي 🇺🇸' : 'USD 🇺🇸',
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildDesktopField(
                    _sarPurchasePriceController,
                    _converterCurrency == 'SAR'
                        ? (isArabic ? 'سعر الشراء (سعودي 🇸🇦)' : 'Purchase Cost (SAR 🇸🇦)')
                        : (isArabic ? 'سعر الشراء (دولار 🇺🇸)' : 'Purchase Cost (USD 🇺🇸)'),
                    Icons.payments_outlined,
                    type: TextInputType.number,
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: _buildDesktopField(
                    _exchangeRateController,
                    isArabic ? 'سعر الصرف اليوم' : 'Exchange Rate Today',
                    Icons.trending_up_rounded,
                    type: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.sm,
                vertical: AppSpace.xs,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isArabic ? 'القيمة المعادلة باليمني:' : 'Equivalent in YER:',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.of(context).textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_purchasePriceController.text} ${isArabic ? "ريال يمني 🇾🇪" : "YER 🇾🇪"}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopCurrencyChoiceChip(String value, String label) {
    final isSelected = _converterCurrency == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _converterCurrency = value;
            final prefs = sl<SharedPreferences>();
            if (value == 'SAR') {
              final lastRate = prefs.getDouble('last_sar_exchange_rate') ?? 400.0;
              _exchangeRateController.text = lastRate.toStringAsFixed(0);
            } else {
              final lastRate = prefs.getDouble('last_usd_exchange_rate') ?? 1500.0;
              _exchangeRateController.text = lastRate.toStringAsFixed(0);
            }
            _updateSarToYemeniConversion();
          });
        }
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.primary,
    );
  }

  Widget _buildTier1Section() {
    return Column(
      children: [
        _buildModernField(
          _nameController,
          'product_name'.tr(),
          Icons.inventory_2_outlined,
          hint: 'product_name'.tr(),
          required: true,
          validator: (v) =>
              v == null || v.isEmpty ? 'required_field'.tr() : null,
        ),
        if (_formConfig.showBarcode) ...[
          SizedBox(height: 12.h),
          _buildBarcodeField(),
        ],
        if (_formConfig.showPurchasePrice) ...[
          SizedBox(height: 12.h),
          _buildSarConverterCard(),
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
                focusNode: _salePriceFocusNode,
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
        if (!_formConfig.showUnits) ...[
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
            focusNode: _wholesalePriceFocusNode,
            validator: (v) {
              if (v != null && v.isNotEmpty && double.tryParse(v) == null)
                return 'invalid_number'.tr();
              return null;
            },
          ),
        ],
        
        if (_formConfig.showPurchasePrice) ...[
          SizedBox(height: 16.h),
          _buildMarginDisplay(),
        ],
        
        if (_formConfig.showSupplier) ...[
          SizedBox(height: 16.h),
          _buildSupplierDropdown(),
          if (_selectedSupplier != null) ...[
            SizedBox(height: 16.h),
            _buildPurchaseSection(),
          ],
        ],
        
        if (_formConfig.showExpiry) ...[
          SizedBox(height: 16.h),
          _buildExpirySelector(),
        ],
      ],
    );
  }

  Widget _buildSupplierDropdown() {
    final isArabic = context.locale.languageCode == 'ar';
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<Supplier>(
            value: _selectedSupplier,
            decoration: InputDecoration(
              labelText: 'suppliers'.tr(),
              prefixIcon: const Icon(Icons.business_rounded),
              filled: true,
              fillColor: AppColors.of(context).surfaceContainer,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide.none,
              ),
              isDense: true,
            ),
            items: _suppliers
                .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                .toList(),
            onChanged: (val) {
              setState(() {
                _selectedSupplier = val;
                _lastPurchasePrice = null;
              });
              if (val != null && widget.product != null) {
                sl<ProductService>().getLastPurchaseInfo(widget.product!.id!, val.id!).then((info) {
                  if (mounted) setState(() {
                    _lastPurchasePrice = info != null ? (info['cost_price'] as num).toDouble() : null;
                  });
                });
              }
            },
          ),
        ),
        SizedBox(width: 8.w),
        IconButton.filled(
          onPressed: () async {
            await Navigator.pushNamed(context, Routes.suppliers);
            final suppliers = await sl<SupplierService>().getAllSuppliers();
            setState(() {
              _suppliers = suppliers;
              if (_selectedSupplier != null && !suppliers.any((s) => s.id == _selectedSupplier!.id)) {
                _selectedSupplier = null;
              }
            });
          },
          icon: const Icon(Icons.add),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
          tooltip: isArabic ? 'إدارة الموردين' : 'Manage Suppliers',
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18.sp, color: AppColors.of(context).textSecondary),
        SizedBox(width: 8.w),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.of(context).textSecondary,
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
        color: (isProfit ? Colors.green : Colors.red).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(
          color: (isProfit ? Colors.green : Colors.red).withValues(alpha: 0.2),
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

  Widget _buildModernField(
    TextEditingController controller,
    String label,
    IconData? icon, {
    TextInputType type = TextInputType.text,
    String? hint,
    FocusNode? focusNode,
    String? Function(String?)? validator,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8.h, right: 4.w),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.of(context).textSecondary,
                ),
              ),
              if (required)
                Text(
                  ' *',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
            ],
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: type,
          focusNode: focusNode,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon, size: 20.sp, color: AppColors.primary) : null,
            filled: true,
            fillColor: AppColors.of(context).surfaceContainer,
            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: AppColors.of(context).border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: AppColors.of(context).border),
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
    final isArabic = context.locale.languageCode == 'ar';
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<Category>(
            value: _selectedCategory,
            decoration: InputDecoration(
              labelText: 'category'.tr(),
              prefixIcon: const Icon(Icons.category_outlined),
              filled: true,
              fillColor: AppColors.of(context).surfaceContainer,
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
          ),
        ),
        SizedBox(width: 8.w),
        IconButton.filled(
          onPressed: () async {
            await Navigator.pushNamed(context, Routes.categories);
            final cats = await _categoryService.getAllCategories();
            setState(() {
              _categories = cats;
              if (_selectedCategory != null && !cats.any((c) => c.id == _selectedCategory!.id)) {
                _selectedCategory = null;
              }
            });
          },
          icon: const Icon(Icons.add),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
          tooltip: isArabic ? 'إدارة الأصناف' : 'Manage Categories',
        ),
      ],
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
        fillColor: AppColors.of(context).surfaceContainer,
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
            color: AppColors.of(context).textSecondary,
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.of(context).surfaceContainer,
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
                child: Icon(Icons.add, color: AppColors.of(context).textLight, size: 16),
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
          color: AppColors.of(context).surfaceContainer,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_outlined, color: AppColors.of(context).textLight),
            SizedBox(width: 12.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'expiry_date'.tr(),
                  style: TextStyle(fontSize: 11.sp, color: AppColors.of(context).textSecondary),
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
              color: AppColors.of(context).textLight,
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

    final currentPurchasePrice = double.tryParse(_purchasePriceController.text) ?? 0;
    final hasPriceDiff = _lastPurchasePrice != null && _lastPurchasePrice! > 0 && currentPurchasePrice > 0;
    final priceDiff = hasPriceDiff ? currentPurchasePrice - _lastPurchasePrice! : 0.0;
    final diffPercent = hasPriceDiff ? ((priceDiff / _lastPurchasePrice!) * 100).abs() : 0.0;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
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
            if (_lastPurchasePrice != null && _lastPurchasePrice! > 0)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: hasPriceDiff && priceDiff > 0 ? Colors.red.withValues(alpha: 0.05) : Colors.green.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: hasPriceDiff && priceDiff > 0 ? Colors.red.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasPriceDiff && priceDiff > 0 ? Icons.trending_up : Icons.trending_down,
                      size: 16.sp,
                      color: hasPriceDiff && priceDiff > 0 ? Colors.red : Colors.green,
                    ),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        '${'last_purchase'.tr()}: ${CurrencyHelper.getFormatter('YER').format(_lastPurchasePrice!)}  '
                        '(${hasPriceDiff ? '${priceDiff > 0 ? "+" : ""}${CurrencyHelper.getFormatter('YER').format(priceDiff)}' : "0"} '
                        '| ${diffPercent.toStringAsFixed(1)}%)',
                        style: TextStyle(fontSize: 10.sp, color: AppColors.of(context).textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 10.h),
            Text(
              'record_as_purchase_desc'.tr(),
              style: TextStyle(fontSize: 11.sp, color: AppColors.of(context).textSecondary),
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

  Widget _buildSarConverterCard() {
    final isArabic = context.locale.languageCode == 'ar';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            Colors.amber.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.currency_exchange_rounded, color: AppColors.primary, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                isArabic ? 'حاسبة الشراء بالعملات الأجنبية' : 'Foreign Currency Calculator',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.sp,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              Switch(
                value: _useSarConversion,
                activeColor: AppColors.primary,
                onChanged: (val) {
                  setState(() {
                    _useSarConversion = val;
                    if (!val) {
                      _sarPurchasePriceController.clear();
                    } else {
                      _updateSarToYemeniConversion();
                    }
                  });
                },
              ),
            ],
          ),
          if (_useSarConversion) ...[
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _buildCurrencyChoiceChip('SAR', isArabic ? 'ريال سعودي 🇸🇦' : 'SAR 🇸🇦'),
                SizedBox(width: 8.w),
                _buildCurrencyChoiceChip('USD', isArabic ? 'دولار أمريكي 🇺🇸' : 'USD 🇺🇸'),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: _buildModernField(
                    _sarPurchasePriceController,
                    _converterCurrency == 'SAR'
                        ? (isArabic ? 'سعر الشراء (سعودي 🇸🇦)' : 'Purchase Cost (SAR 🇸🇦)')
                        : (isArabic ? 'سعر الشراء (دولار 🇺🇸)' : 'Purchase Cost (USD 🇺🇸)'),
                    Icons.payments_outlined,
                    type: TextInputType.number,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: _buildModernField(
                    _exchangeRateController,
                    isArabic ? 'سعر الصرف اليوم' : 'Exchange Rate Today',
                    Icons.trending_up_rounded,
                    type: TextInputType.number,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isArabic ? 'القيمة المعادلة باليمني:' : 'Equivalent in YER:',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.of(context).textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_purchasePriceController.text} ${isArabic ? "ريال يمني 🇾🇪" : "YER 🇾🇪"}',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrencyChoiceChip(String value, String label) {
    final isSelected = _converterCurrency == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11.sp, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _converterCurrency = value;
            final prefs = sl<SharedPreferences>();
            if (value == 'SAR') {
              final lastRate = prefs.getDouble('last_sar_exchange_rate') ?? 400.0;
              _exchangeRateController.text = lastRate.toStringAsFixed(0);
            } else {
              final lastRate = prefs.getDouble('last_usd_exchange_rate') ?? 1500.0;
              _exchangeRateController.text = lastRate.toStringAsFixed(0);
            }
            _updateSarToYemeniConversion();
          });
        }
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.primary,
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
