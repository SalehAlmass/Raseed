import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/supplier.dart';
import '../../../core/services/product_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/currency_helper.dart';

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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('purchase_history'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Column(
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
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12.r),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.all(12.w),
                              leading: Container(
                                padding: EdgeInsets.all(8.w),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                child: const Icon(Icons.shopping_cart_outlined, color: AppColors.primary),
                              ),
                              title: Text(productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (widget.initialSupplier == null)
                                    Text(supplierName, style: TextStyle(fontSize: 11.sp, color: Colors.grey[600])),
                                  Row(
                                    children: [
                                      Text('${qty} ${'units'.tr()}', style: TextStyle(fontSize: 11.sp, color: Colors.grey[500])),
                                      SizedBox(width: 8.w),
                                      Text('× ${CurrencyHelper.getFormatter('YER').format(price)}', style: TextStyle(fontSize: 11.sp, color: Colors.grey[500])),
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
                                    style: TextStyle(fontSize: 10.sp, color: Colors.grey[400]),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
