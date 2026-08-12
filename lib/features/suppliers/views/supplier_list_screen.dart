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
import '../../../core/routes/routes.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/models/app_feature.dart';
import '../../../core/widgets/subscription_dialog.dart';
import '../../../core/theme/desktop_tokens.dart';
import '../../../core/widgets/desktop/desktop_scaffold.dart';
import '../../../core/widgets/desktop/desktop_table.dart';
import '../../../core/widgets/desktop/page_header.dart';
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
  SupplierCategory? _selectedCategory;
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
    return DesktopScaffold(
      activeNavIndex: -1,
      title: 'suppliers'.tr(),
      extendBody: true,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSupplierDialog(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_business_rounded),
      ),
      onNavigate: _onNavTap,
      body: _buildMobileBody(),
      desktopBody: _buildDesktopBody(),
    );
  }

  Widget _buildMobileBody() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(20.w),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'search_supplier'.tr(),
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppColors.of(context).surface,
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
    );
  }

  Widget _buildDesktopBody() {
    final colors = AppColors.of(context);
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
                title: 'suppliers'.tr(),
                subtitle: '${_desktopFilteredSuppliers.length} ${'suppliers'.tr()}',
                actions: [
                  FilledButton.icon(
                    onPressed: () => _showAddSupplierDialog(context),
                    icon: const Icon(Icons.add_business_rounded, size: 18),
                    label: Text('add_new_supplier'.tr()),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              _buildDesktopToolbar(colors),
              const SizedBox(height: AppSpace.lg),
              _buildDesktopSuppliersTable(colors),
            ],
          ),
        ),
      ),
    );
  }

  List<Supplier> get _desktopFilteredSuppliers {
    final query = _searchController.text.toLowerCase();
    return _suppliers.where((s) {
      final matchesSearch = s.name.toLowerCase().contains(query) ||
          s.phone.contains(query) ||
          (s.company?.toLowerCase().contains(query) ?? false);
      final matchesCategory =
          _selectedCategory == null || s.categoryId == _selectedCategory!.id;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  Widget _buildDesktopToolbar(AppColorSet colors) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
        boxShadow: AppShadow.soft(Colors.black),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 300,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'search_supplier'.tr(),
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                fillColor: colors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Wrap(
              spacing: AppSpace.xs,
              runSpacing: AppSpace.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildDesktopFilterChip('all'.tr(), null),
                for (final category in _categories)
                  _buildDesktopFilterChip(category.name, category),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopFilterChip(String label, SupplierCategory? category) {
    final isSelected = _selectedCategory?.id == category?.id;
    final colors = AppColors.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      onSelected: (val) {
        if (val) {
          setState(() {
            _selectedCategory = category;
          });
        }
      },
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : colors.textPrimary,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: colors.surface,
      selectedColor: AppColors.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildDesktopSuppliersTable(AppColorSet colors) {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final rows = _desktopFilteredSuppliers
        .map((s) => _buildSupplierRow(colors, s))
        .toList();
    return DesktopTable(
      headers: [
        'name'.tr(),
        'phone_number'.tr(),
        'category'.tr(),
        'total_paid'.tr(),
        'remaining'.tr(),
        '',
      ],
      flexes: const [3, 2, 2, 2, 2, 1],
      rows: rows,
      emptyMessage: 'no_suppliers'.tr(),
    );
  }

  List<Widget> _buildSupplierRow(AppColorSet colors, Supplier supplier) {
    final category = _categories.firstWhere(
      (c) => c.id == supplier.categoryId,
      orElse: () => SupplierCategory(name: ''),
    );
    return [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              supplier.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          if (supplier.rating > 0) ...[
            const SizedBox(width: AppSpace.xs),
            const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
            const SizedBox(width: 2),
            Text(
              supplier.rating.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.amber[800],
              ),
            ),
          ],
        ],
      ),
      Text(
        supplier.phone,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      category.name.isEmpty
          ? Text('-', style: const TextStyle(fontSize: 12))
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                category.name,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
      Text(
        CurrencyHelper.getFormatter('YER').format(supplier.totalPaid),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.success,
        ),
      ),
      Text(
        CurrencyHelper.getFormatter('YER').format(supplier.totalDebt),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: supplier.totalDebt > 0 ? AppColors.error : AppColors.success,
        ),
      ),
      IconButton(
        tooltip: 'view'.tr(),
        iconSize: 18,
        visualDensity: VisualDensity.compact,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SupplierDetailScreen(supplier: supplier),
            ),
          ).then((_) => _loadSuppliers());
        },
        icon: const Icon(Icons.chevron_right_rounded),
      ),
    ];
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
          Navigator.pushNamed(context, Routes.sale).then((result) {
            if (result == true) _loadSuppliers();
          });
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
                            style: TextStyle(color: AppColors.of(context).textSecondary, fontSize: 14.sp),
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
                    Text('rating'.tr(), style: TextStyle(fontSize: 12.sp, color: AppColors.of(context).textLight)),
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
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(15.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(15.w),
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
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
            Text(supplier.company ?? supplier.phone, style: TextStyle(fontSize: 12.sp, color: AppColors.of(context).textLight)),
            if (category.name.isNotEmpty)
              Container(
                margin: EdgeInsets.only(top: 4.h),
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5.r)),
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
                    Text('total_paid'.tr(), style: TextStyle(fontSize: 9.sp, color: AppColors.of(context).textLight)),
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
                    Text('remaining'.tr(), style: TextStyle(fontSize: 9.sp, color: AppColors.of(context).textLight)),
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
