import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/product.dart';
import '../../../core/services/product_service.dart';
import '../../../core/services/supplier_service.dart';
import '../../suppliers/views/purchase_screen.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/models/app_feature.dart';
import '../../../core/widgets/subscription_dialog.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/currency_helper.dart';
import 'widgets/add_edit_product_screen.dart';
import 'widgets/quick_purchase_dialog.dart';
import '../../../core/routes/routes.dart';
import '../../../core/widgets/app_bottom_navigation_bar.dart';
import 'widgets/sell_product_dialog.dart';
import '../../../core/models/category.dart';
import '../../../core/services/category_service.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final ProductService _productService = sl<ProductService>();
  final CategoryService _categoryService = sl<CategoryService>();
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  List<Category> _categories = [];
  Category? _selectedCategory;
  String _selectedStatus = 'all'; // 'all', 'outOfStock', 'expired', 'nearExpiry'
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final products = await _productService.getAllProducts();
    final categories = await _categoryService.getAllCategories();
    setState(() {
      _products = products;
      _categories = categories;
      _isLoading = false;
      _applyFilters();
    });
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _products.where((p) {
        // 1. Search Query Filter
        final matchesQuery = p.name.toLowerCase().contains(query);

        // 2. Category Filter
        final matchesCategory = _selectedCategory == null || p.categoryId == _selectedCategory!.id;

        // 3. Status Filter
        bool matchesStatus = true;
        if (_selectedStatus == 'outOfStock') {
          matchesStatus = p.stockQuantity <= 0;
        } else if (_selectedStatus == 'expired') {
          matchesStatus = p.hasExpiredBatch;
        } else if (_selectedStatus == 'nearExpiry') {
          matchesStatus = p.hasNearExpiryBatch;
        }

        return matchesQuery && matchesCategory && matchesStatus;
      }).toList();
    });
  }

  bool get _hasActiveFilters => _selectedCategory != null || _selectedStatus != 'all' || _searchController.text.isNotEmpty;

  void _clearFilters() {
    setState(() {
      _selectedCategory = null;
      _selectedStatus = 'all';
      _searchController.clear();
      _applyFilters();
    });
  }

  Widget _buildCategoryFilterChip(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    return PopupMenuButton<Category?>(
      initialValue: _selectedCategory,
      onSelected: (Category? category) {
        setState(() {
          _selectedCategory = category;
          _applyFilters();
        });
      },
      itemBuilder: (context) => [
        PopupMenuItem<Category?>(
          value: null,
          child: Text(isArabic ? 'كل الأصناف' : 'All Categories'),
        ),
        ..._categories.map((cat) => PopupMenuItem<Category?>(
          value: cat,
          child: Text(cat.name),
        )),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: _selectedCategory != null 
              ? AppColors.primary 
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: _selectedCategory != null 
                ? AppColors.primary 
                : Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.category_outlined,
              size: 16.sp,
              color: _selectedCategory != null ? Colors.white : AppColors.textSecondary,
            ),
            SizedBox(width: 6.w),
            Text(
              _selectedCategory?.name ?? (isArabic ? 'الصنف' : 'Category'),
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: _selectedCategory != null ? Colors.white : AppColors.textSecondary,
              ),
            ),
            SizedBox(width: 4.w),
            Icon(
              Icons.arrow_drop_down,
              size: 16.sp,
              color: _selectedCategory != null ? Colors.white : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, String label) {
    final isSelected = _selectedStatus == status;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedStatus = status;
          _applyFilters();
        });
      },
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  void _showAddEditDialog([Product? product]) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditProductScreen(product: product),
      ),
    );
    if (result == true) {
      _loadProducts();
    }
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
            if (result == true) _loadProducts();
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

  void _showSellDialog(Product product) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => SellProductDialog(product: product),
    );
    if (result == true) {
      _loadProducts();
    }
  }

  Future<void> _onPurchase(Product product) async {
    if (product.supplierId == null) return;

    final supplier = await sl<SupplierService>().getSupplierById(
      product.supplierId!,
    );
    if (supplier != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PurchaseScreen(
            initialSupplier: supplier,
            initialProduct: product,
          ),
        ),
      ).then((_) => _loadProducts());
    }
  }

  void _onDelete(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('delete_confirm'.tr()),
        content: Text('delete_product_warning'.tr()), // Note: Ensure this key exists or use a generic one
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'delete'.tr(),
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _productService.deleteProduct(product.id!);
      _loadProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('success'.tr())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('store'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.business_rounded),
          //   onPressed: () => Navigator.pushNamed(context, Routes.suppliers),
          //   tooltip: 'suppliers'.tr(),
          // ),
          IconButton(
            icon: const Icon(Icons.category),
            onPressed: () => Navigator.pushNamed(context, Routes.categories).then((_) => _loadProducts()),
            tooltip: 'manage_categories'.tr(),
          ),
          IconButton(
            icon: const Icon(Icons.straighten),
            onPressed: () => Navigator.pushNamed(context, Routes.units).then((_) => _loadProducts()),
            tooltip: 'manage_units'.tr(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 20.h, bottom: 10.h),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'search_hint'.tr(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _hasActiveFilters
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: AppColors.error),
                        onPressed: _clearFilters,
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15.r),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // Horizontal Category filter chips & Status chips
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryFilterChip(context),
                  SizedBox(width: 8.w),
                  _buildStatusChip('all', context.locale.languageCode == 'ar' ? 'الكل' : 'All'),
                  SizedBox(width: 8.w),
                  _buildStatusChip('outOfStock', context.locale.languageCode == 'ar' ? 'نفذ من المخزن' : 'Out of Stock'),
                  SizedBox(width: 8.w),
                  _buildStatusChip('expired', context.locale.languageCode == 'ar' ? 'منتهي الصلاحية' : 'Expired'),
                  SizedBox(width: 8.w),
                  _buildStatusChip('nearExpiry', context.locale.languageCode == 'ar' ? 'قريب الانتهاء' : 'Near Expiry'),
                ],
              ),
            ),
          ),
          SizedBox(height: 15.h),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProducts.isEmpty
                ? Center(child: Text('no_products'.tr()))
                : ListView.builder(
                    padding: EdgeInsets.only(
                      left: 20.w,
                      right: 20.w,
                      bottom: 100.h,
                    ),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      return _ProductTile(
                        product: product,
                        onEdit: () {
                          if (sl<SubscriptionService>().canUseFeature(
                            AppFeature.editInventory,
                          )) {
                            _showAddEditDialog(product);
                          } else {
                            SubscriptionDialog.show(context);
                          }
                        },
                        onSell: () {
                          if (sl<SubscriptionService>().canUseFeature(
                            AppFeature.addSale,
                          )) {
                            _showSellDialog(product);
                          } else {
                            SubscriptionDialog.show(context);
                          }
                        },
                        onPurchase: product.supplierId == null
                            ? null
                            : () => _onPurchase(product),
                        onDelete: () => _onDelete(product),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (sl<SubscriptionService>().canUseFeature(
            AppFeature.editInventory,
          )) {
            _showAddEditDialog();
          } else {
            SubscriptionDialog.show(context);
          }
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        activeIndex: 4,
        onTap: _onNavTap,
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onSell;
  final VoidCallback onDelete;
  final VoidCallback? onPurchase;

  const _ProductTile({
    required this.product,
    required this.onEdit,
    required this.onSell,
    required this.onDelete,
    this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final inStock = product.stockQuantity > 0;
    final isExpired = product.hasExpiredBatch;
    final isNearExpiry = product.hasNearExpiryBatch;

    final statusColor = isExpired
        ? AppColors.error
        : (isNearExpiry
              ? Colors.orange
              : (inStock ? AppColors.success : AppColors.error));

    return Container(
      margin: EdgeInsets.only(bottom: 15.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 12.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(Icons.inventory_2_outlined, color: statusColor),
            ),
            SizedBox(width: 15.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    sl<ProductService>().formatStock(
                      product.stockQuantity,
                      product.unitsPerPackage,
                    ),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: (isExpired || isNearExpiry)
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  if (isExpired)
                    Text(
                      'expired'.tr(),
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (!isExpired && isNearExpiry)
                    Text(
                      'near_expiry'.tr(),
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${CurrencyHelper.getFormatter(product.currency).format(product.price)} ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                        color: AppColors.primary,
                      ),
                    ),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.more_vert, size: 20),
                      onSelected: (value) {
                        if (value == 'edit') {
                          onEdit();
                        } else if (value == 'sell') {
                          onSell();
                        } else if (value == 'purchase') {
                          onPurchase?.call();
                        } else if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (context) => [
                        if (inStock)
                          PopupMenuItem(
                            value: 'sell',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.shopping_cart_outlined,
                                  size: 20,
                                ),
                                SizedBox(width: 8.w),
                                Text('sell'.tr()),
                              ],
                            ),
                          ),
                        if (product.supplierId != null)
                          PopupMenuItem(
                            value: 'purchase',
                            child: Row(
                              children: [
                                const Icon(Icons.add_shopping_cart, size: 20),
                                SizedBox(width: 8.w),
                                Text('purchase'.tr()),
                              ],
                            ),
                          ),
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(Icons.edit_outlined, size: 20),
                              SizedBox(width: 8.w),
                              Text('edit'.tr()),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: AppColors.error,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                'delete'.tr(),
                                style: const TextStyle(color: AppColors.error),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Show expiry date if available
                if (product.batches.any((b) => b.expiryDate != null))
                  Padding(
                    padding: EdgeInsets.only(right: 8.w, top: 2.h),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_note,
                          size: 10.sp,
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          DateFormat.yMd(context.locale.toString()).format(
                            product.batches
                                .where((b) => b.expiryDate != null)
                                .map((b) => b.expiryDate!)
                                .reduce((a, b) => a.isBefore(b) ? a : b),
                          ),
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
