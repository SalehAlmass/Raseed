import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/app_transaction.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/transaction_item.dart';
import '../../../core/services/customer_service.dart';
import '../../../core/services/transaction_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/currency_helper.dart';

class SalesReturnScreen extends StatefulWidget {
  const SalesReturnScreen({super.key});

  @override
  State<SalesReturnScreen> createState() => _SalesReturnScreenState();
}

class _SalesReturnScreenState extends State<SalesReturnScreen> {
  final _customerService = sl<CustomerService>();
  final _transactionService = sl<TransactionService>();

  List<Customer> _customers = [];
  Customer? _selectedCustomer;
  List<AppTransaction> _sales = [];
  AppTransaction? _selectedSale;
  List<TransactionItem> _originalItems = [];
  final Map<int, int> _returnQuantities = {};
  final Map<int, bool> _selectedItems = {};
  final _reasonController = TextEditingController();
  String _condition = 'good';
  bool _isLoadingCustomers = true;
  bool _isLoadingSales = false;
  bool _isProcessing = false;
  bool _showCustomerSelection = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoadingCustomers = true);
    final customers = await _customerService.getAllCustomers();
    if (mounted) {
      setState(() {
        _customers = customers;
        _isLoadingCustomers = false;
      });
    }
  }

  Future<void> _loadCustomerSales(Customer customer) async {
    setState(() {
      _isLoadingSales = true;
      _selectedCustomer = customer;
      _selectedSale = null;
      _originalItems = [];
      _returnQuantities.clear();
      _selectedItems.clear();
      _showCustomerSelection = false;
    });
    final transactions = await _transactionService.getCustomerTransactions(customer.id!);
    if (mounted) {
      setState(() {
        _sales = transactions.where((t) => t.type == TransactionType.sale && t.items.isNotEmpty).toList();
        _isLoadingSales = false;
      });
    }
  }

  void _selectSale(AppTransaction sale) {
    setState(() {
      _selectedSale = sale;
      _originalItems = List.from(sale.items);
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
        total += item.price * qty;
      }
    }
    return total;
  }

  Future<void> _processReturn() async {
    if (_selectedSale == null || _totalReturnAmount <= 0) return;

    setState(() => _isProcessing = true);

    try {
      final itemsToRefund = <TransactionItem>[];
      for (var item in _originalItems) {
        if (_selectedItems[item.productId] == true) {
          final qty = _returnQuantities[item.productId] ?? 0;
          if (qty > 0) {
            itemsToRefund.add(TransactionItem(
              productId: item.productId,
              productName: item.productName,
              quantity: qty,
              price: item.price,
              costPrice: item.costPrice,
              currency: item.currency,
            ));
          }
        }
      }

      await _transactionService.processRefund(
        originalTransaction: _selectedSale!,
        itemsToRefund: itemsToRefund,
        customerId: _selectedCustomer!.id,
        note: _reasonController.text,
        returnReason: _reasonController.text,
        returnCondition: _condition,
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
        title: Text('sales_return'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        actions: [
          if (!_showCustomerSelection && _selectedCustomer != null)
            TextButton(
              onPressed: () {
                setState(() {
                  _showCustomerSelection = true;
                  _selectedSale = null;
                });
              },
              child: Text('change'.tr()),
            ),
        ],
      ),
      body: _isLoadingCustomers
          ? const Center(child: CircularProgressIndicator())
          : _showCustomerSelection
              ? _buildCustomerSelection()
              : _isLoadingSales
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedSale == null
                      ? _buildSaleSelection()
                      : _buildReturnForm(),
    );
  }

  Widget _buildCustomerSelection() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(20.w),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'search_customer'.tr(),
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (query) {
              setState(() {});
            },
          ),
        ),
        Expanded(
          child: _customers.isEmpty
              ? Center(child: Text('no_customers'.tr()))
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  itemCount: _customers.length,
                  itemBuilder: (context, index) {
                    final customer = _customers[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 8.h),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: Icon(Icons.person, color: AppColors.primary),
                        ),
                        title: Text(customer.name),
                        subtitle: Text(customer.phone),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => _loadCustomerSales(customer),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSaleSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(20.w),
          child: Text(
            '${'customer'.tr()}: ${_selectedCustomer!.name}',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: _sales.isEmpty
              ? Center(child: Text('no_sales_for_return'.tr()))
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  itemCount: _sales.length,
                  itemBuilder: (context, index) {
                    final sale = _sales[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 8.h),
                      child: ListTile(
                        title: Text('${'invoice'.tr()} #${sale.id}'),
                        subtitle: Text(
                          '${DateFormat('yyyy-MM-dd').format(sale.date)} | ${CurrencyHelper.getFormatter(sale.currency).format(sale.amount)}',
                        ),
                        trailing: Text(
                          '${sale.items.length} ${'items'.tr()}',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        onTap: () => _selectSale(sale),
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
                      '${'customer'.tr()}: ${_selectedCustomer!.name}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${'invoice'.tr()} #${_selectedSale!.id} - ${DateFormat('yyyy-MM-dd').format(_selectedSale!.date)}',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedSale = null),
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

  Widget _buildReturnItemCard(TransactionItem item) {
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
                      '${CurrencyHelper.getFormatter(item.currency).format(item.price * returnQty)}',
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
        SizedBox(height: 12.h),
        Text('return_condition'.tr(), style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
        SizedBox(height: 8.h),
        Row(
          children: [
            _buildConditionChip('good', Icons.check_circle, Colors.green),
            SizedBox(width: 8.w),
            _buildConditionChip('fair', Icons.check_circle_outline, Colors.orange),
            SizedBox(width: 8.w),
            _buildConditionChip('damaged', Icons.cancel, Colors.red),
          ],
        ),
      ],
    );
  }

  Widget _buildConditionChip(String value, IconData icon, Color color) {
    final isSelected = _condition == value;
    return GestureDetector(
      onTap: () => setState(() => _condition = value),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: isSelected ? color : Colors.grey.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? color : Colors.grey),
            SizedBox(width: 4.w),
            Text(
              value == 'good' ? (context.locale.languageCode == 'ar' ? 'سليم' : 'Good') :
              value == 'fair' ? (context.locale.languageCode == 'ar' ? 'مقبول' : 'Fair') :
              (context.locale.languageCode == 'ar' ? 'تالف' : 'Damaged'),
              style: TextStyle(
                color: isSelected ? color : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
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
