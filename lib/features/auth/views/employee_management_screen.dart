import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/app_feature.dart';
import '../../../core/models/user.dart';
import '../../../core/routes/routes.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/desktop_tokens.dart';
import '../../../core/widgets/desktop/desktop_scaffold.dart';
import '../../../core/widgets/desktop/desktop_table.dart';
import '../../../core/widgets/desktop/page_header.dart';
import '../../../core/widgets/subscription_dialog.dart';

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
    return DesktopScaffold(
      activeNavIndex: -1,
      title: 'employee_management'.tr(),
      onNavigate: _onNavTap,
      body: _buildMobileBody(context),
      desktopBody: _buildDesktopBody(context),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddUserDialog(),
        label: Text('add_employee'.tr()),
        icon: const Icon(Icons.person_add_rounded),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildMobileBody(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: _users.length,
            itemBuilder: (context, index) {
              final user = _users[index];
              return _buildUserCard(user);
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
                title: 'employee_management'.tr(),
                subtitle: '${_users.length}',
                actions: [
                  FilledButton.icon(
                    onPressed: () => _showAddUserDialog(),
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: Text('add_employee'.tr()),
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
    final colors = AppColors.of(context);
    return DesktopTable(
      headers: [
        'name'.tr(),
        'username'.tr(),
        'role'.tr(),
        'status'.tr(),
        '',
      ],
      flexes: const [3, 2, 2, 2, 1],
      rows: [
        for (final user in _users)
          _buildUserRow(colors, user),
      ],
      isLoading: _isLoading,
    );
  }

  List<Widget> _buildUserRow(AppColorSet colors, AppUser user) {
    final roleColor = _roleColor(user.role);
    return [
      Text(
        user.name,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      Text('@${user.username}', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs, vertical: 2),
        decoration: BoxDecoration(
          color: roleColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          user.role.name.tr(),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: roleColor),
        ),
      ),
      Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: colors.success, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpace.xs),
          Text('active'.tr(), style: TextStyle(fontSize: 12, color: colors.success)),
        ],
      ),
      user.id == 1
          ? const Icon(Icons.admin_panel_settings, size: 18, color: Colors.grey)
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'delete'.tr(),
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmDelete(user),
                ),
              ],
            ),
    ];
  }

  Widget _buildUserCard(AppUser user) {
    Color roleColor = _roleColor(user.role);

    return Card(
      elevation: 0,
      margin: EdgeInsets.only(bottom: 12.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(16.w),
        leading: CircleAvatar(
          backgroundColor: roleColor.withValues(alpha: 0.1),
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
                color: roleColor.withValues(alpha: 0.1),
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

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.admin: return Colors.purple;
      case UserRole.cashier: return Colors.blue;
      case UserRole.warehouse: return Colors.orange;
    }
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
