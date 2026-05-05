import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/purchase_order.dart';
import '../../../core/models/supplier.dart';
import '../../../core/models/product.dart';
import '../../../core/services/supplier_service.dart';
import '../../../core/services/product_service.dart';
import '../../../core/services/procurement_service.dart';

class CreatePurchaseOrderScreen extends StatefulWidget {
  final Supplier? initialSupplier;
  const CreatePurchaseOrderScreen({super.key, this.initialSupplier});

  @override
  State<CreatePurchaseOrderScreen> createState() => _CreatePurchaseOrderScreenState();
}

class _CreatePurchaseOrderScreenState extends State<CreatePurchaseOrderScreen> {
  final _procurementService = sl<ProcurementService>();
  final _supplierService = sl<SupplierService>();
  final _productService = sl<ProductService>();

  Supplier? _selectedSupplier;
  List<Supplier> _suppliers = [];
  List<Product> _products = [];
  final List<PurchaseOrderItem> _selectedItems = [];
  final _noteController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedSupplier = widget.initialSupplier;
    _loadData();
  }

  Future<void> _loadData() async {
    final suppliers = await _supplierService.getAllSuppliers();
    final products = await _productService.getAllProducts();
    setState(() {
      _suppliers = suppliers;
      _products = products;
      _isLoading = false;
    });
  }

  void _addItem(Product product) {
    setState(() {
      _selectedItems.add(PurchaseOrderItem(
        productId: product.id!,
        productName: product.name,
        quantity: 1,
        costPrice: product.costPrice,
      ));
    });
  }

  Future<void> _savePO() async {
    if (_selectedSupplier == null || _selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('please_select_supplier_and_items'.tr())),
      );
      return;
    }

    final total = _selectedItems.fold(0.0, (sum, item) => sum + (item.costPrice * item.quantity));

    final po = PurchaseOrder(
      supplierId: _selectedSupplier!.id!,
      date: DateTime.now(),
      status: PurchaseOrderStatus.pending,
      totalAmount: total,
      note: _noteController.text,
      items: _selectedItems,
    );

    await _procurementService.createPurchaseOrder(po);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('create_po'.tr())),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildItemsList()),
                _buildFooter(),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          DropdownButtonFormField<Supplier>(
            value: _selectedSupplier,
            decoration: InputDecoration(
              labelText: 'supplier'.tr(),
              border: const OutlineInputBorder(),
            ),
            items: _suppliers.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
            onChanged: (val) => setState(() => _selectedSupplier = val),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: 'note'.tr(),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _showProductPicker,
            icon: const Icon(Icons.add),
            label: Text('add_product'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    return ListView.builder(
      itemCount: _selectedItems.length,
      itemBuilder: (context, index) {
        final item = _selectedItems[index];
        return ListTile(
          title: Text(item.productName),
          subtitle: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: () => setState(() {
                  if (item.quantity > 1) {
                    _selectedItems[index] = PurchaseOrderItem(
                      productId: item.productId,
                      productName: item.productName,
                      quantity: item.quantity - 1,
                      costPrice: item.costPrice,
                    );
                  }
                }),
              ),
              Text('${item.quantity}'),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => setState(() {
                  _selectedItems[index] = PurchaseOrderItem(
                    productId: item.productId,
                    productName: item.productName,
                    quantity: item.quantity + 1,
                    costPrice: item.costPrice,
                  );
                }),
              ),
            ],
          ),
          trailing: Text('${item.costPrice * item.quantity}'),
        );
      },
    );
  }

  Widget _buildFooter() {
    final total = _selectedItems.fold(0.0, (sum, item) => sum + (item.costPrice * item.quantity));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('total'.tr() + ': $total', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ElevatedButton(onPressed: _savePO, child: Text('save_po'.tr())),
        ],
      ),
    );
  }

  void _showProductPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView.builder(
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final p = _products[index];
          return ListTile(
            title: Text(p.name),
            subtitle: Text('cost'.tr() + ': ${p.costPrice}'),
            onTap: () {
              _addItem(p);
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }
}
