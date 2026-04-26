import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/product.dart';
import '../../../core/services/product_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/models/app_feature.dart';
import '../../../core/widgets/subscription_dialog.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/currency_helper.dart';
import 'widgets/add_edit_product_dialog.dart';
import '../../../core/routes/routes.dart';
import '../../../core/widgets/app_bottom_navigation_bar.dart';
import 'widgets/sell_product_dialog.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final ProductService _productService = sl<ProductService>();
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
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
    setState(() {
      _products = products;
      _filteredProducts = products;
      _isLoading = false;
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _products.where((p) {
        return p.name.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _showAddEditDialog([Product? product]) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AddEditProductDialog(product: product),
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
          IconButton(
            icon: const Icon(Icons.category),
            onPressed: () => Navigator.pushNamed(context, Routes.categories),
            tooltip: 'manage_categories'.tr(),
          ),
          IconButton(
            icon: const Icon(Icons.straighten),
            onPressed: () => Navigator.pushNamed(context, Routes.units),
            tooltip: 'manage_units'.tr(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(20.w),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'search_hint'.tr(),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15.r),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProducts.isEmpty
                ? Center(child: Text('no_products'.tr()))
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      return _ProductTile(
                        product: product,
                        onEdit: () => _showAddEditDialog(product),
                        onSell: () => _showSellDialog(product),
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

  const _ProductTile({
    required this.product,
    required this.onEdit,
    required this.onSell,
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
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 8.h),
        leading: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(Icons.inventory_2_outlined, color: statusColor),
        ),
        title: Text(
          product.name,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
        trailing: Row(
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
            SizedBox(width: 10.w),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'sell') {
                  onSell();
                }
              },
              itemBuilder: (context) => [
                if (inStock)
                  PopupMenuItem(
                    value: 'sell',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.point_of_sale,
                          color: AppColors.success,
                          size: 20,
                        ),
                        SizedBox(width: 10.w),
                        Text('sell'.tr()),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.edit,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      SizedBox(width: 10.w),
                      Text('edit'.tr()),
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
