import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rseed/core/services/unit_service.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/unit.dart';
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
    final nameController = TextEditingController(text: unit?.name);
    bool isSubUnit = unit?.parentId != null;
    Unit? selectedParent = _units
        .where((u) => u.id == unit?.parentId)
        .firstOrNull;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          title: Text(unit == null ? 'add_unit'.tr() : 'edit_unit'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('unit_type'.tr(), style: TextStyle(fontSize: 12.sp, color: Colors.grey[600], fontWeight: FontWeight.bold)),
              SizedBox(height: 8.h),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('main_unit_label'.tr()),
                    icon: const Icon(Icons.inventory_2_outlined),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('sub_unit_label'.tr()),
                    icon: const Icon(Icons.inventory_outlined),
                  ),
                ],
                selected: {isSubUnit},
                onSelectionChanged: (Set<bool> selection) {
                  setDialogState(() {
                    isSubUnit = selection.first;
                    if (!isSubUnit) selectedParent = null;
                  });
                },
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: AppColors.primary,
                  selectedForegroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              SizedBox(height: 20.h),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'unit_name'.tr(),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15.r),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.drive_file_rename_outline),
                ),
                autofocus: true,
              ),
              if (isSubUnit) ...[
                SizedBox(height: 16.h),
                DropdownButtonFormField<Unit>(
                  value: selectedParent,
                  decoration: InputDecoration(
                    labelText: 'main_unit'.tr(),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15.r),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.account_tree_outlined),
                  ),
                  items: _units
                      .where((u) => u.parentId == null && u.id != unit?.id) // Only main units as parents
                      .map(
                        (u) => DropdownMenuItem(value: u, child: Text(u.name)),
                      )
                      .toList(),
                  onChanged: (val) => setDialogState(() => selectedParent = val),
                  validator: (val) => isSubUnit && val == null ? 'select_unit_type'.tr() : null,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                if (isSubUnit && selectedParent == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('select_unit_type'.tr())),
                  );
                  return;
                }
                
                final newUnit = Unit(
                  id: unit?.id,
                  name: nameController.text.trim(),
                  parentId: isSubUnit ? selectedParent?.id : null,
                );
                
                if (unit == null) {
                  await _unitService.addUnit(newUnit);
                } else {
                  await _unitService.updateUnit(newUnit);
                }
                
                if (mounted) {
                  Navigator.pop(context);
                  _loadUnits();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: Size(100.w, 45.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text('save'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('manage_units'.tr()),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(onPressed: _loadUnits, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _units.isEmpty
          ? _buildEmptyState()
          : GridView.builder(
              padding: EdgeInsets.all(20.w),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 15.w,
                mainAxisSpacing: 15.h,
                childAspectRatio: 1.1,
              ),
              itemCount: _units.length,
              itemBuilder: (context, index) {
                final unit = _units[index];
                return _buildUnitCard(unit);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: Text('add_unit'.tr()),
      ),
    );
  }

  Widget _buildUnitCard(Unit unit) {
    final isMainUnit = unit.parentId == null;
    final accentColor = isMainUnit ? AppColors.primary : Colors.teal;
    final iconData = isMainUnit ? Icons.inventory_2_outlined : Icons.inventory_outlined;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: accentColor.withOpacity(0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Stack(
          children: [
            // Background Decorative Icon
            Positioned(
              right: -10,
              bottom: -10,
              child: Icon(
                iconData,
                size: 80.sp,
                color: accentColor.withOpacity(0.03),
              ),
            ),
            
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showAddEditDialog(unit),
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Unit Icon & Type Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            unit.name,
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              (isMainUnit ? 'main_unit_label' : 'sub_unit_label').tr(),
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const Spacer(),
                      
                      // Unit Name
                     
                      SizedBox(height: 12.h),
                      
                      // Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _SmallActionButton(
                            icon: Icons.edit_outlined,
                            color: Colors.blue,
                            onTap: () => _showAddEditDialog(unit),
                          ),
                          SizedBox(width: 8.w),
                          _SmallActionButton(
                            icon: Icons.delete_outline,
                            color: AppColors.error,
                            onTap: () => _confirmDelete(unit),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.straighten_outlined, size: 80.sp, color: Colors.grey[300]),
          SizedBox(height: 16.h),
          Text(
            'no_units_yet'.tr(),
            style: TextStyle(
              fontSize: 18.sp,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'add_units_to_manage_inventory'.tr(),
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Unit unit) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Text('confirm_delete'.tr()),
        content: Text('delete_unit_warning'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'delete'.tr(),
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final inUse = await _unitService.isUnitInUse(unit.id!);
      if (inUse) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('unit_in_use'.tr()),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
      await _unitService.deleteUnit(unit.id!);
      _loadUnits();
    }
  }
}

class _SmallActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SmallActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Icon(icon, color: color, size: 16.sp),
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CircleActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 18.sp),
      ),
    );
  }
}
