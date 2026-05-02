import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/purchase_order.dart';
import '../../../core/services/procurement_service.dart';
import 'create_purchase_order_screen.dart';

class PurchaseOrderListScreen extends StatefulWidget {
  const PurchaseOrderListScreen({super.key});

  @override
  State<PurchaseOrderListScreen> createState() => _PurchaseOrderListScreenState();
}

class _PurchaseOrderListScreenState extends State<PurchaseOrderListScreen> {
  final _procurementService = sl<ProcurementService>();
  List<PurchaseOrder> _purchaseOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPurchaseOrders();
  }

  Future<void> _loadPurchaseOrders() async {
    setState(() => _isLoading = true);
    final pos = await _procurementService.getPurchaseOrders();
    setState(() {
      _purchaseOrders = pos;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('purchase_orders'.tr()),
        actions: [
          IconButton(
            onPressed: _loadPurchaseOrders,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _purchaseOrders.isEmpty
              ? _buildEmptyState()
              : _buildPOList(),
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'no_purchase_orders'.tr(),
            style: const TextStyle(fontSize: 18, color: Colors.grey),
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
                color: statusColor.withOpacity(0.1),
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
}
