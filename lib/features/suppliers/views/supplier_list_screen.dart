import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/services/supplier_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/models/supplier.dart';
import '../../../core/models/supplier_category.dart';
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
  List<SupplierCategory> _categories = [];
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
    final categories = await _supplierService.getAllCategories();
    setState(() {
      _suppliers = suppliers;
      _filteredSuppliers = suppliers;
      _categories = categories;
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
                          category: _categories.firstWhere((c) => c.id == supplier.categoryId, orElse: () => SupplierCategory(name: '')),
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
    );
  }

  void _showAddSupplierDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final companyController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    SupplierCategory? selectedCategory;
    double rating = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('add_new_supplier'.tr()),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        label: RichText(
                          text: TextSpan(
                            text: 'supplier_name'.tr(),
                            style: TextStyle(color: Colors.grey[700], fontSize: 14.sp),
                            children: [
                              TextSpan(
                                text: ' *',
                                style: TextStyle(color: Colors.red[700], fontSize: 14.sp, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
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
                    const SizedBox(height: 15),
                    DropdownButtonFormField<SupplierCategory>(
                      value: selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'category'.tr(),
                        prefixIcon: const Icon(Icons.category_outlined),
                      ),
                      items: [
                        ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c.name))),
                        DropdownMenuItem(
                          value: null,
                          child: Text('+ ${'add_category'.tr()}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ),
                      ],
                      onChanged: (val) async {
                        if (val == null) {
                          final catName = await _showAddCategoryDialog(context);
                          if (catName != null) {
                            await _supplierService.addCategory(SupplierCategory(name: catName));
                            await _loadSuppliers();
                            setDialogState(() {});
                          }
                        } else {
                          setDialogState(() => selectedCategory = val);
                        }
                      },
                    ),
                    const SizedBox(height: 15),
                    Text('rating'.tr(), style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: Colors.amber,
                          ),
                          onPressed: () => setDialogState(() => rating = index + 1.0),
                        );
                      }),
                    ),
                  ],
                ),
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
                      categoryId: selectedCategory?.id,
                      rating: rating,
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
          );
        },
      ),
    );
  }

  Future<String?> _showAddCategoryDialog(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('add_category'.tr()),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: 'category_name'.tr()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('add'.tr()),
          ),
        ],
      ),
    );
  }
}

class _SupplierTile extends StatelessWidget {
  final Supplier supplier;
  final SupplierCategory category;
  final VoidCallback onTap;

  const _SupplierTile({required this.supplier, required this.category, required this.onTap});

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
        title: Row(
          children: [
            Expanded(child: Text(supplier.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp))),
            if (supplier.rating > 0) ...[
              const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
              SizedBox(width: 2.w),
              Text(supplier.rating.toStringAsFixed(1), style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.amber[800])),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(supplier.company ?? supplier.phone, style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
            if (category.name.isNotEmpty)
              Container(
                margin: EdgeInsets.only(top: 4.h),
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(5.r)),
                child: Text(category.name, style: TextStyle(fontSize: 9.sp, color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyHelper.getFormatter('YER').format(supplier.totalPaid),
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.sp,
                      ),
                    ),
                    Text('total_paid'.tr(), style: TextStyle(fontSize: 9.sp, color: Colors.grey)),
                  ],
                ),
                SizedBox(width: 12.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyHelper.getFormatter('YER').format(supplier.totalDebt),
                      style: TextStyle(
                        color: supplier.totalDebt > 0 ? AppColors.error : AppColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.sp,
                      ),
                    ),
                    Text('remaining'.tr(), style: TextStyle(fontSize: 9.sp, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
