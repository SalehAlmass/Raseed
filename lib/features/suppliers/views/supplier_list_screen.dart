import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/services/supplier_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/models/supplier.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/widgets/app_bottom_navigation_bar.dart';
import '../../../core/routes/routes.dart';
import 'supplier_detail_screen.dart';

class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  final SupplierService _supplierService = sl<SupplierService>();
  List<Supplier> _suppliers = [];
  List<Supplier> _filteredSuppliers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    setState(() => _isLoading = true);
    final suppliers = await _supplierService.getAllSuppliers();
    setState(() {
      _suppliers = suppliers;
      _filteredSuppliers = suppliers;
      _isLoading = false;
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSuppliers = _suppliers.where((s) {
        return s.name.toLowerCase().contains(query) ||
            s.phone.contains(query) ||
            (s.company?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('suppliers'.tr()),
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
                hintText: 'search_supplier'.tr(),
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
                : _filteredSuppliers.isEmpty
                ? Center(child: Text('no_suppliers'.tr()))
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 100.h),
                    itemCount: _filteredSuppliers.length,
                    itemBuilder: (context, index) {
                      final supplier = _filteredSuppliers[index];
                      return FadeInUp(
                        duration: Duration(milliseconds: 300 + (index * 50)),
                        child: _SupplierTile(
                          supplier: supplier,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SupplierDetailScreen(supplier: supplier),
                              ),
                            ).then((_) => _loadSuppliers());
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSupplierDialog(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_business_rounded),
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        activeIndex: 4, // Assuming we use it for something else or just highlight
        onTap: (index) {
           // Handle navigation
           if (index == 0) Navigator.pushReplacementNamed(context, Routes.home);
           if (index == 1) Navigator.pushReplacementNamed(context, Routes.customers);
           if (index == 4) Navigator.pushReplacementNamed(context, Routes.store);
        },
      ),
    );
  }

  void _showAddSupplierDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final companyController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('add_new_supplier'.tr()),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'supplier_name'.tr()),
                validator: (val) => (val == null || val.isEmpty) ? 'name_required'.tr() : null,
              ),
              TextFormField(
                controller: phoneController,
                decoration: InputDecoration(labelText: 'phone_number'.tr()),
                keyboardType: TextInputType.phone,
              ),
              TextFormField(
                controller: companyController,
                decoration: InputDecoration(labelText: 'company_name'.tr()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await _supplierService.addSupplier(Supplier(
                  name: nameController.text,
                  phone: phoneController.text,
                  company: companyController.text,
                ));
                if (mounted) {
                  Navigator.pop(context);
                  _loadSuppliers();
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

class _SupplierTile extends StatelessWidget {
  final Supplier supplier;
  final VoidCallback onTap;

  const _SupplierTile({required this.supplier, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 15.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(15.w),
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: const Icon(Icons.business_rounded, color: AppColors.primary),
        ),
        title: Text(supplier.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
        subtitle: Text(supplier.company ?? supplier.phone, style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              CurrencyHelper.getFormatter('YER').format(supplier.totalDebt),
              style: TextStyle(
                color: supplier.totalDebt > 0 ? AppColors.error : AppColors.success,
                fontWeight: FontWeight.bold,
                fontSize: 14.sp,
              ),
            ),
            Text('supplier_debt'.tr(), style: TextStyle(fontSize: 10.sp, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
