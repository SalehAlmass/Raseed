
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/category.dart';
import '../../../core/services/category_service.dart';
import '../../../core/theme/colors.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text('manage_categories'.tr()),
        actions: [
          IconButton(onPressed: _loadCategories, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading 
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
                        onPressed: () async {
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
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
