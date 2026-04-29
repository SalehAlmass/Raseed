import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/product.dart';
import '../../../core/models/supplier.dart';
import '../../../core/models/supplier_transaction.dart';
import '../../../core/models/supplier_transaction_item.dart';
import '../../../core/services/product_service.dart';
import '../../../core/services/supplier_transaction_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/currency_helper.dart';

class PurchaseScreen extends StatefulWidget {
  final Supplier initialSupplier;
  final Product? initialProduct;
  const PurchaseScreen({super.key, required this.initialSupplier, this.initialProduct});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  final ProductService _productService = sl<ProductService>();
  final SupplierTransactionService _transactionService = sl<SupplierTransactionService>();

  final List<SupplierTransactionItem> _items = [];
  double _totalAmount = 0;
  final TextEditingController _paidAmountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  
  List<Product> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    if (widget.initialProduct != null) {
      _addItem(widget.initialProduct!, 1, widget.initialProduct!.packagePrice);
    }
  }

  Future<void> _loadProducts() async {
    final products = await _productService.getAllProducts();
    setState(() {
      _products = products;
      _isLoading = false;
    });
  }

  void _addItem(Product product, int quantity, double costPrice) {
    setState(() {
      _items.add(SupplierTransactionItem(
        productId: product.id!,
        productName: product.name,
        quantity: quantity,
        costPrice: costPrice,
      ));
      _calculateTotal();
    });
  }

  void _calculateTotal() {
    _totalAmount = _items.fold(0, (sum, item) => sum + (item.quantity * item.costPrice));
  }

  Future<void> _savePurchase() async {
    if (_items.isEmpty) return;

    final paid = double.tryParse(_paidAmountController.text) ?? 0;
    
    final tx = SupplierTransaction(
      supplierId: widget.initialSupplier.id!,
      type: SupplierTransactionType.purchase,
      amount: _totalAmount,
      paidAmount: paid,
      date: DateTime.now(),
      note: _noteController.text,
      items: _items,
    );

    await _transactionService.addTransaction(tx);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('purchase_invoice'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildItemList()),
                _buildFooter(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProductDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_shopping_cart),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(15.w),
      color: AppColors.surface,
      child: Row(
        children: [
          const Icon(Icons.business_rounded, color: AppColors.primary),
          SizedBox(width: 10.w),
          Text(
            widget.initialSupplier.name,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList() {
    if (_items.isEmpty) {
      return Center(child: Text('no_products'.tr()));
    }
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return ListTile(
          title: Text(item.productName),
          subtitle: Text('${item.quantity} x ${CurrencyHelper.getFormatter('YER').format(item.costPrice)}'),
          trailing: Text(
            CurrencyHelper.getFormatter('YER').format(item.quantity * item.costPrice),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          onLongPress: () => setState(() {
            _items.removeAt(index);
            _calculateTotal();
          }),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('total_purchase'.tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
              Text(
                CurrencyHelper.getFormatter('YER').format(_totalAmount),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp, color: AppColors.primary),
              ),
            ],
          ),
          SizedBox(height: 15.h),
          TextField(
            controller: _paidAmountController,
            decoration: InputDecoration(
              labelText: 'paid_amount'.tr(),
              prefixText: 'YER ',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: 15.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _items.isEmpty ? null : _savePurchase,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 15.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: Text('save'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog() {
    Product? selectedProduct;
    final qtyController = TextEditingController();
    final costController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('add_to_invoice'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Product>(
                items: _products.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                onChanged: (val) {
                  setState(() {
                    selectedProduct = val;
                    if (val != null) costController.text = val.packagePrice.toStringAsFixed(0);
                  });
                },
                decoration: InputDecoration(labelText: 'select_product'.tr()),
              ),
              TextField(
                controller: qtyController,
                decoration: InputDecoration(labelText: 'quantity'.tr()),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: costController,
                decoration: InputDecoration(labelText: 'purchase_price'.tr()),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
            ElevatedButton(
              onPressed: () {
                final qty = int.tryParse(qtyController.text) ?? 0;
                final cost = double.tryParse(costController.text) ?? 0.0;
                
                if (selectedProduct != null && qty > 0) {
                  _addItem(
                    selectedProduct!,
                    qty,
                    cost,
                  );
                  Navigator.pop(context);
                } else if (qty <= 0) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('invalid_quantity'.tr())),
                  );
                }
              },
              child: Text('add'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
