import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/user.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/colors.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() => _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  final _authService = sl<AuthService>();
  List<AppUser> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final users = await _authService.getAllUsers();
    setState(() {
      _users = users;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('employee_management'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: EdgeInsets.all(16.w),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return _buildUserCard(user);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddUserDialog(),
        label: Text('add_employee'.tr()),
        icon: const Icon(Icons.person_add_rounded),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildUserCard(AppUser user) {
    Color roleColor;
    switch (user.role) {
      case UserRole.admin: roleColor = Colors.purple; break;
      case UserRole.cashier: roleColor = Colors.blue; break;
      case UserRole.warehouse: roleColor = Colors.orange; break;
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.only(bottom: 12.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(16.w),
        leading: CircleAvatar(
          backgroundColor: roleColor.withOpacity(0.1),
          child: Icon(Icons.person_rounded, color: roleColor),
        ),
        title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('@${user.username}', style: TextStyle(color: Colors.grey, fontSize: 12.sp)),
            SizedBox(height: 4.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                user.role.name.tr(),
                style: TextStyle(color: roleColor, fontSize: 10.sp, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        trailing: user.id == 1 
            ? null 
            : IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmDelete(user),
              ),
      ),
    );
  }

  void _showAddUserDialog() {
    final nameController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    UserRole selectedRole = UserRole.cashier;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('add_employee'.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'name'.tr()),
                ),
                TextField(
                  controller: usernameController,
                  decoration: InputDecoration(labelText: 'username'.tr()),
                ),
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(labelText: 'password'.tr()),
                  obscureText: true,
                ),
                SizedBox(height: 16.h),
                DropdownButtonFormField<UserRole>(
                  value: selectedRole,
                  items: UserRole.values.map((role) => DropdownMenuItem(
                    value: role,
                    child: Text(role.name.tr()),
                  )).toList(),
                  onChanged: (val) => setDialogState(() => selectedRole = val!),
                  decoration: InputDecoration(labelText: 'role'.tr()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
            ElevatedButton(
              onPressed: () async {
                final user = AppUser(
                  name: nameController.text,
                  username: usernameController.text,
                  password: passwordController.text,
                  role: selectedRole,
                  createdAt: DateTime.now(),
                );
                await _authService.addUser(user);
                Navigator.pop(context);
                _loadUsers();
              },
              child: Text('add'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(AppUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('delete_confirm'.tr()),
        content: Text('delete_employee_confirm'.tr(args: [user.name])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
          TextButton(
            onPressed: () async {
              await _authService.deleteUser(user.id!);
              Navigator.pop(context);
              _loadUsers();
            },
            child: Text('delete'.tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
