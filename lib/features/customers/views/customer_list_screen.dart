import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/services/customer_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/models/customer.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/routes/routes.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/widgets/app_bottom_navigation_bar.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final CustomerService _customerService = sl<CustomerService>();
  final SettingsService _settingsService = sl<SettingsService>();
  List<Customer> _customers = [];
  List<Customer> _filteredCustomers = [];
  AppSettings? _settings;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    final customers = await _customerService.getAllCustomers();
    final settings = await _settingsService.getSettings();
    setState(() {
      _customers = customers;
      _filteredCustomers = customers;
      _settings = settings;
      _isLoading = false;
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCustomers = _customers.where((customer) {
        return customer.name.toLowerCase().contains(query) || 
               customer.phone.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('customers'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(20.w),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'search_hint'.tr(),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15.r),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _filteredCustomers.isEmpty
                ? Center(child: Text('no_customers'.tr()))
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    itemCount: _filteredCustomers.length,
                    itemBuilder: (context, index) {
                      final customer = _filteredCustomers[index];
                      return _CustomerTile(
                        customer: customer,
                        settings: _settings,
                        onTap: () => Navigator.pushNamed(
                          context, 
                          '/customer_detail', 
                          arguments: customer,
                        ).then((_) => _loadCustomers()),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCustomerDialog(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add),
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        activeIndex: 0,
        onTap: _onNavTap,
      ),
    );
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.pushReplacementNamed(context, Routes.home);
        break;
      case 2:
        Navigator.pushReplacementNamed(context, Routes.reports);
        break;
      case 3:
        Navigator.pushReplacementNamed(context, Routes.store);
        break;
    }
  }

  void _showAddCustomerDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('add_new_customer'.tr()),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'name'.tr()),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'مطلوب إدخال الاسم';
                  if (!RegExp(r'^[\u0600-\u06FFa-zA-Z\s]+$').hasMatch(val)) return 'يجب أن يحتوي الاسم على حروف فقط';
                  return null;
                },
              ),
              TextFormField(
                controller: phoneController,
                decoration: InputDecoration(labelText: 'phone_number'.tr()),
                keyboardType: TextInputType.phone,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'مطلوب إدخال رقم الهاتف';
                  if (val.trim().length < 9) return 'رقم الهاتف غير صحيح';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await _customerService.createCustomer(Customer(
                  name: nameController.text,
                  phone: phoneController.text,
                ));
                if (context.mounted) {
                  Navigator.pop(context);
                  _loadCustomers();
                }
              }
            },
            child: Text('save'.tr()),
          ),
        ],
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  final Customer customer;
  final AppSettings? settings;
  final VoidCallback onTap;

  const _CustomerTile({required this.customer, required this.onTap, this.settings});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 15.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(15.w),
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Text(
            customer.name.substring(0, 1).toUpperCase(),
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          customer.name,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
        ),
        subtitle: Text(customer.phone),
        trailing: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${CurrencyHelper.getFormatter('YER').format(customer.totalDebt)} YER',
                style: TextStyle(
                  color: customer.totalDebt > 0 ? AppColors.error : AppColors.success,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.sp,
                ),
              ),
              Text('debt'.tr(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
