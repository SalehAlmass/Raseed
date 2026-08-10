
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/app_feature.dart';
import '../../../core/models/category.dart';
import '../../../core/routes/routes.dart';
import '../../../core/services/category_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/desktop_tokens.dart';
import '../../../core/widgets/desktop/desktop_scaffold.dart';
import '../../../core/widgets/desktop/desktop_table.dart';
import '../../../core/widgets/desktop/page_header.dart';
import '../../../core/widgets/subscription_dialog.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final _categoryService = sl<CategoryService>();
  List<Category> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    final categories = await _categoryService.getAllCategories();
    setState(() {
      _categories = categories;
      _isLoading = false;
    });
  }

  void _showAddEditDialog([Category? category]) {
    final controller = TextEditingController(text: category?.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(category == null ? 'add_category'.tr() : 'edit_category'.tr()),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'category_name'.tr(),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              if (category == null) {
                await _categoryService.addCategory(Category(name: controller.text.trim()));
              } else {
                await _categoryService.updateCategory(Category(id: category.id, name: controller.text.trim()));
              }
              if (mounted) {
                Navigator.pop(context);
                _loadCategories();
              }
            },
            child: Text('save'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DesktopScaffold(
      activeNavIndex: -1,
      title: 'manage_categories'.tr(),
      actions: [
        IconButton(onPressed: _loadCategories, icon: const Icon(Icons.refresh)),
      ],
      onNavigate: _onNavTap,
      body: _buildMobileBody(context),
      desktopBody: _buildDesktopBody(context),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMobileBody(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              return Card(
                margin: EdgeInsets.only(bottom: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                child: ListTile(
                  title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showAddEditDialog(cat)),
                      IconButton(
                        icon: const Icon(Icons.delete, color: AppColors.error),
                        onPressed: () => _confirmDelete(cat),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  Widget _buildDesktopBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: DesktopMetrics.contentMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'manage_categories'.tr(),
                subtitle: '${_categories.length}',
                actions: [
                  FilledButton.icon(
                    onPressed: () => _showAddEditDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text('add_category'.tr()),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              _buildDesktopTable(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTable() {
    return DesktopTable(
      headers: [
        'name'.tr(),
        '',
      ],
      flexes: const [4, 1],
      rows: [
        for (final cat in _categories)
          [
            Text(
              cat.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'edit_category'.tr(),
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showAddEditDialog(cat),
                ),
                IconButton(
                  tooltip: 'delete'.tr(),
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete, color: AppColors.error),
                  onPressed: () => _confirmDelete(cat),
                ),
              ],
            ),
          ],
      ],
      isLoading: _isLoading,
    );
  }

  Future<void> _confirmDelete(Category cat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_delete'.tr()),
        content: Text('delete_category_warning'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('cancel'.tr())),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('delete'.tr(), style: const TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm == true) {
      final inUse = await _categoryService.isCategoryInUse(cat.id!);
      if (inUse) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('category_in_use'.tr()), backgroundColor: AppColors.error),
          );
        }
        return;
      }
      await _categoryService.deleteCategory(cat.id!);
      _loadCategories();
    }
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0: Navigator.pushReplacementNamed(context, Routes.home); break;
      case 1: Navigator.pushReplacementNamed(context, Routes.customers); break;
      case 2:
        if (sl<SubscriptionService>().canUseFeature(AppFeature.addSale)) {
          Navigator.pushNamed(context, Routes.sale);
        } else { SubscriptionDialog.show(context); }
        break;
      case 3:
        if (sl<SubscriptionService>().canUseFeature(AppFeature.viewReports)) {
          Navigator.pushReplacementNamed(context, Routes.reports);
        } else { SubscriptionDialog.show(context); }
        break;
      case 4: Navigator.pushReplacementNamed(context, Routes.store); break;
    }
  }
}
