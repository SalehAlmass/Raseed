import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/app_transaction.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/product.dart';
import '../../../core/models/transaction_item.dart';
import '../../../core/models/installment_plan.dart';
import '../../../core/services/customer_service.dart';
import '../../../core/services/product_service.dart';
import '../../../core/services/transaction_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/discount_code_service.dart';
import '../../../core/services/receivable_service.dart';
import '../../../core/services/printer_service.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/routes/routes.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/models/app_feature.dart';
import '../../../core/widgets/barcode_scanner_view.dart';
import '../../../core/widgets/subscription_dialog.dart';
import '../../../core/widgets/transaction_detail_sheet.dart';
import '../../../core/widgets/desktop/desktop_scaffold.dart';
import '../../../core/widgets/desktop/desktop_table.dart';
import '../../../core/theme/desktop_tokens.dart';

class SaleScreen extends StatefulWidget {
  final TransactionType initialType;

  const SaleScreen({super.key, this.initialType = TransactionType.sale});

  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen> {
  final _transactionService = sl<TransactionService>();
  final _productService = sl<ProductService>();
  final _customerService = sl<CustomerService>();

  final List<TransactionItem> _cart = [];
  final _paidAmountController = TextEditingController();
  final _promoCodeController = TextEditingController();

  int _searchKey = 0;
  Customer? _selectedCustomer;
  List<Product> _products = [];
  List<Customer> _customers = [];
  bool _isLoading = false;

  String _desktopProductSearchQuery = '';

  DiscountType _discountType = DiscountType.none;
  double _discountValue = 0;
  double _promoDiscount = 0;
  bool _promoValid = false;
  bool _enableInstallments = false;
  int _installmentCount = 2;
  int _installmentPeriod = 30;

  @override
  void initState() {
    super.initState();

    _loadData();
  }

  @override
  void dispose() {
    _paidAmountController.dispose();
    _promoCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _products = await _productService.getAllProducts();
    _customers = await _customerService.getAllCustomers();
    setState(() => _isLoading = false);
  }

  double get _subtotal => _cart.fold(0.0, (sum, item) => sum + item.total);
  double get _invoiceDiscount {
    if (_discountType == DiscountType.percentage) return _subtotal * _discountValue / 100;
    if (_discountType == DiscountType.fixed) return _discountValue.clamp(0, _subtotal);
    return 0;
  }
  double get _totalAmount => _subtotal - _invoiceDiscount - _promoDiscount;
  double get _paidAmount => double.tryParse(_paidAmountController.text) ?? 0.0;

  void _addToCart(Product product) {
    setState(() {
      final existingIndex = _cart.indexWhere(
        (item) => item.productId == product.id,
      );
      if (existingIndex >= 0) {
        final existingItem = _cart[existingIndex];
        _cart[existingIndex] = TransactionItem(
          productId: existingItem.productId,
          productName: existingItem.productName,
          quantity: existingItem.quantity + 1,
          price: existingItem.price,
          costPrice: existingItem.costPrice,
          currency: existingItem.currency,
        );
      } else {
        _cart.add(
          TransactionItem(
            productId: product.id!,
            productName: product.name,
            quantity: 1,
            price: product.price,
            costPrice: product.costPrice,
            currency: product.currency,
          ),
        );
      }
      if (_totalAmount > 0) {
        _paidAmountController.text = _totalAmount.toStringAsFixed(0);
      } else {
        _paidAmountController.clear();
      }
    });
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      final newQty = _cart[index].quantity + delta;
      if (newQty <= 0) {
        _cart.removeAt(index);
      } else {
        final item = _cart[index];
        _cart[index] = TransactionItem(
          productId: item.productId,
          productName: item.productName,
          quantity: newQty,
          price: item.price,
          costPrice: item.costPrice,
          currency: item.currency,
        );
      }
      if (_totalAmount > 0) {
        _paidAmountController.text = _totalAmount.toStringAsFixed(0);
      } else {
        _paidAmountController.clear();
      }
    });
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerView()),
    );
    if (code != null) {
      try {
        final product = _products.firstWhere((p) => p.barcode == code);
        _addToCart(product);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('product_not_found'.tr()),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _completeSale() async {
    if (_cart.isEmpty) return;

    final paid = _paidAmount;
    if (paid > _totalAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('amount_exceeds_total'.tr()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final bool isCustomerRequired = paid < _totalAmount;
    if (isCustomerRequired && _selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('please_select_customer'.tr()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final netAmount = _totalAmount;

      final transaction = AppTransaction(
        customerId: _selectedCustomer?.id,
        type: TransactionType.sale,
        amount: netAmount,
        paidAmount: paid,
        date: DateTime.now(),
        items: _cart,
        discountType: _discountType,
        discountValue: _discountValue,
        promoCode: _promoValid ? _promoCodeController.text.trim().toUpperCase() : '',
      );

      final txId = await _transactionService.addTransaction(transaction);
      
      if (_enableInstallments && _selectedCustomer != null && paid < netAmount) {
        final remaining = netAmount - paid;
        final installAmount = remaining / _installmentCount;
        await sl<ReceivableService>().createPlan(InstallmentPlan(
          transactionId: txId,
          customerId: _selectedCustomer!.id!,
          totalAmount: netAmount,
          downPayment: paid,
          remaining: remaining,
          installmentAmount: installAmount,
          installmentCount: _installmentCount,
          periodDays: _installmentPeriod,
          startDate: DateTime.now(),
        ));
      }

      if (_promoValid) {
        try {
          final code = await sl<DiscountCodeService>().getByCode(_promoCodeController.text.trim());
          if (code?.id != null) await sl<DiscountCodeService>().incrementUses(code!.id!);
        } catch (_) {}
      }

      final settings = await sl<SettingsService>().getSettings();

      if (settings.enableWhatsapp &&
          mounted &&
          _selectedCustomer != null &&
          _selectedCustomer!.phone.isNotEmpty) {
        double newDebt = _selectedCustomer!.totalDebt;
        newDebt += (netAmount - paid);

        final bool? sendWa = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'whatsapp_reminder_title'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'whatsapp_reminder_desc'.tr(),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.r),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'cancel'.tr(),
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text('send_now'.tr()),
              ),
            ],
          ),
        );

        if (sendWa == true) {
          final String yerBal = CurrencyHelper.getFormatter(
            'YER',
          ).format(newDebt);

          String phone = _selectedCustomer!.phone;
          phone = phone.replaceAll(RegExp(r'[^\d+]'), '');
          if (phone.startsWith('0')) phone = phone.substring(1);
          if (!phone.startsWith('+') &&
              !phone.startsWith('00') &&
              !phone.startsWith('967')) {
            phone = '967$phone';
          }
          phone = phone.replaceAll('+', '').replaceAll('00', '');

          final String formattedPaid = CurrencyHelper.getFormatter(
            'YER',
          ).format(paid);
          final String formattedTotal = CurrencyHelper.getFormatter(
            'YER',
          ).format(_totalAmount);

          String message = 'whatsapp_msg_greeting'.tr(namedArgs: {'name': _selectedCustomer!.name});
          message += 'whatsapp_msg_sale'.tr(namedArgs: {'total': formattedTotal});
          if (paid > 0) message += 'whatsapp_msg_paid'.tr(namedArgs: {'paid': formattedPaid});
          message += 'whatsapp_msg_balance'.tr(namedArgs: {'balance': yerBal});

          final url =
              "https://wa.me/$phone?text=${Uri.encodeComponent(message)}";
          try {
            await launchUrl(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
            );
          } catch (_) {}
        }
      }

      if (mounted) {
        await TransactionDetailSheet.show(context, transaction);
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('sale_completed_success'.tr()),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String msg = 'error_occurred'.tr();
        final errorStr = e.toString();
        if (errorStr.contains('over_limit')) msg = 'over_limit_error'.tr();
        if (errorStr.contains('insufficient_stock'))
          msg = 'insufficient_stock_error'.tr();
        if (errorStr.contains('amount_exceeds_total'))
          msg = 'amount_exceeds_total'.tr();
        if (errorStr.contains('no_debt_to_repay'))
          msg = 'no_debt_to_repay'.tr();
        if (errorStr.contains('payment_exceeds_debt'))
          msg = 'payment_exceeds_debt'.tr();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return DesktopScaffold(
      activeNavIndex: 2,
      title: 'new_sale'.tr(),
      extendBody: true,
      actions: [
        IconButton(
          onPressed: _scanBarcode,
          icon: const Icon(Icons.qr_code_scanner),
          tooltip: 'scan'.tr(),
        ),
      ],
      onNavigate: _onNavTap,
      body: _buildMobileBody(),
      desktopBody: _buildDesktopBody(),
      showMobileBottomNav: false,
    );
  }

  Widget _buildMobileBody() {
    return Column(
      children: [
        _buildProductSearch(),
        Expanded(child: _buildCartList()),
        _buildCheckoutSection(),
      ],
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
        // Already on the sale screen; do not stack a duplicate.
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

  // ──────────────────────────────────────────────────────────────
  // Desktop UI (presentation-only). All values come from the
  // existing getters/state and all actions reuse the existing
  // callbacks unchanged.
  // ──────────────────────────────────────────────────────────────

  Widget _buildDesktopBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= AppBreakpoints.desktop;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDesktopWorkspace(constraints, wide),
              const SizedBox(height: AppSpace.xl),
              _buildDesktopCartTable(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopWorkspace(BoxConstraints constraints, bool wide) {
    final productPanel = _buildDesktopProductPanel(constraints);
    final summaryPanel = _buildDesktopSummaryPanel();

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 6, child: productPanel),
          const SizedBox(width: AppSpace.xl),
          Expanded(flex: 4, child: summaryPanel),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        productPanel,
        const SizedBox(height: AppSpace.xl),
        summaryPanel,
      ],
    );
  }

  Widget _buildDesktopProductPanel(BoxConstraints constraints) {
    final colors = AppColors.of(context);
    final products = _filteredProducts();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'select_product'.tr(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            TextField(
              onChanged: (v) =>
                  setState(() => _desktopProductSearchQuery = v),
              decoration: InputDecoration(
                hintText: 'search_products'.tr(),
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              onSubmitted: (_) {
                final first = products.isNotEmpty ? products.first : null;
                if (first != null) _addToCart(first);
              },
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              '${products.length} ${'items'.tr()}',
              style: TextStyle(fontSize: 12, color: colors.textLight),
            ),
            const SizedBox(height: AppSpace.sm),
            Expanded(
              child: products.isEmpty
                  ? Center(
                      child: Text(
                        'no_products_found'.tr(),
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textLight,
                        ),
                      ),
                    )
                  : _buildDesktopProductGrid(constraints),
            ),
          ],
        ),
      ),
    );
  }

  List<Product> _filteredProducts() {
    final query = _desktopProductSearchQuery.toLowerCase().trim();
    if (query.isEmpty) return _products;
    return _products
        .where((p) => p.name.toLowerCase().contains(query))
        .toList();
  }

  Widget _buildDesktopProductGrid(BoxConstraints constraints) {
    final products = _filteredProducts();
    final panelWidth = constraints.maxWidth;
    final int cols =
        (panelWidth.isFinite ? panelWidth / 190 : 2).clamp(1.0, 4.0).round();

    return SingleChildScrollView(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: AppSpace.sm,
          mainAxisSpacing: AppSpace.sm,
          childAspectRatio: 3.0,
        ),
        itemCount: products.length,
        itemBuilder: (_, index) {
          final product = products[index];
          return _SaleProductTile(
            product: product,
            onAdd: () => _addToCart(product),
          );
        },
      ),
    );
  }

  Widget _buildDesktopSummaryPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDesktopInvoiceHeader(),
                const SizedBox(height: AppSpace.md),
                _buildDesktopCustomerSelector(constraints),
                const SizedBox(height: AppSpace.md),
                _buildDesktopDiscountSection(),
                const SizedBox(height: AppSpace.md),
                _buildDesktopTotals(constraints),
                const SizedBox(height: AppSpace.md),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_isLoading || _cart.isEmpty || _paidAmount > _totalAmount)
                        ? null
                        : _completeSale,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpace.md),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                    icon: _isLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 20),
                    label: Text(
                      'complete_sale'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDesktopInvoiceHeader() {
    final colors = AppColors.of(context);
    final isCustomerRequired = _paidAmount < _totalAmount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'new_sale'.tr(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          _selectedCustomer == null
              ? (isCustomerRequired
                  ? '${'select_customer'.tr()} *'.tr()
                  : '${'select_customer'.tr()} ${'optional'.tr()}'.tr())
              : '${'selected_customer'.tr()}: ${_selectedCustomer!.name}',
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildDesktopCustomerSelector(BoxConstraints constraints) {
    final colors = AppColors.of(context);
    return DropdownMenu<Customer>(
      initialSelection: _selectedCustomer,
      width: constraints.maxWidth,
      enableFilter: true,
      requestFocusOnTap: true,
      leadingIcon: Icon(Icons.search, size: 20, color: colors.textSecondary),
      label: Text('select_customer'.tr()),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      dropdownMenuEntries: _customers
          .map(
            (c) => DropdownMenuEntry<Customer>(
              value: c,
              label:
                  '${c.name} (${CurrencyHelper.getFormatter('YER').format(c.totalDebt)})',
              enabled: true,
            ),
          )
          .toList(),
      onSelected: (val) => setState(() => _selectedCustomer = val),
    );
  }

  Widget _buildDesktopDiscountSection() {
    final colors = AppColors.of(context);
    final bool showRemaining =
        _selectedCustomer != null && _paidAmount < _totalAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          _buildDesktopDiscountChip(DiscountType.percentage),
          const SizedBox(width: AppSpace.xs),
          _buildDesktopDiscountChip(DiscountType.fixed),
          if (_discountType != DiscountType.none) ...[
            const SizedBox(width: AppSpace.xs),
            GestureDetector(
              onTap: () => setState(() {
                _discountType = DiscountType.none;
                _discountValue = 0;
              }),
              child: const Icon(Icons.close, size: 18, color: Colors.red),
            ),
          ],
        ]),
        if (_discountType != DiscountType.none &&
            _discountType == DiscountType.percentage) ...[
          const SizedBox(height: AppSpace.sm),
          SizedBox(
            width: 90,
            child: TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '10',
                suffixText: '%',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              onChanged: (v) => setState(
                  () => _discountValue = double.tryParse(v) ?? 0),
            ),
          ),
        ],
        if (_discountType != DiscountType.none &&
            _discountType == DiscountType.fixed) ...[
          const SizedBox(height: AppSpace.sm),
          SizedBox(
            width: 110,
            child: TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '1000',
                prefixText: '${CurrencyHelper.getSymbol('YER')} ',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              onChanged: (v) => setState(
                  () => _discountValue = double.tryParse(v) ?? 0),
            ),
          ),
        ],
        const SizedBox(height: AppSpace.sm),
        if (_invoiceDiscount > 0 || _promoDiscount > 0) ...[
          _buildDesktopTotalRow('subtotal'.tr(),
              CurrencyHelper.getFormatter('YER').format(_subtotal),
              colors.textSecondary, 11),
          if (_invoiceDiscount > 0)
            _buildDesktopTotalRow('discount'.tr(),
                '-${CurrencyHelper.getFormatter('YER').format(_invoiceDiscount)}',
                Colors.green[700]!, 11),
          if (_promoDiscount > 0)
            _buildDesktopTotalRow('promo'.tr(),
                '-${CurrencyHelper.getFormatter('YER').format(_promoDiscount)}',
                Colors.blue[700]!, 11),
        ],
        const SizedBox(height: AppSpace.sm),
        Row(children: [
          Icon(Icons.redeem, size: 16, color: colors.textLight),
          const SizedBox(width: AppSpace.xs),
          Expanded(
            child: TextField(
              controller: _promoCodeController,
              decoration: InputDecoration(
                hintText: 'promo_code'.tr(),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                suffixIcon: _promoCodeController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(_promoValid
                            ? Icons.check_circle
                            : Icons.search),
                        color: _promoValid ? Colors.green : colors.textLight,
                        iconSize: 18,
                        onPressed: _validatePromoCode,
                      )
                    : null,
              ),
              onChanged: (_) => setState(() => _promoValid = false),
              onSubmitted: (_) => _validatePromoCode(),
            ),
          ),
        ]),
        if (showRemaining) ...[
          const SizedBox(height: AppSpace.sm),
          Row(children: [
            Icon(Icons.calendar_month, size: 16, color: colors.textLight),
            const SizedBox(width: AppSpace.xs),
            Text('installments'.tr(),
                style: TextStyle(fontSize: 12, color: colors.textSecondary)),
            const Spacer(),
            Switch(
              value: _enableInstallments,
              onChanged: _paidAmount >= _totalAmount
                  ? null
                  : (v) => setState(() => _enableInstallments = v),
              activeThumbColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ]),
          if (_enableInstallments) ...[
            const SizedBox(height: AppSpace.sm),
            Row(children: [
              Text('${'number_of_installments'.tr()}: ',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary)),
              _buildDesktopStepper(_installmentCount,
                  (v) => setState(() => _installmentCount = v.clamp(2, 24))),
              const SizedBox(width: AppSpace.sm),
              Text('${'every'.tr()}: ',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary)),
              _buildDesktopStepper(_installmentPeriod,
                  (v) => setState(() => _installmentPeriod = v.clamp(7, 90))),
              Text(' ${'days'.tr()}', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
            ]),
          ],
        ],
      ],
    );
  }

  Widget _buildDesktopDiscountChip(DiscountType type) {
    final colors = AppColors.of(context);
    final bool isSelected = _discountType == type;
    final label = switch (type) {
      DiscountType.percentage => '%',
      DiscountType.fixed => 'fixed'.tr(),
      DiscountType.none => '',
    };
    return GestureDetector(
      onTap: () => setState(() {
        // Preserved exact logic from mobile _buildDiscountChip.
        _discountType = isSelected ? DiscountType.none : type;
        if (!isSelected) _discountValue = 0;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.blue : colors.textSecondary)),
      ),
    );
  }

  Widget _buildDesktopStepper(int value, ValueChanged<int> onChanged) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTap: () => onChanged(value - 1),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: const Icon(Icons.remove, size: 16),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text('$value',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ),
      GestureDetector(
        onTap: () => onChanged(value + 1),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: const Icon(Icons.add, size: 16),
        ),
      ),
    ]);
  }

  Widget _buildDesktopTotals(BoxConstraints constraints) {
    final colors = AppColors.of(context);
    final bool isOverpaid = _paidAmount > _totalAmount;
    final fmt = CurrencyHelper.getFormatter('YER');

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: _paidAmountController,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: 'paid_amount'.tr(),
          errorText: isOverpaid ? 'amount_exceeds_total'.tr() : null,
          prefixText: '${CurrencyHelper.getSymbol('YER')} ',
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
        onChanged: (val) => setState(() {}),
      ),
      const SizedBox(height: AppSpace.md),
      _buildDesktopTotalRow('subtotal'.tr(), fmt.format(_subtotal),
          colors.textSecondary, 13),
      if (_invoiceDiscount > 0)
        _buildDesktopTotalRow('discount'.tr(),
            '-${fmt.format(_invoiceDiscount)}', Colors.green[700]!, 13),
      if (_promoDiscount > 0)
        _buildDesktopTotalRow('promo'.tr(),
            '-${fmt.format(_promoDiscount)}', Colors.blue[700]!, 13),
      _buildDesktopTotalRow('tax'.tr(), fmt.format(0),
          colors.textSecondary, 13),
      const Divider(height: 16, thickness: 1),
      _buildDesktopTotalRow('total_amount'.tr(), fmt.format(_totalAmount),
          colors.textPrimary, 16, FontWeight.bold, AppColors.primary),
      if (isOverpaid)
        _buildDesktopTotalRow('amount_exceeds_total'.tr(),
            '-${fmt.format(_paidAmount - _totalAmount)}', Colors.red, 12),
      if (_paidAmount < _totalAmount && _totalAmount > 0)
        _buildDesktopTotalRow('remaining_amount'.tr(),
            fmt.format(_totalAmount - _paidAmount), Colors.orange[800]!, 13),
      if (_paidAmount == _totalAmount && _totalAmount > 0)
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.check_circle_outline,
              color: Colors.green, size: 16),
          const SizedBox(width: AppSpace.xs),
          Text('paid_full'.tr(),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800])),
        ]),
    ]);
  }

  Widget _buildDesktopTotalRow(String label, String value, Color color,
      double size, [FontWeight weight = FontWeight.normal, Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: size,
                    color: color,
                    fontWeight: weight))),
        Text(value,
            style: TextStyle(
                fontSize: size,
                color: valueColor ?? color,
                fontWeight: weight)),
      ]),
    );
  }

  Widget _buildDesktopCartTable() {
    return DesktopTable(
      headers: [
        'product'.tr(),
        'quantity'.tr(),
        'price'.tr(),
        'total'.tr(),
      ],
      flexes: [4, 2, 2, 2],
      emptyMessage: 'cart_empty'.tr(),
      rows: [
        for (int i = 0; i < _cart.length; i++) _buildCartRow(i, _cart[i]),
      ],
    );
  }

  List<Widget> _buildCartRow(int index, TransactionItem item) {
    final fmt = CurrencyHelper.getFormatter(item.currency);
    return [
      Text(item.productName,
          style: TextStyle(color: AppColors.of(context).textPrimary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
          tooltip: 'remove'.tr(),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove, size: 16, color: AppColors.error),
          onPressed: () => _updateQuantity(index, -1),
        ),
        Text('${item.quantity}',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold)),
        IconButton(
          tooltip: 'add'.tr(),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add, size: 16, color: AppColors.success),
          onPressed: () => _updateQuantity(index, 1),
        ),
      ]),
      Text(fmt.format(item.price),
          textAlign: TextAlign.right,
          style: TextStyle(color: AppColors.of(context).textSecondary)),
      Text(fmt.format(item.total),
          textAlign: TextAlign.right,
          style: TextStyle(
              fontWeight: FontWeight.bold, color: AppColors.primary)),
    ];
  }

  Widget _buildProductSearch() {
    return Container(
      padding: EdgeInsets.all(16.w),
      color: AppColors.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return DropdownMenu<Product>(
            key: ValueKey(_searchKey),
            width: constraints.maxWidth,
            enableFilter: true,
            requestFocusOnTap: true,
            leadingIcon: const Icon(Icons.search),
            label: Text('select_product'.tr()),
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            dropdownMenuEntries: _products
                .map(
                  (p) => DropdownMenuEntry<Product>(
                    value: p,
                    label:
                        '${p.name} (${p.stockQuantity}) - ${CurrencyHelper.getSymbol(p.currency)}${p.price}',
                  ),
                )
                .toList(),
            onSelected: (val) {
              if (val != null) {
                _addToCart(val);
                setState(() {
                  _searchKey++;
                });
                FocusScope.of(context).unfocus();
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildCartList() {
    if (_cart.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64.sp,
              color: Colors.grey.withOpacity(0.5),
            ),
            SizedBox(height: 16.h),
            Text('cart_empty'.tr(), style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(16.w),
      itemCount: _cart.length,
      separatorBuilder: (context, index) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        final item = _cart[index];
        return FadeInRight(
          duration: Duration(milliseconds: 300 + (index * 50)),
          child: Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.sp,
                        ),
                      ),
                      Text(
                        '${CurrencyHelper.getSymbol(item.currency)}${item.price} / unit',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _updateQuantity(index, -1),
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: AppColors.error,
                      ),
                    ),
                    Text(
                      '${item.quantity}',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _updateQuantity(index, 1),
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 8.w),
                Text(
                  CurrencyHelper.getFormatter(item.currency).format(item.total),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDiscountSection() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.discount, size: 18, color: Colors.blue),
              SizedBox(width: 8.w),
              Text('discount'.tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
              const Spacer(),
              if (_discountType != DiscountType.none)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _discountType = DiscountType.none;
                      _discountValue = 0;
                    });
                  },
                  child: const Icon(Icons.close, size: 18, color: Colors.red),
                ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              _buildDiscountChip(DiscountType.percentage, '%', context.locale.languageCode == 'ar' ? 'نسبة' : 'Percent'),
              SizedBox(width: 8.w),
              _buildDiscountChip(DiscountType.fixed, 'fixed', context.locale.languageCode == 'ar' ? 'قيمة' : 'Fixed'),
              SizedBox(width: 8.w),
              if (_discountType != DiscountType.none && _discountType == DiscountType.percentage)
                SizedBox(
                  width: 80.w,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '10',
                      suffixText: '%',
                      contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                    ),
                    onChanged: (v) => setState(() => _discountValue = double.tryParse(v) ?? 0),
                  ),
                ),
              if (_discountType != DiscountType.none && _discountType == DiscountType.fixed)
                SizedBox(
                  width: 100.w,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '1000',
                      prefixText: '${CurrencyHelper.getSymbol('YER')} ',
                      contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                    ),
                    onChanged: (v) => setState(() => _discountValue = double.tryParse(v) ?? 0),
                  ),
                ),
            ],
          ),
          if (_invoiceDiscount > 0 || _promoDiscount > 0) ...[
            SizedBox(height: 6.h),
            Row(
              children: [
                Text('subtotal'.tr(), style: TextStyle(fontSize: 11.sp, color: Colors.grey[600])),
                const Spacer(),
                Text(CurrencyHelper.getFormatter('YER').format(_subtotal), style: TextStyle(fontSize: 11.sp, color: Colors.grey[600])),
              ],
            ),
            if (_invoiceDiscount > 0)
              Row(
                children: [
                  Text('discount'.tr(), style: TextStyle(fontSize: 11.sp, color: Colors.green[700])),
                  const Spacer(),
                  Text('-${CurrencyHelper.getFormatter('YER').format(_invoiceDiscount)}', style: TextStyle(fontSize: 11.sp, color: Colors.green[700])),
                ],
              ),
            if (_promoDiscount > 0)
              Row(
                children: [
                  Text('promo'.tr(), style: TextStyle(fontSize: 11.sp, color: Colors.blue[700])),
                  const Spacer(),
                  Text('-${CurrencyHelper.getFormatter('YER').format(_promoDiscount)}', style: TextStyle(fontSize: 11.sp, color: Colors.blue[700])),
                ],
              ),
          ],
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(Icons.redeem, size: 16, color: Colors.grey[600]),
              SizedBox(width: 6.w),
              Expanded(
                child: TextField(
                  controller: _promoCodeController,
                  decoration: InputDecoration(
                    hintText: context.locale.languageCode == 'ar' ? 'كود خصم' : 'Promo code',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                    suffixIcon: _promoCodeController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(_promoValid ? Icons.check_circle : Icons.search, size: 18, color: _promoValid ? Colors.green : Colors.grey),
                            onPressed: _validatePromoCode,
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() => _promoValid = false),
                ),
              ),
            ],
          ),
          if (_selectedCustomer != null)
            SizedBox(height: 8.h),
          if (_selectedCustomer != null)
            Row(
              children: [
                Icon(Icons.calendar_month, size: 16, color: Colors.grey[600]),
                SizedBox(width: 6.w),
                Text(context.locale.languageCode == 'ar' ? 'تقسيط' : 'Installments', style: TextStyle(fontSize: 12.sp)),
                const Spacer(),
                Switch(
                  value: _enableInstallments,
                  onChanged: _paidAmount >= _totalAmount ? null : (v) => setState(() => _enableInstallments = v),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          if (_enableInstallments) ...[
            SizedBox(height: 6.h),
            Row(
              children: [
                Text('${context.locale.languageCode == 'ar' ? 'عدد الأقساط' : 'Installments'}: ', style: TextStyle(fontSize: 12.sp)),
                _buildStepper(_installmentCount, (v) => setState(() => _installmentCount = v.clamp(2, 24))),
                SizedBox(width: 12.w),
                Text('${context.locale.languageCode == 'ar' ? 'كل' : 'Every'}: ', style: TextStyle(fontSize: 12.sp)),
                _buildStepper(_installmentPeriod, (v) => setState(() => _installmentPeriod = v.clamp(7, 90))),
                Text(context.locale.languageCode == 'ar' ? ' يوم' : ' days', style: TextStyle(fontSize: 12.sp)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiscountChip(DiscountType type, String key, String label) {
    final isSelected = _discountType == type;
    return GestureDetector(
      onTap: () => setState(() {
        _discountType = isSelected ? DiscountType.none : type;
        if (!isSelected) _discountValue = 0;
      }),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.3)),
        ),
        child: Text(label, style: TextStyle(fontSize: 12.sp, color: isSelected ? Colors.blue : Colors.grey[700])),
      ),
    );
  }

  Widget _buildStepper(int value, ValueChanged<int> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => onChanged(value - 1),
          child: Container(
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: const Icon(Icons.remove, size: 16),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          child: Text('$value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
        ),
        GestureDetector(
          onTap: () => onChanged(value + 1),
          child: Container(
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: const Icon(Icons.add, size: 16),
          ),
        ),
      ],
    );
  }

  Future<void> _validatePromoCode() async {
    final code = _promoCodeController.text.trim();
    if (code.isEmpty) return;
    try {
      final discount = await sl<DiscountCodeService>().validateAndApply(code, _subtotal - _invoiceDiscount);
      setState(() {
        _promoDiscount = discount;
        _promoValid = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('promo_applied'.tr())));
      }
    } catch (e) {
      setState(() {
        _promoDiscount = 0;
        _promoValid = false;
      });
      String msg = 'promo_invalid'.tr();
      final err = e.toString();
      if (err.contains('promo_expired')) msg = 'promo_expired'.tr();
      if (err.contains('promo_min_purchase')) msg = 'promo_min_purchase'.tr();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.error));
      }
    }
  }

  Widget _buildCheckoutSection() {
    final isOverpaid = _paidAmount > _totalAmount;

    bool isButtonDisabled = _isLoading || _cart.isEmpty || isOverpaid;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return DropdownMenu<Customer>(
                  initialSelection: _selectedCustomer,
                  width: constraints.maxWidth,
                  enableFilter: true,
                  requestFocusOnTap: true,
                  leadingIcon: const Icon(Icons.search),
                  label: Text(
                    _paidAmount < _totalAmount
                        ? '${'select_customer'.tr()} *'
                        : '${'select_customer'.tr()} ${'optional'.tr()}',
                  ),
                  inputDecorationTheme: InputDecorationTheme(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  dropdownMenuEntries: _customers
                      .map(
                        (c) => DropdownMenuEntry<Customer>(
                          value: c,
                          label:
                              '${c.name} (${CurrencyHelper.getFormatter("YER").format(c.totalDebt)})',
                        ),
                      )
                      .toList(),
                  onSelected: (val) => setState(() => _selectedCustomer = val),
                );
              },
            ),
            SizedBox(height: 12.h),
            _buildDiscountSection(),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _paidAmountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'paid_amount'.tr(),
                      errorText: isOverpaid
                          ? 'amount_exceeds_total'.tr()
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      prefixText: '${CurrencyHelper.getSymbol('YER')} ',
                    ),
                    onChanged: (val) => setState(() {}),
                  ),
                ),
                SizedBox(width: 16.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'total_amount'.tr(),
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      CurrencyHelper.getFormatter('YER').format(_totalAmount),
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (_paidAmount < _totalAmount && _totalAmount > 0)
              Padding(
                padding: EdgeInsets.only(top: 12.h),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'remaining_amount'.tr(),
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.orange[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        CurrencyHelper.getFormatter('YER').format(_totalAmount - _paidAmount),
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.orange[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_paidAmount == _totalAmount && _totalAmount > 0)
               Padding(
                padding: EdgeInsets.only(top: 12.h),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                      SizedBox(width: 8.w),
                      Text(
                        'paid_full'.tr(),
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.green[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              height: 54.h,
              child: ElevatedButton(
                onPressed: isButtonDisabled ? null : _completeSale,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'complete_sale'.tr(),
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      
    );
  }
}

class _SaleProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onAdd;

  const _SaleProductTile({required this.product, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final symbol = CurrencyHelper.getSymbol(product.currency);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.sm),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary)),
                  const SizedBox(height: 2),
                  Text('$symbol ${product.price.toStringAsFixed(0)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: colors.textSecondary)),
                ],
              ),
            ),
            if (product.stockQuantity > 0)
              Text('${product.stockQuantity}',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w600)),
            const SizedBox(width: AppSpace.xs),
            SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                tooltip: 'add'.tr(),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
                onPressed: onAdd,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
