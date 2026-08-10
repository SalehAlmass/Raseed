import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/app_feature.dart';
import '../../../core/models/app_transaction.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/transaction_item.dart';
import '../../../core/routes/routes.dart';
import '../../../core/services/customer_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/services/transaction_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/desktop_tokens.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/widgets/desktop/desktop_scaffold.dart';
import '../../../core/widgets/desktop/desktop_table.dart';
import '../../../core/widgets/desktop/page_header.dart';
import '../../../core/widgets/subscription_dialog.dart';

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
    return DesktopScaffold(
      activeNavIndex: -1,
      title: 'sales_return'.tr(),
      showMobileBottomNav: false,
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
    return _isLoadingCustomers
        ? const Center(child: CircularProgressIndicator())
        : _showCustomerSelection
            ? _buildCustomerSelection()
            : _isLoadingSales
                ? const Center(child: CircularProgressIndicator())
                : _selectedSale == null
                    ? _buildSaleSelection()
                    : _buildReturnForm();
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
                title: 'sales_return'.tr(),
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
    if (_showCustomerSelection) return 'select_customer'.tr();
    if (_selectedCustomer == null) return null;
    return _selectedSale == null
        ? '${'customer'.tr()}: ${_selectedCustomer!.name}'
        : '${'customer'.tr()}: ${_selectedCustomer!.name} - ${'invoice'.tr()} #${_selectedSale!.id}';
  }

  List<Widget> _buildDesktopStep() {
    if (_isLoadingCustomers || _isLoadingSales) {
      return const [
        SizedBox(
          height: 240,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_showCustomerSelection) return [_buildDesktopCustomerSelection()];
    if (_selectedSale == null) return [_buildDesktopSaleSelection()];
    return _buildDesktopReturnForm();
  }

  Widget _buildDesktopCustomerSelection() {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 420,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'search_customer'.tr(),
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              filled: true,
              fillColor: colors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (query) {
              setState(() {});
            },
          ),
        ),
        const SizedBox(height: AppSpace.md),
        if (_customers.isEmpty)
          SizedBox(
            height: 160,
            child: Center(child: Text('no_customers'.tr())),
          )
        else
          DesktopTable(
            headers: ['name'.tr(), 'phone_number'.tr(), ''],
            flexes: const [4, 3, 1],
            maxHeight: 520,
            rows: [
              for (final customer in _customers)
                [
                  Text(
                    customer.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(customer.phone, style: const TextStyle(fontSize: 12)),
                  IconButton(
                    tooltip: 'view'.tr(),
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _loadCustomerSales(customer),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
            ],
          ),
      ],
    );
  }

  Widget _buildDesktopSaleSelection() {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${'customer'.tr()}: ${_selectedCustomer!.name}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpace.md),
        if (_sales.isEmpty)
          SizedBox(
            height: 200,
            child: Center(child: Text('no_sales_for_return'.tr())),
          )
        else
          DesktopTable(
            headers: [
              'invoice'.tr(),
              'date'.tr(),
              'total_amount'.tr(),
              'items'.tr(),
              '',
            ],
            flexes: const [3, 2, 2, 1, 1],
            maxHeight: 520,
            rows: [
              for (final sale in _sales)
                [
                  Text(
                    '${'invoice'.tr()} #${sale.id}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    DateFormat('yyyy-MM-dd').format(sale.date),
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    CurrencyHelper.getFormatter(sale.currency).format(sale.amount),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${sale.items.length} ${'items'.tr()}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  IconButton(
                    tooltip: 'view'.tr(),
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _selectSale(sale),
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
          CurrencyHelper.getFormatter(item.currency).format(item.price * returnQty),
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
                  '${'customer'.tr()}: ${_selectedCustomer!.name}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedSale = null),
                child: Text('back'.tr()),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            '${'invoice'.tr()} #${_selectedSale!.id} - ${DateFormat('yyyy-MM-dd').format(_selectedSale!.date)}',
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
          const SizedBox(height: AppSpace.md),
          Text(
            'return_condition'.tr(),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpace.xs),
          Wrap(
            spacing: AppSpace.xs,
            children: [
              _buildDesktopConditionChip('good', Icons.check_circle, Colors.green),
              _buildDesktopConditionChip('fair', Icons.check_circle_outline, Colors.orange),
              _buildDesktopConditionChip('damaged', Icons.cancel, Colors.red),
            ],
          ),
          const Divider(height: AppSpace.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'total_return'.tr(),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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

  Widget _buildDesktopConditionChip(String value, IconData icon, Color color) {
    final isSelected = _condition == value;
    return GestureDetector(
      onTap: () => setState(() => _condition = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isSelected
                ? color
                : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? color : Colors.grey),
            const SizedBox(width: 4),
            Text(
              value == 'good'
                  ? (context.locale.languageCode == 'ar' ? 'سليم' : 'Good')
                  : value == 'fair'
                      ? (context.locale.languageCode == 'ar' ? 'مقبول' : 'Fair')
                      : (context.locale.languageCode == 'ar' ? 'تالف' : 'Damaged'),
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
}
