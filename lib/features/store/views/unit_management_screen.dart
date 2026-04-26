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
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'unit_name'.tr(),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15.r),
                    borderSide: BorderSide.none,
                  ),
                ),
                autofocus: true,
              ),
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
                ),
                items: [
                  DropdownMenuItem<Unit>(
                    value: null,
                    child: Text('none_manual'.tr()),
                  ),
                  ..._units
                      .where((u) => u.id != unit?.id) // Prevent self-reference
                      .map(
                        (u) => DropdownMenuItem(value: u, child: Text(u.name)),
                      ),
                ],
                onChanged: (val) => setDialogState(() => selectedParent = val),
              ),
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
                final newUnit = Unit(
                  id: unit?.id,
                  name: nameController.text.trim(),
                  parentId: selectedParent?.id,
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
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
    final String initial = unit.name.isNotEmpty
        ? unit.name[0].toUpperCase()
        : '?';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(20.r),
                  bottomLeft: Radius.circular(20.r),
                ),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  unit.name,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    _CircleActionButton(
                      icon: Icons.edit,
                      color: Colors.blue,
                      onTap: () => _showAddEditDialog(unit),
                    ),
                    SizedBox(width: 8.w),
                    _CircleActionButton(
                      icon: Icons.delete_outline,
                      color: AppColors.error,
                      onTap: () => _confirmDelete(unit),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
      await _unitService.deleteUnit(unit.id!);
      _loadUnits();
    }
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
