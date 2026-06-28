import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/supplier.dart';
import '../../../core/models/supplier_transaction.dart';
import '../../../core/models/supplier_transaction_item.dart';
import '../../../core/services/supplier_service.dart';
import '../../../core/services/supplier_transaction_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/currency_helper.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text('supplier_return'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
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
      ),
      body: _isLoadingSuppliers
          ? const Center(child: CircularProgressIndicator())
          : _showSupplierSelection
              ? _buildSupplierSelection()
              : _isLoadingPurchases
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedPurchase == null
                      ? _buildPurchaseSelection()
                      : _buildReturnForm(),
    );
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
}
