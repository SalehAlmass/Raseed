import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/app_feature.dart';
import '../../../core/models/supplier.dart';
import '../../../core/models/supplier_transaction.dart';
import '../../../core/models/product.dart';
import '../../../core/services/product_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/services/supplier_service.dart';
import '../../../core/services/supplier_transaction_service.dart';
import '../../reports/services/report_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/desktop_tokens.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/routes/routes.dart';
import '../../../core/widgets/desktop/desktop_scaffold.dart';
import '../../../core/widgets/desktop/desktop_table.dart';
import '../../../core/widgets/desktop/page_header.dart';
import '../../../core/widgets/desktop/responsive.dart';
import '../../../core/widgets/desktop/stat_card.dart';
import '../../../core/widgets/subscription_dialog.dart';
import 'supplier_purchase_history_screen.dart';

class SupplierDetailScreen extends StatefulWidget {
  final Supplier supplier;
  const SupplierDetailScreen({super.key, required this.supplier});

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  final SupplierService _supplierService = sl<SupplierService>();
  final SupplierTransactionService _transactionService = sl<SupplierTransactionService>();
  final ProductService _productService = sl<ProductService>();
  
  late Supplier _supplier;
  List<SupplierTransaction> _transactions = [];
  List<Product> _products = [];
  List<Map<String, dynamic>> _lowStockItems = [];
  Map<int, Map<String, dynamic>?> _lastPurchaseInfo = {};
  bool _isLoading = true;
  int _desktopTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _supplier = widget.supplier;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final updatedSupplier = await _supplierService.getSupplierById(_supplier.id!);
    final transactions = await _transactionService.getTransactionsBySupplier(_supplier.id!);
    final lowStock = await sl<ReportService>().getLowStockBySupplier(_supplier.id!);
    final products = await sl<ProductService>().getProductsBySupplier(_supplier.id!);
    
    Map<int, Map<String, dynamic>?> lastPurchaseInfo = {};
    for (var p in products) {
      lastPurchaseInfo[p.id!] = await _productService.getLastPurchaseInfo(p.id!, _supplier.id!);
    }
    
    setState(() {
      if (updatedSupplier != null) _supplier = updatedSupplier;
      _transactions = transactions;
      _lowStockItems = lowStock;
      _products = products;
      _lastPurchaseInfo = lastPurchaseInfo;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DesktopScaffold(
      activeNavIndex: -1,
      title: _supplier.name,
      extendBody: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.replay, color: Colors.orange),
          tooltip: 'supplier_return'.tr(),
          onPressed: () => Navigator.pushNamed(context, Routes.supplierReturn),
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
        : DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDebtCard(),
                        SizedBox(height: 20.h),
                        _buildActionButtons(),
                        if (_lowStockItems.isNotEmpty) ...[
                          SizedBox(height: 30.h),
                          _buildLowStockSection(),
                        ],
                        SizedBox(height: 30.h),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.of(context).surface,
                            borderRadius: BorderRadius.circular(15.r),
                          ),
                          child: TabBar(
                            labelColor: AppColors.primary,
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: AppColors.primary,
                            indicatorSize: TabBarIndicatorSize.label,
                            tabs: [
                              Tab(text: 'account_statement'.tr()),
                              Tab(text: 'products'.tr()),
                            ],
                          ),
                        ),
                        SizedBox(height: 20.h),
                        SizedBox(
                          height: 500.h, // Fixed height for tab content
                          child: TabBarView(
                            children: [
                              _buildTransactionList(),
                              _buildProductList(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
  }

  Widget _buildDesktopBody() {
    final colors = AppColors.of(context);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
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
                title: _supplier.name,
                subtitle: _supplier.company != null
                    ? '${_supplier.company} • ${_supplier.phone}'
                    : _supplier.phone,
                actions: [
                  FilledButton.icon(
                    onPressed: _showPaymentDialog,
                    icon: const Icon(Icons.payment, size: 18),
                    label: Text('pay_supplier'.tr()),
                  ),
                  const SizedBox(width: AppSpace.xs),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SupplierPurchaseHistoryScreen(
                              initialSupplier: _supplier,
                            ),
                      ),
                    ).then((_) => _loadData()),
                    icon: const Icon(Icons.history, size: 18),
                    label: Text('purchase_history'.tr()),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              _buildDesktopStats(colors),
              if (_lowStockItems.isNotEmpty) ...[
                const SizedBox(height: AppSpace.lg),
                _buildDesktopLowStockTable(colors),
              ],
              const SizedBox(height: AppSpace.lg),
              _buildDesktopTabSelector(),
              const SizedBox(height: AppSpace.md),
              if (_desktopTabIndex == 0)
                _buildDesktopTransactionsTable(colors)
              else
                _buildDesktopProductsTable(colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopStats(AppColorSet colors) {
    final purchasesCount = _transactions
        .where((t) => t.type == SupplierTransactionType.purchase)
        .length;
    return ResponsiveGrid(
      columns: 3,
      children: [
        StatCard(
          title: 'total_paid'.tr(),
          value: CurrencyHelper.getFormatter('YER')
              .format(_supplier.totalPaid),
          icon: Icons.payments_outlined,
          color: AppColors.success,
        ),
        StatCard(
          title: 'remaining'.tr(),
          value: CurrencyHelper.getFormatter('YER')
              .format(_supplier.totalDebt),
          icon: Icons.account_balance_wallet_outlined,
          color: AppColors.error,
        ),
        StatCard(
          title: 'purchase_history'.tr(),
          value: '$purchasesCount',
          icon: Icons.shopping_cart_outlined,
          color: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildDesktopLowStockTable(AppColorSet colors) {
    final rows = _lowStockItems.map((item) {
      return <Widget>[
        Text(
          item['name'],
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        Text('${item['stock_quantity']}', style: const TextStyle(fontSize: 12)),
        Text(
          '${item['reorder_level']}',
          style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.bold),
        ),
      ];
    }).toList();
    return DesktopTable(
      headers: [
        'product_name'.tr(),
        'stock_quantity'.tr(),
        'reorder_level'.tr(),
      ],
      flexes: const [4, 2, 2],
      rows: rows,
      emptyMessage: 'no_products'.tr(),
      maxHeight: 220,
    );
  }

  Widget _buildDesktopTabSelector() {
    final colors = AppColors.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: colors.border),
        ),
        child: SegmentedButton<int>(
          segments: [
            ButtonSegment(
              value: 0,
              icon: const Icon(Icons.receipt_long_outlined, size: 16),
              label: Text('account_statement'.tr()),
            ),
            ButtonSegment(
              value: 1,
              icon: const Icon(Icons.inventory_2_outlined, size: 16),
              label: Text('products'.tr()),
            ),
          ],
          selected: {_desktopTabIndex},
          onSelectionChanged: (selection) {
            setState(() => _desktopTabIndex = selection.first);
          },
          showSelectedIcon: false,
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            backgroundColor: WidgetStatePropertyAll(colors.surface),
            foregroundColor: WidgetStatePropertyAll(colors.textPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTransactionsTable(AppColorSet colors) {
    if (_transactions.isEmpty) {
      return DesktopTable(
        headers: [''],
        rows: const [],
        emptyMessage: 'no_transactions'.tr(),
        maxHeight: 320,
      );
    }
    final rows = _transactions.map((tx) {
      final isPurchase = tx.type == SupplierTransactionType.purchase;
      return <Widget>[
        Row(
          children: [
            Icon(
              isPurchase ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: isPurchase ? AppColors.error : AppColors.success,
            ),
            const SizedBox(width: AppSpace.xs),
            Text(
              isPurchase ? 'purchase'.tr() : 'payment'.tr(),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        Text(
          DateFormat('MMM dd, yyyy').format(tx.date),
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
        Text(
          CurrencyHelper.getFormatter(tx.currency).format(tx.amount),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isPurchase ? AppColors.error : AppColors.success,
          ),
        ),
        Row(
          children: [
            if (tx.isVoid)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  'voided'.tr(),
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (isPurchase)
              IconButton(
                tooltip: 'view'.tr(),
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                onPressed: () => _showPurchaseInvoice(tx),
                icon: const Icon(Icons.receipt_long_outlined),
              ),
            if (!tx.isVoid)
              IconButton(
                tooltip: 'delete'.tr(),
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                onPressed: () => _showVoidConfirmation(tx),
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
      ];
    }).toList();
    return DesktopTable(
      headers: [
        'type'.tr(),
        'date'.tr(),
        'amount'.tr(),
        '',
      ],
      flexes: const [3, 2, 2, 2],
      rows: rows,
      emptyMessage: 'no_transactions'.tr(),
      maxHeight: 520,
    );
  }

  Widget _buildDesktopProductsTable(AppColorSet colors) {
    if (_products.isEmpty) {
      return DesktopTable(
        headers: [''],
        rows: const [],
        emptyMessage: 'no_products'.tr(),
        maxHeight: 320,
      );
    }
    final rows = _products.map((product) {
      final lastPurchase = _lastPurchaseInfo[product.id];
      final hasPurchaseInfo = lastPurchase != null;
      final lastPrice = hasPurchaseInfo
          ? (lastPurchase!['cost_price'] as num).toDouble()
          : 0.0;
      return <Widget>[
        Text(
          product.name,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        Text(
          sl<ProductService>()
              .formatStock(product.stockQuantity, product.conversionFactor),
          style: const TextStyle(fontSize: 12),
        ),
        Text(
          hasPurchaseInfo
              ? '${CurrencyHelper.getFormatter('YER').format(lastPrice)}'
                  ' • ${DateFormat('yyyy/MM/dd').format(DateTime.parse(lastPurchase!['date'] as String))}'
              : '-',
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
        Text(
          CurrencyHelper.getFormatter(product.currency).format(product.price),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ];
    }).toList();
    return DesktopTable(
      headers: [
        'product_name'.tr(),
        'stock_quantity'.tr(),
        'last_purchase'.tr(),
        'selling_price'.tr(),
      ],
      flexes: const [4, 2, 3, 2],
      rows: rows,
      emptyMessage: 'no_products'.tr(),
      maxHeight: 520,
    );
  }

  Widget _buildDebtCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_supplier.rating > 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10.r)),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                      SizedBox(width: 4.w),
                      Text(_supplier.rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              else
                const SizedBox.shrink(),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                onPressed: () => _showEditRatingDialog(),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    'total_paid'.tr(),
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13.sp),
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    CurrencyHelper.getFormatter('YER').format(_supplier.totalPaid),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(height: 40.h, width: 1, color: Colors.white24),
              Column(
                children: [
                  Text(
                    'remaining'.tr(),
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13.sp),
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    CurrencyHelper.getFormatter('YER').format(_supplier.totalDebt),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_supplier.company != null) ...[
            SizedBox(height: 15.h),
            Text(
              _supplier.company!,
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13.sp, fontWeight: FontWeight.w500),
            ),
          ],
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(
                '${_transactions.where((t) => t.type == SupplierTransactionType.purchase).length} ${'purchases'.tr()}',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11.sp),
              ),
              if (_supplier.phone.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    final phone = _supplier.phone.replaceAll(RegExp(r'\D'), '');
                    launchUrl(Uri.parse('https://wa.me/$phone'));
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.chat_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 4.w),
                        Text(
                          'whatsapp'.tr(),
                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 10.sp),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8.w),
            Text(
              'low_stock_alerts'.tr(),
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.orange[800]),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Container(
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.05),
            borderRadius: BorderRadius.circular(15.r),
            border: Border.all(color: Colors.orange.withOpacity(0.2)),
          ),
          child: Column(
            children: _lowStockItems.map((item) {
              return ListTile(
                dense: true,
                title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Text(
                  '${item['stock_quantity']} / ${item['reorder_level']}',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: 'pay_supplier'.tr(),
            icon: Icons.payment,
            color: AppColors.success,
            onTap: () => _showPaymentDialog(),
          ),
        ),
        SizedBox(width: 15.w),
        Expanded(
          child: _ActionButton(
            label: 'purchase_history'.tr(),
            icon: Icons.history,
            color: AppColors.primary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SupplierPurchaseHistoryScreen(initialSupplier: _supplier),
              ),
            ).then((_) => _loadData()),
          ),
        ),
      ],
    );
  }

  void _showEditRatingDialog() {
    double currentRating = _supplier.rating;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('rating'.tr()),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < currentRating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: Colors.amber,
                  size: 32.sp,
                ),
                onPressed: () => setDialogState(() => currentRating = index + 1.0),
              );
            }),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
            ElevatedButton(
              onPressed: () async {
                await _supplierService.updateSupplierRating(_supplier.id!, currentRating);
                if (mounted) {
                  Navigator.pop(context);
                  _loadData();
                }
              },
              child: Text('save'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentDialog() {
    if (_supplier.totalDebt <= 0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.green),
              SizedBox(width: 8.w),
              Text('pay_supplier'.tr()),
            ],
          ),
          content: Text('no_debt_to_pay_desc'.tr()),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('ok'.tr()),
            ),
          ],
        ),
      );
      return;
    }

    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? warningMessage;
    double adjustedAmount = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('pay_supplier'.tr()),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: amountController,
                  decoration: InputDecoration(labelText: 'amount'.tr()),
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    final entered = double.tryParse(val) ?? 0;
                    final currentDebt = _supplier.totalDebt;
                    if (entered > currentDebt && currentDebt > 0) {
                      setDialogState(() {
                        warningMessage = 'payment_exceeds_debt_warning'.tr(args: [currentDebt.toStringAsFixed(0)]);
                        adjustedAmount = currentDebt;
                      });
                    } else {
                      setDialogState(() {
                        warningMessage = null;
                        adjustedAmount = 0;
                      });
                    }
                  },
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'required_field'.tr();
                    if (double.tryParse(val) == null) return 'invalid_number'.tr();
                    return null;
                  },
                ),
                if (warningMessage != null) ...[
                  SizedBox(height: 10.h),
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            warningMessage!,
                            style: TextStyle(fontSize: 11.sp, color: Colors.orange[900]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 6.h),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        amountController.text = adjustedAmount.toStringAsFixed(0);
                        setDialogState(() => warningMessage = null);
                      },
                      child: Text(
                        'apply_suggested_amount'.tr(args: [adjustedAmount.toStringAsFixed(0)]),
                        style: TextStyle(fontSize: 12.sp, color: Colors.orange),
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 8.h),
                TextFormField(
                  controller: noteController,
                  decoration: InputDecoration(labelText: 'note'.tr()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  double amount = double.parse(amountController.text);
                  if (amount > _supplier.totalDebt && _supplier.totalDebt > 0) {
                    amount = _supplier.totalDebt;
                  }
                  final tx = SupplierTransaction(
                    supplierId: _supplier.id!,
                    type: SupplierTransactionType.payment,
                    amount: amount,
                    date: DateTime.now(),
                    note: noteController.text,
                  );
                  try {
                    await _transactionService.addTransaction(tx);
                    if (mounted) {
                      Navigator.pop(context);
                      _loadData();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('no_debt_to_pay'.tr())),
                      );
                    }
                  }
                }
              },
              child: Text('save'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList() {
    if (_transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.only(top: 40.h),
          child: Text('no_transactions'.tr(), style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _transactions.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        final isPurchase = tx.type == SupplierTransactionType.purchase;
        
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: (isPurchase ? AppColors.error : AppColors.success).withOpacity(0.1),
            child: Icon(
              isPurchase ? Icons.arrow_upward : Icons.arrow_downward,
              color: isPurchase ? AppColors.error : AppColors.success,
              size: 20,
            ),
          ),
          title: Text(
            isPurchase ? 'purchase'.tr() : 'payment'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            DateFormat('MMM dd, yyyy').format(tx.date),
            style: TextStyle(fontSize: 12.sp, color: Colors.grey),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyHelper.getFormatter(tx.currency).format(tx.amount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isPurchase ? AppColors.error : AppColors.success,
                ),
              ),
              if (tx.isVoid)
                Text(
                  'voided'.tr(),
                  style: TextStyle(color: Colors.red, fontSize: 10.sp, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          onTap: () {
            if (isPurchase) _showPurchaseInvoice(tx);
          },
          onLongPress: () {
             if (!tx.isVoid) _showVoidConfirmation(tx);
          },
        );
      },
    );
  }

  void _showPurchaseInvoice(SupplierTransaction tx) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Row(
          children: [
            const Icon(Icons.receipt_long_outlined, color: AppColors.primary),
            SizedBox(width: 10.w),
            Text('purchase_invoice'.tr()),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${'date'.tr()}: ${DateFormat('yyyy/MM/dd HH:mm').format(tx.date)}',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey),
              ),
              const Divider(),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: tx.items.length,
                  itemBuilder: (context, i) {
                    final item = tx.items[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${item.quantity} x ${CurrencyHelper.getFormatter(tx.currency).format(item.costPrice)}'),
                      trailing: Text(
                        CurrencyHelper.getFormatter(tx.currency).format(item.total),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
              _buildInvoiceRow('total_amount'.tr(), tx.amount, isBold: true),
              _buildInvoiceRow('paid_amount'.tr(), tx.paidAmount, color: AppColors.success),
              _buildInvoiceRow('remaining'.tr(), tx.amount - tx.paidAmount, color: AppColors.error, isBold: true),
              if (tx.note != null && tx.note!.isNotEmpty) ...[
                SizedBox(height: 10.h),
                Text('${'note'.tr()}: ${tx.note}', style: TextStyle(fontSize: 12.sp, fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('done'.tr())),
          ElevatedButton.icon(
            onPressed: () => _shareInvoice(tx),
            icon: const Icon(Icons.share, size: 18),
            label: Text('whatsapp'.tr()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceRow(String label, double value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13.sp, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            CurrencyHelper.getFormatter('YER').format(value),
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _shareInvoice(SupplierTransaction tx) async {
    String phone = _supplier.phone;
    phone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (phone.startsWith('0')) phone = phone.substring(1);
    if (!phone.startsWith('+') && !phone.startsWith('00') && !phone.startsWith('967')) {
      phone = '967$phone';
    }
    phone = phone.replaceAll('+', '').replaceAll('00', '');

    String message = '📦 *${'purchase_invoice'.tr()}*\n';
    message += '📅 ${DateFormat('yyyy/MM/dd').format(tx.date)}\n';
    message += '👤 ${'supplier'.tr()}: ${_supplier.name}\n';
    message += '--------------------------\n';
    for (var item in tx.items) {
      message += '🔹 ${item.productName}: ${item.quantity} x ${item.costPrice} = ${item.total}\n';
    }
    message += '--------------------------\n';
    message += '💰 *${'total_amount'.tr()}: ${tx.amount}*\n';
    message += '✅ ${'paid_amount'.tr()}: ${tx.paidAmount}\n';
    message += '⏳ *${'remaining'.tr()}: ${tx.amount - tx.paidAmount}*\n';
    
    final url = "https://wa.me/$phone?text=${Uri.encodeComponent(message)}";
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _showVoidConfirmation(SupplierTransaction tx) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('void_transaction'.tr()),
        content: Text('void_confirmation_desc'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
          ElevatedButton(
            onPressed: () async {
              await _transactionService.voidTransaction(tx.id!);
              if (mounted) {
                Navigator.pop(context);
                _loadData();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );
  }
  Widget _buildProductList() {
    if (_products.isEmpty) {
      return Center(
        child: Text('no_products'.tr(), style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.separated(
      itemCount: _products.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final product = _products[index];
        final lastPurchase = _lastPurchaseInfo[product.id];
        final hasPurchaseInfo = lastPurchase != null;
        final lastPrice = hasPurchaseInfo ? (lastPurchase!['cost_price'] as num).toDouble() : 0.0;
        
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
          ),
          title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sl<ProductService>().formatStock(product.stockQuantity, product.conversionFactor),
                style: TextStyle(fontSize: 12.sp),
              ),
              if (hasPurchaseInfo)
                Row(
                  children: [
                    Text(
                      '${'last_purchase'.tr()}: ${CurrencyHelper.getFormatter('YER').format(lastPrice)}',
                      style: TextStyle(fontSize: 10.sp, color: Colors.grey[600]),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      DateFormat('yyyy/MM/dd').format(DateTime.parse(lastPurchase!['date'])),
                      style: TextStyle(fontSize: 9.sp, color: Colors.grey[400]),
                    ),
                  ],
                ),
            ],
          ),
          trailing: Text(
            CurrencyHelper.getFormatter(product.currency).format(product.price),
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isFullWidth;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.isFullWidth = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15.r),
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: EdgeInsets.all(15.w),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15.r),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24.sp),
            SizedBox(height: 8.h),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
