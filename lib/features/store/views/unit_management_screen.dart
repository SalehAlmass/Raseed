
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rseed/core/services/unit_service.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/unit.dart';
import '../../../core/services/category_service.dart';
import '../../../core/theme/colors.dart';

class UnitManagementScreen extends StatefulWidget {
  const UnitManagementScreen({super.key});

  @override
  State<UnitManagementScreen> createState() => _UnitManagementScreenState();
}

class _UnitManagementScreenState extends State<UnitManagementScreen> {
  final _unitService = sl<UnitService>();
  List<Unit> _units = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    setState(() => _isLoading = true);
    final units = await _unitService.getAllUnits();
    setState(() {
      _units = units;
      _isLoading = false;
    });
  }

  void _showAddEditDialog([Unit? unit]) {
    final controller = TextEditingController(text: unit?.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(unit == null ? 'add_unit'.tr() : 'edit_unit'.tr()),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'unit_name'.tr(),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              if (unit == null) {
                await _unitService.addUnit(Unit(name: controller.text.trim()));
              } else {
                await _unitService.updateUnit(Unit(id: unit.id, name: controller.text.trim()));
              }
              if (mounted) {
                Navigator.pop(context);
                _loadUnits();
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
        title: Text('manage_units'.tr()),
        actions: [
          IconButton(onPressed: _loadUnits, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: _units.length,
            itemBuilder: (context, index) {
              final unit = _units[index];
              return Card(
                margin: EdgeInsets.only(bottom: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                child: ListTile(
                  title: Text(unit.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showAddEditDialog(unit)),
                      IconButton(
                        icon: const Icon(Icons.delete, color: AppColors.error), 
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('confirm_delete'.tr()),
                              content: Text('delete_unit_warning'.tr()),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: Text('cancel'.tr())),
                                TextButton(onPressed: () => Navigator.pop(context, true), child: Text('delete'.tr(), style: const TextStyle(color: AppColors.error))),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await _unitService.deleteUnit(unit.id!);
                            _loadUnits();
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
