import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/app_feature.dart';
import '../../../core/models/purchase_order.dart';
import '../../../core/models/supplier.dart';
import '../../../core/models/product.dart';
import '../../../core/routes/routes.dart';
import '../../../core/services/supplier_service.dart';
import '../../../core/services/product_service.dart';
import '../../../core/services/procurement_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/desktop_tokens.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/widgets/desktop/desktop_scaffold.dart';
import '../../../core/widgets/desktop/desktop_table.dart';
import '../../../core/widgets/desktop/page_header.dart';
import '../../../core/widgets/subscription_dialog.dart';

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
    return DesktopScaffold(
      activeNavIndex: -1,
      title: 'create_po'.tr(),
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
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildItemsList()),
              _buildFooter(),
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
                title: 'create_po'.tr(),
                subtitle: _selectedSupplier?.name,
                actions: [
                  FilledButton.icon(
                    onPressed: _showDesktopProductPicker,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text('add_product'.tr()),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              if (_isLoading)
                const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide =
                        constraints.maxWidth >= AppBreakpoints.desktop;
                    final cart = _buildDesktopItemsTable(colors);
                    final summary = _buildDesktopSummary(colors);
                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: cart),
                          const SizedBox(width: AppSpace.lg),
                          Expanded(flex: 5, child: summary),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        cart,
                        const SizedBox(height: AppSpace.lg),
                        summary,
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopItemsTable(AppColorSet colors) {
    final rows = _selectedItems.map((item) {
      final index = _selectedItems.indexOf(item);
      return <Widget>[
        Text(
          item.productName,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'remove'.tr(),
              iconSize: 16,
              visualDensity: VisualDensity.compact,
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
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('${item.quantity}'),
            IconButton(
              tooltip: 'add'.tr(),
              iconSize: 16,
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() {
                _selectedItems[index] = PurchaseOrderItem(
                  productId: item.productId,
                  productName: item.productName,
                  quantity: item.quantity + 1,
                  costPrice: item.costPrice,
                );
              }),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        Text(
          CurrencyHelper.getFormatter('YER').format(item.costPrice),
          style: const TextStyle(fontSize: 12),
        ),
        Text(
          CurrencyHelper.getFormatter('YER').format(
            item.costPrice * item.quantity,
          ),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        IconButton(
          tooltip: 'delete'.tr(),
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          onPressed: () => setState(() => _selectedItems.removeAt(index)),
          icon: const Icon(Icons.delete_outline),
        ),
      ];
    }).toList();
    return DesktopTable(
      headers: [
        'product_name'.tr(),
        'quantity'.tr(),
        'cost'.tr(),
        'total'.tr(),
        '',
      ],
      flexes: const [4, 3, 2, 2, 1],
      rows: rows,
      emptyMessage: 'no_products'.tr(),
      maxHeight: 520,
    );
  }

  Widget _buildDesktopSummary(AppColorSet colors) {
    final total = _selectedItems.fold(
      0.0,
      (sum, item) => sum + (item.costPrice * item.quantity),
    );
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
          Text(
            'supplier'.tr(),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpace.xs),
          DropdownButtonFormField<Supplier>(
            value: _selectedSupplier,
            decoration: InputDecoration(
              labelText: 'supplier'.tr(),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            items: _suppliers
                .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                .toList(),
            onChanged: (val) => setState(() => _selectedSupplier = val),
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: 'note'.tr(),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'total'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Text(
                CurrencyHelper.getFormatter('YER').format(total),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const Divider(height: AppSpace.xl),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed:
                  (_selectedSupplier == null || _selectedItems.isEmpty)
                      ? null
                      : _savePO,
              icon: const Icon(Icons.check_circle_outline),
              label: Text('save_po'.tr()),
            ),
          ),
        ],
      ),
    );
  }

  void _showDesktopProductPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('add_product'.tr()),
        content: SizedBox(
          width: 520,
          height: 400,
          child: _products.isEmpty
              ? Center(child: Text('no_products'.tr()))
              : ListView.builder(
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final p = _products[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.inventory_2_outlined,
                          color: AppColors.primary),
                      title: Text(p.name),
                      subtitle: Text(
                        '${'cost'.tr()}: ${CurrencyHelper.getFormatter('YER').format(p.costPrice)}',
                      ),
                      onTap: () {
                        _addItem(p);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
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
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width >= 900 ? 760 : double.infinity,
      ),
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
