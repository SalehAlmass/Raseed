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
import '../../../core/services/customer_service.dart';
import '../../../core/services/product_service.dart';
import '../../../core/services/transaction_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/widgets/barcode_scanner_view.dart';

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
  TransactionType _selectedType = TransactionType.sale;
  int _searchKey = 0;
  Customer? _selectedCustomer;
  List<Product> _products = [];
  List<Customer> _customers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _loadData();
  }

  @override
  void dispose() {
    _paidAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _products = await _productService.getAllProducts();
    _customers = await _customerService.getAllCustomers();
    setState(() => _isLoading = false);
  }

  double get _totalAmount => _cart.fold(0, (sum, item) => sum + item.total);
  double get _paidAmount => double.tryParse(_paidAmountController.text) ?? 0.0;

  void _addToCart(Product product) {
    setState(() {
      final existingIndex = _cart.indexWhere((item) => item.productId == product.id);
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
        _cart.add(TransactionItem(
          productId: product.id!,
          productName: product.name,
          quantity: 1,
          price: product.price,
          costPrice: product.costPrice,
          currency: product.currency,
        ));
      }
      // Auto-update paid amount if it was empty or matching previous total
      if (_paidAmountController.text.isEmpty || _selectedType == TransactionType.sale) {
         _paidAmountController.text = _totalAmount.toStringAsFixed(0);
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
      if (_selectedType == TransactionType.sale) {
         _paidAmountController.text = _totalAmount.toStringAsFixed(0);
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
            SnackBar(content: Text('product_not_found'.tr()), backgroundColor: AppColors.error),
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
         SnackBar(content: Text('amount_exceeds_total'.tr()), backgroundColor: AppColors.error),
       );
       return;
    }

    final bool isCustomerRequired = _selectedType == TransactionType.payment || paid < _totalAmount;
    if (isCustomerRequired && _selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('please_select_customer'.tr()), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final transaction = AppTransaction(
        customerId: _selectedCustomer?.id,
        type: _selectedType,
        amount: _totalAmount,
        paidAmount: paid,
        date: DateTime.now(),
        items: _cart,
      );

      await _transactionService.addTransaction(transaction);
      
      if (mounted && _selectedCustomer != null && _selectedCustomer!.phone.isNotEmpty) {
        double newDebt = _selectedCustomer!.totalDebt;
        if (_selectedType == TransactionType.sale) {
          newDebt += (_totalAmount - paid);
        } else {
          newDebt -= paid;
        }

        final bool? sendWa = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('إرسال تذكير عبر واتساب', style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text('تمت العملية بنجاح. هل تريد إرسال تفاصيل العملية والرصيد المتبقي إلى العميل عبر واتساب؟'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('cancel'.tr(), style: const TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('إرسال الآن'),
              ),
            ],
          ),
        );

        if (sendWa == true) {
          final String yerBal = CurrencyHelper.getFormatter('YER').format(newDebt);
          
          String phone = _selectedCustomer!.phone;
          phone = phone.replaceAll(RegExp(r'[^\d+]'), '');
          if (phone.startsWith('0')) phone = phone.substring(1);
          if (!phone.startsWith('+') && !phone.startsWith('00') && !phone.startsWith('967')) {
            phone = '967$phone';
          }
          phone = phone.replaceAll('+', '').replaceAll('00', '');

          final String formattedPaid = CurrencyHelper.getFormatter('YER').format(paid);
          final String formattedTotal = CurrencyHelper.getFormatter('YER').format(_totalAmount);

          String message = "مرحباً ${_selectedCustomer!.name}،\n";
          if (_selectedType == TransactionType.sale) {
             message += "لقد تم تسجيل فاتورة مشتريات بقيمة $formattedTotal";
             if (paid > 0) message += "، وسداد مبلغ $formattedPaid";
             message += ".\n";
          } else {
             message += "لقد تم تسجيل سند قبض (سداد) بمبلغ $formattedPaid.\n";
          }
          message += "\nبذلك إجمالي الرصيد المتبقي عليكم في تطبيق رصيد هو: $yerBal\nنتمنى لكم يوماً سعيداً!";

          final url = "https://wa.me/$phone?text=${Uri.encodeComponent(message)}";
          try {
            await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          } catch (_) {}
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('sale_completed_success'.tr()), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = 'error_occurred'.tr();
        final errorStr = e.toString();
        if (errorStr.contains('over_limit')) msg = 'over_limit_error'.tr();
        if (errorStr.contains('uninsufficient_stock')) msg = 'insufficient_stock_error'.tr();
        if (errorStr.contains('amount_exceeds_total')) msg = 'amount_exceeds_total'.tr();
        
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
    return Scaffold(
      appBar: AppBar(
        title: Text('new_sale'.tr()),
        actions: [
          IconButton(
            onPressed: _scanBarcode,
            icon: const Icon(Icons.qr_code_scanner),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildProductSearch(),
          Expanded(child: _buildCartList()),
          _buildCheckoutSection(),
        ],
      ),
    );
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            dropdownMenuEntries: _products.map((p) => DropdownMenuEntry<Product>(
              value: p,
              label: '${p.name} (${p.stockQuantity}) - ${CurrencyHelper.getSymbol(p.currency)}${p.price}',
            )).toList(),
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
        }
      ),
    );
  }

  Widget _buildCartList() {
    if (_cart.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64.sp, color: Colors.grey.withOpacity(0.5)),
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
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.productName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
                      Text(
                        '${CurrencyHelper.getSymbol(item.currency)}${item.price} / unit',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _updateQuantity(index, -1),
                      icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                    ),
                    Text('${item.quantity}', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                    IconButton(
                      onPressed: () => _updateQuantity(index, 1),
                      icon: const Icon(Icons.add_circle_outline, color: AppColors.success),
                    ),
                  ],
                ),
                SizedBox(width: 8.w),
                Text(
                  CurrencyHelper.getFormatter(item.currency).format(item.total),
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCheckoutSection() {
    final isOverpaid = _paidAmount > _totalAmount;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5)),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<TransactionType>(
              segments: [
                ButtonSegment(value: TransactionType.sale, label: Text('sale'.tr()), icon: const Icon(Icons.shopping_cart)),
                ButtonSegment(value: TransactionType.payment, label: Text('payment'.tr()), icon: const Icon(Icons.payment)),
              ],
              selected: {_selectedType},
              onSelectionChanged: (val) {
                 setState(() {
                    _selectedType = val.first;
                    if (_selectedType == TransactionType.sale) {
                       _paidAmountController.text = _totalAmount.toStringAsFixed(0);
                    } else if (_paidAmountController.text == _totalAmount.toStringAsFixed(0)) {
                       _paidAmountController.text = '0';
                    }
                 });
              },
            ),
            SizedBox(height: 16.h),
            DropdownButtonFormField<Customer>(
              value: _selectedCustomer,
              decoration: InputDecoration(
                labelText: (_selectedType == TransactionType.payment || _paidAmount < _totalAmount)
                    ? '${'select_customer'.tr()} *'
                    : '${'select_customer'.tr()} (اختياري)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              items: _customers.map((c) => DropdownMenuItem(
                value: c,
                child: Text('${c.name} (${CurrencyHelper.getFormatter("YER").format(c.totalDebt)})'),
              )).toList(),
              onChanged: (val) => setState(() => _selectedCustomer = val),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _paidAmountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: 'paid_amount'.tr(),
                        errorText: isOverpaid ? 'amount_exceeds_total'.tr() : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                        prefixText: 'YER ',
                    ),
                    onChanged: (val) => setState(() {}),
                  ),
                ),
                SizedBox(width: 16.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('total_amount'.tr(), style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary)),
                    Text(
                      CurrencyHelper.getFormatter('YER').format(_totalAmount),
                      style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              height: 54.h,
              child: ElevatedButton(
                onPressed: _isLoading || _cart.isEmpty || isOverpaid ? null : _completeSale,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text('complete_sale'.tr(), style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
