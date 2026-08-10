import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/app_feature.dart';
import '../../../core/models/supplier.dart';
import '../../../core/models/supplier_transaction.dart';
import '../../../core/models/supplier_transaction_item.dart';
import '../../../core/routes/routes.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/services/supplier_service.dart';
import '../../../core/services/supplier_transaction_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/desktop_tokens.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/widgets/desktop/desktop_scaffold.dart';
import '../../../core/widgets/desktop/desktop_table.dart';
import '../../../core/widgets/desktop/page_header.dart';
import '../../../core/widgets/subscription_dialog.dart';

class SupplierReturnScreen extends StatefulWidget {
  const SupplierReturnScreen({super.key});

  @override
  State<SupplierReturnScreen> createState() => _SupplierReturnScreenState();
}

class _SupplierReturnScreenState extends State<SupplierReturnScreen> {
  final _supplierService = sl<SupplierService>();
  final _supplierTxService = sl<SupplierTransactionService>();

  List<Supplier> _suppliers = [];
  Supplier? _selectedSupplier;
  List<SupplierTransaction> _purchases = [];
  SupplierTransaction? _selectedPurchase;
  List<SupplierTransactionItem> _originalItems = [];
  final Map<int, int> _returnQuantities = {};
  final Map<int, bool> _selectedItems = {};
  final _reasonController = TextEditingController();
  bool _isLoadingSuppliers = true;
  bool _isLoadingPurchases = false;
  bool _isProcessing = false;
  bool _showSupplierSelection = true;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    setState(() => _isLoadingSuppliers = true);
    final suppliers = await _supplierService.getAllSuppliers();
    if (mounted) {
      setState(() {
        _suppliers = suppliers;
        _isLoadingSuppliers = false;
      });
    }
  }

  Future<void> _loadSupplierPurchases(Supplier supplier) async {
    setState(() {
      _isLoadingPurchases = true;
      _selectedSupplier = supplier;
      _selectedPurchase = null;
      _originalItems = [];
      _returnQuantities.clear();
      _selectedItems.clear();
      _showSupplierSelection = false;
    });
    final transactions = await _supplierTxService.getTransactionsBySupplier(supplier.id!);
    if (mounted) {
      setState(() {
        _purchases = transactions
            .where((t) => t.type == SupplierTransactionType.purchase && t.items.isNotEmpty && !t.isVoid)
            .toList();
        _isLoadingPurchases = false;
      });
    }
  }

  void _selectPurchase(SupplierTransaction purchase) {
    setState(() {
      _selectedPurchase = purchase;
      _originalItems = List.from(purchase.items);
      _returnQuantities.clear();
      _selectedItems.clear();
      for (var item in _originalItems) {
        _selectedItems[item.productId] = false;
        _returnQuantities[item.productId] = 0;
      }
    });
  }

  double get _totalReturnAmount {
    double total = 0;
    for (var item in _originalItems) {
      if (_selectedItems[item.productId] == true) {
        final qty = _returnQuantities[item.productId] ?? 0;
        total += item.costPrice * qty;
      }
    }
    return total;
  }

  Future<void> _processReturn() async {
    if (_selectedPurchase == null || _totalReturnAmount <= 0) return;

    setState(() => _isProcessing = true);

    try {
      final itemsToReturn = <SupplierTransactionItem>[];
      for (var item in _originalItems) {
        if (_selectedItems[item.productId] == true) {
          final qty = _returnQuantities[item.productId] ?? 0;
          if (qty > 0) {
            itemsToReturn.add(SupplierTransactionItem(
              productId: item.productId,
              productName: item.productName,
              quantity: qty,
              costPrice: item.costPrice,
              currency: item.currency,
            ));
          }
        }
      }

      await _supplierTxService.processSupplierReturn(
        supplierId: _selectedSupplier!.id!,
        itemsToReturn: itemsToReturn,
        note: _reasonController.text,
        returnReason: _reasonController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('return_processed'.tr())),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_occurred'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopScaffold(
      activeNavIndex: -1,
      title: 'supplier_return'.tr(),
      showMobileBottomNav: false,
      actions: [
        if (!_showSupplierSelection && _selectedSupplier != null)
          TextButton(
            onPressed: () {
              setState(() {
                _showSupplierSelection = true;
                _selectedPurchase = null;
              });
            },
            child: Text('change'.tr()),
          ),
      ],
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
    return _isLoadingSuppliers
        ? const Center(child: CircularProgressIndicator())
        : _showSupplierSelection
            ? _buildSupplierSelection()
            : _isLoadingPurchases
                ? const Center(child: CircularProgressIndicator())
                : _selectedPurchase == null
                    ? _buildPurchaseSelection()
                    : _buildReturnForm();
  }

  Widget _buildSupplierSelection() {
    return ListView.builder(
      padding: EdgeInsets.all(20.w),
      itemCount: _suppliers.length,
      itemBuilder: (context, index) {
        final supplier = _suppliers[index];
        return Card(
          margin: EdgeInsets.only(bottom: 8.h),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Icon(Icons.business, color: AppColors.primary),
            ),
            title: Text(supplier.name),
            subtitle: Text(supplier.phone),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => _loadSupplierPurchases(supplier),
          ),
        );
      },
    );
  }

  Widget _buildPurchaseSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(20.w),
          child: Text(
            '${'supplier_name'.tr()}: ${_selectedSupplier!.name}',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: _purchases.isEmpty
              ? Center(child: Text('no_purchases_for_return'.tr()))
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  itemCount: _purchases.length,
                  itemBuilder: (context, index) {
                    final purchase = _purchases[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 8.h),
                      child: ListTile(
                        title: Text('purchase'.tr()),
                        subtitle: Text(
                          '${DateFormat('yyyy-MM-dd').format(purchase.date)} | ${CurrencyHelper.getFormatter(purchase.currency).format(purchase.amount)}',
                        ),
                        trailing: Text(
                          '${purchase.items.length} ${'items'.tr()}',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        onTap: () => _selectPurchase(purchase),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildReturnForm() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16.w),
          color: AppColors.primary.withOpacity(0.05),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${'supplier_name'.tr()}: ${_selectedSupplier!.name}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${'purchase'.tr()} - ${DateFormat('yyyy-MM-dd').format(_selectedPurchase!.date)}',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedPurchase = null),
                child: Text('back'.tr()),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(20.w),
            itemCount: _originalItems.length + 2,
            itemBuilder: (context, index) {
              if (index == _originalItems.length) {
                return _buildReasonSection();
              }
              if (index == _originalItems.length + 1) {
                return SizedBox(height: 100.h);
              }
              return _buildReturnItemCard(_originalItems[index]);
            },
          ),
        ),
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildReturnItemCard(SupplierTransactionItem item) {
    final isSelected = _selectedItems[item.productId] ?? false;
    final returnQty = _returnQuantities[item.productId] ?? 0;

    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (v) {
                    setState(() {
                      _selectedItems[item.productId] = v ?? false;
                      if (v == true && returnQty == 0) {
                        _returnQuantities[item.productId] = item.quantity;
                      } else if (v == false) {
                        _returnQuantities[item.productId] = 0;
                      }
                    });
                  },
                ),
                Expanded(
                  child: Text(item.productName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                ),
              ],
            ),
            if (isSelected) ...[
              SizedBox(height: 8.h),
              Padding(
                padding: EdgeInsets.only(left: 40.w),
                child: Row(
                  children: [
                    Text('${'quantity'.tr()}: ', style: TextStyle(color: AppColors.textSecondary)),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                      onPressed: returnQty > 1
                          ? () => setState(() => _returnQuantities[item.productId] = returnQty - 1)
                          : null,
                    ),
                    Text('$returnQty', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      onPressed: returnQty < item.quantity
                          ? () => setState(() => _returnQuantities[item.productId] = returnQty + 1)
                          : null,
                    ),
                    const Spacer(),
                    Text(
                      '${CurrencyHelper.getFormatter(item.currency).format(item.costPrice * returnQty)}',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReasonSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16.h),
        Text('return_reason'.tr(), style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
        SizedBox(height: 8.h),
        TextField(
          controller: _reasonController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'return_reason_hint'.tr(),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final hasItems = _selectedItems.values.any((v) => v);
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${'total_return'.tr()}: ${CurrencyHelper.getFormatter('YER').format(_totalReturnAmount)}',
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: (!hasItems || _totalReturnAmount <= 0 || _isProcessing) ? null : _processReturn,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: _isProcessing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('process_return'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Desktop UI (presentation-only). All values come from the
  // existing state/getters and all actions reuse the existing
  // callbacks unchanged.
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
                title: 'supplier_return'.tr(),
                subtitle: _desktopSubtitle(),
              ),
              const SizedBox(height: AppSpace.lg),
              ..._buildDesktopStep(),
            ],
          ),
        ),
      ),
    );
  }

  String? _desktopSubtitle() {
    if (_showSupplierSelection) return 'suppliers'.tr();
    if (_selectedSupplier == null) return null;
    return _selectedPurchase == null
        ? '${'supplier_name'.tr()}: ${_selectedSupplier!.name}'
        : '${'supplier_name'.tr()}: ${_selectedSupplier!.name} - ${'purchase'.tr()}';
  }

  List<Widget> _buildDesktopStep() {
    if (_isLoadingSuppliers || _isLoadingPurchases) {
      return const [
        SizedBox(
          height: 240,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_showSupplierSelection) return [_buildDesktopSupplierSelection()];
    if (_selectedPurchase == null) return [_buildDesktopPurchaseSelection()];
    return _buildDesktopReturnForm();
  }

  Widget _buildDesktopSupplierSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_suppliers.isEmpty)
          SizedBox(
            height: 160,
            child: Center(child: Text('no_suppliers'.tr())),
          )
        else
          DesktopTable(
            headers: ['supplier_name'.tr(), 'phone_number'.tr(), ''],
            flexes: const [4, 3, 1],
            maxHeight: 520,
            rows: [
              for (final supplier in _suppliers)
                [
                  Text(
                    supplier.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(supplier.phone, style: const TextStyle(fontSize: 12)),
                  IconButton(
                    tooltip: 'view'.tr(),
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _loadSupplierPurchases(supplier),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
            ],
          ),
      ],
    );
  }

  Widget _buildDesktopPurchaseSelection() {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${'supplier_name'.tr()}: ${_selectedSupplier!.name}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpace.md),
        if (_purchases.isEmpty)
          SizedBox(
            height: 200,
            child: Center(child: Text('no_purchases_for_return'.tr())),
          )
        else
          DesktopTable(
            headers: [
              'purchase'.tr(),
              'date'.tr(),
              'total_amount'.tr(),
              'items'.tr(),
              '',
            ],
            flexes: const [3, 2, 2, 1, 1],
            maxHeight: 520,
            rows: [
              for (final purchase in _purchases)
                [
                  Text(
                    '${'purchase'.tr()} #${purchase.id}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    DateFormat('yyyy-MM-dd').format(purchase.date),
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    CurrencyHelper.getFormatter(purchase.currency)
                        .format(purchase.amount),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${purchase.items.length} ${'items'.tr()}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  IconButton(
                    tooltip: 'view'.tr(),
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _selectPurchase(purchase),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
            ],
          ),
      ],
    );
  }

  List<Widget> _buildDesktopReturnForm() {
    return [
      LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= AppBreakpoints.desktop;
          final itemsPanel = _buildDesktopReturnItemsPanel();
          final summaryPanel = _buildDesktopReturnSummaryPanel();
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: itemsPanel),
                const SizedBox(width: AppSpace.lg),
                Expanded(flex: 5, child: summaryPanel),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              itemsPanel,
              const SizedBox(height: AppSpace.lg),
              summaryPanel,
            ],
          );
        },
      ),
    ];
  }

  Widget _buildDesktopReturnItemsPanel() {
    final rows = _originalItems.map((item) {
      final isSelected = _selectedItems[item.productId] ?? false;
      final returnQty = _returnQuantities[item.productId] ?? 0;
      return <Widget>[
        Checkbox(
          value: isSelected,
          onChanged: (v) {
            setState(() {
              _selectedItems[item.productId] = v ?? false;
              if (v == true && returnQty == 0) {
                _returnQuantities[item.productId] = item.quantity;
              } else if (v == false) {
                _returnQuantities[item.productId] = 0;
              }
            });
          },
        ),
        Text(
          item.productName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'remove'.tr(),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.remove_circle_outline,
                size: 18,
                color: AppColors.error,
              ),
              onPressed: (isSelected && returnQty > 1)
                  ? () => setState(
                      () => _returnQuantities[item.productId] = returnQty - 1,
                    )
                  : null,
            ),
            Text(
              '$returnQty',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            IconButton(
              tooltip: 'add'.tr(),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.add_circle_outline,
                size: 18,
                color: AppColors.success,
              ),
              onPressed: (isSelected && returnQty < item.quantity)
                  ? () => setState(
                      () => _returnQuantities[item.productId] = returnQty + 1,
                    )
                  : null,
            ),
          ],
        ),
        Text(
          CurrencyHelper.getFormatter(item.currency).format(item.costPrice * returnQty),
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ];
    }).toList();
    return DesktopTable(
      headers: ['', 'product_name'.tr(), 'quantity'.tr(), 'total'.tr()],
      flexes: const [1, 4, 2, 2],
      rows: rows,
      maxHeight: 420,
    );
  }

  Widget _buildDesktopReturnSummaryPanel() {
    final colors = AppColors.of(context);
    final hasItems = _selectedItems.values.any((v) => v);
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
              Expanded(
                child: Text(
                  '${'supplier_name'.tr()}: ${_selectedSupplier!.name}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedPurchase = null),
                child: Text('back'.tr()),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            '${'purchase'.tr()} - ${DateFormat('yyyy-MM-dd').format(_selectedPurchase!.date)}',
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
          const Divider(height: AppSpace.lg),
          Text(
            'return_reason'.tr(),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpace.xs),
          TextField(
            controller: _reasonController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'return_reason_hint'.tr(),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
          ),
          const Divider(height: AppSpace.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'total_return'.tr(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                CurrencyHelper.getFormatter('YER').format(_totalReturnAmount),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: (!hasItems || _totalReturnAmount <= 0 || _isProcessing)
                  ? null
                  : _processReturn,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              icon: _isProcessing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 20),
              label: Text(
                'process_return'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
