import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/app_feature.dart';
import '../../../core/models/supplier.dart';
import '../../../core/routes/routes.dart';
import '../../../core/services/product_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/desktop_tokens.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/widgets/desktop/desktop_scaffold.dart';
import '../../../core/widgets/desktop/desktop_table.dart';
import '../../../core/widgets/desktop/page_header.dart';
import '../../../core/widgets/subscription_dialog.dart';

class SupplierPurchaseHistoryScreen extends StatefulWidget {
  final Supplier? initialSupplier;
  const SupplierPurchaseHistoryScreen({super.key, this.initialSupplier});

  @override
  State<SupplierPurchaseHistoryScreen> createState() => _SupplierPurchaseHistoryScreenState();
}

class _SupplierPurchaseHistoryScreenState extends State<SupplierPurchaseHistoryScreen> {
  final ProductService _productService = sl<ProductService>();
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _filteredHistory = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final history = await _productService.getAllPurchaseHistoryWithProduct();
    setState(() {
      if (widget.initialSupplier != null) {
        _history = history.where((h) => h['supplier_id'] == widget.initialSupplier!.id).toList();
      } else {
        _history = history;
      }
      _filteredHistory = _history;
      _isLoading = false;
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredHistory = _history.where((h) {
        final name = (h['product_name'] as String?)?.toLowerCase() ?? '';
        final supplier = (h['supplier_name'] as String?)?.toLowerCase() ?? '';
        return name.contains(query) || supplier.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DesktopScaffold(
      activeNavIndex: -1,
      title: 'purchase_history'.tr(),
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
        break;
      case 2:
        if (sl<SubscriptionService>().canUseFeature(AppFeature.addSale)) {
          Navigator.pushNamed(context, Routes.sale);
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
        Navigator.pushReplacementNamed(context, Routes.store);
        break;
    }
  }

  Widget _buildMobileBody() {
    return Column(
      children: [
        if (widget.initialSupplier == null)
          Padding(
            padding: EdgeInsets.all(20.w),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'search_product'.tr(),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.of(context).surface,
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
              : _filteredHistory.isEmpty
                  ? Center(child: Text('no_purchase_history'.tr()))
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
                      itemCount: _filteredHistory.length,
                      itemBuilder: (context, index) {
                        final record = _filteredHistory[index];
                        final price = (record['cost_price'] as num).toDouble();
                        final qty = (record['quantity'] as num).toInt();
                        final date = DateTime.parse(record['date'] as String);
                        final productName = record['product_name'] as String? ?? '';
                        final supplierName = record['supplier_name'] as String? ?? '';

                        return Container(
                          margin: EdgeInsets.only(bottom: 10.h),
                          decoration: BoxDecoration(
                            color: AppColors.of(context).surface,
                            borderRadius: BorderRadius.circular(12.r),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3)),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.all(12.w),
                            leading: Container(
                              padding: EdgeInsets.all(8.w),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: const Icon(Icons.shopping_cart_outlined, color: AppColors.primary),
                            ),
                            title: Text(productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.initialSupplier == null)
                                  Text(supplierName, style: TextStyle(fontSize: 11.sp, color: AppColors.of(context).textSecondary)),
                                Row(
                                  children: [
                                    Text('${qty} ${'units'.tr()}', style: TextStyle(fontSize: 11.sp, color: AppColors.of(context).textLight)),
                                    SizedBox(width: 8.w),
                                    Text('× ${CurrencyHelper.getFormatter('YER').format(price)}', style: TextStyle(fontSize: 11.sp, color: AppColors.of(context).textLight)),
                                  ],
                                ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  CurrencyHelper.getFormatter('YER').format(price * qty),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                                Text(
                                  DateFormat('yyyy/MM/dd').format(date),
                                  style: TextStyle(fontSize: 10.sp, color: AppColors.of(context).textLight),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildDesktopBody() {
    final colors = AppColors.of(context);
    return SingleChildScrollView(
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
                title: 'purchase_history'.tr(),
                subtitle: widget.initialSupplier?.name,
              ),
              const SizedBox(height: AppSpace.lg),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.md,
                  vertical: AppSpace.sm,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: colors.border),
                  boxShadow: AppShadow.soft(Colors.black),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 340,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'search_product'.tr(),
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          filled: true,
                          fillColor: colors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_filteredHistory.length}',
                      style: TextStyle(fontSize: 12, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              _buildDesktopHistoryTable(colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopHistoryTable(AppColorSet colors) {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final showSupplier = widget.initialSupplier == null;
    final headers = [
      'product_name'.tr(),
      if (showSupplier) 'supplier'.tr(),
      'quantity'.tr(),
      'purchase_price'.tr(),
      'total'.tr(),
      'date'.tr(),
    ];
    final flexes = [
      3,
      if (showSupplier) 2,
      2,
      2,
      2,
      2,
    ];
    final rows = _filteredHistory.map((record) {
      final price = (record['cost_price'] as num).toDouble();
      final qty = (record['quantity'] as num).toInt();
      final date = DateTime.parse(record['date'] as String);
      final productName = record['product_name'] as String? ?? '';
      final supplierName = record['supplier_name'] as String? ?? '';
      return <Widget>[
        Text(
          productName,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        if (showSupplier)
          Text(supplierName, style: const TextStyle(fontSize: 12)),
        Text('$qty', style: const TextStyle(fontSize: 12)),
        Text(
          CurrencyHelper.getFormatter('YER').format(price),
          style: const TextStyle(fontSize: 12),
        ),
        Text(
          CurrencyHelper.getFormatter('YER').format(price * qty),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        Text(
          DateFormat('yyyy/MM/dd').format(date),
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
      ];
    }).toList();
    return DesktopTable(
      headers: headers,
      flexes: flexes,
      rows: rows,
      emptyMessage: 'no_purchase_history'.tr(),
      maxHeight: 520,
    );
  }
}
