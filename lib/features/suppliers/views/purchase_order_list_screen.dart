import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/app_feature.dart';
import '../../../core/models/purchase_order.dart';
import '../../../core/models/supplier.dart';
import '../../../core/routes/routes.dart';
import '../../../core/services/procurement_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/services/supplier_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/desktop_tokens.dart';
import '../../../core/widgets/desktop/desktop_scaffold.dart';
import '../../../core/widgets/desktop/desktop_table.dart';
import '../../../core/widgets/desktop/page_header.dart';
import '../../../core/widgets/desktop/responsive.dart';
import '../../../core/widgets/desktop/stat_card.dart';
import '../../../core/widgets/subscription_dialog.dart';
import 'create_purchase_order_screen.dart';

class PurchaseOrderListScreen extends StatefulWidget {
  const PurchaseOrderListScreen({super.key});

  @override
  State<PurchaseOrderListScreen> createState() => _PurchaseOrderListScreenState();
}

class _PurchaseOrderListScreenState extends State<PurchaseOrderListScreen> {
  final _procurementService = sl<ProcurementService>();
  final _supplierService = sl<SupplierService>();
  List<PurchaseOrder> _purchaseOrders = [];
  List<Supplier> _suppliers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPurchaseOrders();
    _loadSuppliers();
  }

  Future<void> _loadPurchaseOrders() async {
    setState(() => _isLoading = true);
    final pos = await _procurementService.getPurchaseOrders();
    setState(() {
      _purchaseOrders = pos;
      _isLoading = false;
    });
  }

  // Presentation-only: resolves supplier names for the desktop table.
  Future<void> _loadSuppliers() async {
    try {
      final suppliers = await _supplierService.getAllSuppliers();
      if (mounted) {
        setState(() => _suppliers = suppliers);
      }
    } catch (_) {
      // Keep the page functional even if supplier lookup fails.
    }
  }

  Future<void> _openCreatePO() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreatePurchaseOrderScreen()),
    );
    if (result == true) {
      _loadPurchaseOrders();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopScaffold(
      activeNavIndex: -1,
      title: 'purchase_orders'.tr(),
      showMobileBottomNav: false,
      actions: [
        IconButton(
          onPressed: _loadPurchaseOrders,
          icon: const Icon(Icons.refresh),
        ),
      ],
      onNavigate: _onNavTap,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatePurchaseOrderScreen()),
          );
          if (result == true) {
            _loadPurchaseOrders();
          }
        },
        label: Text('create_po'.tr()),
        icon: const Icon(Icons.add_shopping_cart),
      ),
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
        : _purchaseOrders.isEmpty
            ? _buildEmptyState()
            : _buildPOList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 80, color: AppColors.of(context).textLight),
          const SizedBox(height: 16),
          Text(
            'no_purchase_orders'.tr(),
            style: TextStyle(fontSize: 18, color: AppColors.of(context).textLight),
          ),
        ],
      ),
    );
  }

  Widget _buildPOList() {
    return ListView.builder(
      itemCount: _purchaseOrders.length,
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) {
        final po = _purchaseOrders[index];
        return _buildPOCard(po);
      },
    );
  }

  Widget _buildPOCard(PurchaseOrder po) {
    Color statusColor;
    IconData statusIcon;
    switch (po.status) {
      case PurchaseOrderStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        break;
      case PurchaseOrderStatus.received:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case PurchaseOrderStatus.cancelled:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        title: Text(
          'PO #${po.id}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            Text(DateFormat('yyyy/MM/dd').format(po.date)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 12, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    po.status.name.tr(),
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        trailing: Text(
          '${NumberFormat.currency(symbol: '', decimalDigits: 0).format(po.totalAmount)} YER',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...po.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${item.productName} x${item.quantity}'),
                      Text('${NumberFormat.currency(symbol: '', decimalDigits: 0).format(item.costPrice * item.quantity)}'),
                    ],
                  ),
                )),
                const Divider(),
                if (po.status == PurchaseOrderStatus.pending)
                  ElevatedButton.icon(
                    onPressed: () => _showReceiveDialog(po),
                    icon: const Icon(Icons.download),
                    label: Text('receive_stock'.tr()),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showReceiveDialog(PurchaseOrder po) async {
    final amountController = TextEditingController(text: '0');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('receive_po'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('receive_po_confirm'.tr()),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'paid_amount'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
          ElevatedButton(
            onPressed: () async {
              final paid = double.tryParse(amountController.text) ?? 0;
              await _procurementService.receivePurchaseOrder(po.id!, paidAmount: paid);
              if (mounted) {
                Navigator.pop(context);
                _loadPurchaseOrders();
              }
            },
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Desktop UI (presentation-only). All values come from the
  // existing state and all actions reuse the existing callbacks.
  // ──────────────────────────────────────────────────────────────

  Widget _buildDesktopBody() {
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
                title: 'purchase_orders'.tr(),
                subtitle: '${_purchaseOrders.length}',
                actions: [
                  FilledButton.icon(
                    onPressed: _openCreatePO,
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                    label: Text('create_po'.tr()),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              _buildDesktopStats(),
              const SizedBox(height: AppSpace.lg),
              _buildDesktopTable(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopStats() {
    final total = _purchaseOrders.length;
    final pending = _purchaseOrders
        .where((po) => po.status == PurchaseOrderStatus.pending)
        .length;
    final totalAmount =
        _purchaseOrders.fold<double>(0, (sum, po) => sum + po.totalAmount);
    final fmt = NumberFormat.currency(symbol: '', decimalDigits: 0);
    return ResponsiveGrid(
      columns: 3,
      children: [
        StatCard(
          title: 'total'.tr(),
          value: '$total',
          icon: Icons.receipt_long_outlined,
          color: AppColors.primary,
        ),
        StatCard(
          title: 'pending'.tr(),
          value: '$pending',
          icon: Icons.hourglass_empty,
          color: AppColors.warning,
        ),
        StatCard(
          title: 'total_amount'.tr(),
          value: '${fmt.format(totalAmount)} YER',
          icon: Icons.account_balance_wallet_outlined,
          color: AppColors.success,
        ),
      ],
    );
  }

  Widget _buildDesktopTable() {
    final fmt = NumberFormat.currency(symbol: '', decimalDigits: 0);
    final rows = _purchaseOrders.map((po) {
      return <Widget>[
        Text(
          'PO #${po.id}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        Text(
          _supplierName(po.supplierId),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
        Text(
          DateFormat('yyyy/MM/dd').format(po.date),
          style: const TextStyle(fontSize: 12),
        ),
        _buildStatusCell(po),
        Text(
          '${fmt.format(po.totalAmount)} YER',
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        _buildActionsCell(po),
      ];
    }).toList();
    return DesktopTable(
      headers: [
        'invoice'.tr(),
        'supplier_name'.tr(),
        'date'.tr(),
        'status'.tr(),
        'total_amount'.tr(),
        '',
      ],
      flexes: const [2, 3, 2, 2, 2, 2],
      rows: rows,
      emptyMessage: 'no_purchase_orders'.tr(),
      maxHeight: 560,
    );
  }

  String _supplierName(int supplierId) {
    for (final supplier in _suppliers) {
      if (supplier.id == supplierId) return supplier.name;
    }
    return '${'supplier_name'.tr()} #$supplierId';
  }

  Widget _buildStatusCell(PurchaseOrder po) {
    Color statusColor;
    IconData statusIcon;
    switch (po.status) {
      case PurchaseOrderStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        break;
      case PurchaseOrderStatus.received:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case PurchaseOrderStatus.cancelled:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(statusIcon, size: 14, color: statusColor),
        const SizedBox(width: AppSpace.xs),
        Text(
          po.status.name.tr(),
          style: TextStyle(
            fontSize: 12,
            color: statusColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildActionsCell(PurchaseOrder po) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (po.status == PurchaseOrderStatus.pending)
          FilledButton.icon(
            onPressed: () => _showReceiveDialog(po),
            icon: const Icon(Icons.download, size: 15),
            label: Text('receive_stock'.tr()),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(width: AppSpace.xs),
        IconButton(
          tooltip: 'view_details'.tr(),
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          onPressed: () => _showDetailsDialog(po),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  void _showDetailsDialog(PurchaseOrder po) {
    final fmt = NumberFormat.currency(symbol: '', decimalDigits: 0);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('PO #${po.id}'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...po.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${item.productName} x${item.quantity}'),
                      Text(fmt.format(item.costPrice * item.quantity)),
                    ],
                  ),
                )),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'total_amount'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${fmt.format(po.totalAmount)} YER',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('back'.tr()),
          ),
        ],
      ),
    );
  }
}
