import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/app_feature.dart';
import '../../../core/models/shift.dart';
import '../../../core/routes/routes.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/shift_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/desktop_tokens.dart';
import '../../../core/widgets/desktop/desktop_scaffold.dart';
import '../../../core/widgets/desktop/desktop_table.dart';
import '../../../core/widgets/desktop/page_header.dart';
import '../../../core/widgets/desktop/responsive.dart';
import '../../../core/widgets/desktop/stat_card.dart';
import '../../../core/widgets/subscription_dialog.dart';

class ShiftManagementScreen extends StatefulWidget {
  const ShiftManagementScreen({super.key});

  @override
  State<ShiftManagementScreen> createState() => _ShiftManagementScreenState();
}

class _ShiftManagementScreenState extends State<ShiftManagementScreen> {
  final _shiftService = sl<ShiftService>();
  final _authService = sl<AuthService>();
  List<Shift> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final user = _authService.currentUser;
    if (user != null) {
      await _shiftService.loadActiveShift(user.id!);
    }
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final history = await _shiftService.getShiftHistory();
    setState(() {
      _history = history;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DesktopScaffold(
      activeNavIndex: -1,
      title: 'shift_management'.tr(),
      onNavigate: _onNavTap,
      body: _buildMobileBody(context),
      desktopBody: _buildDesktopBody(context),
    );
  }

  Widget _buildMobileBody(BuildContext context) {
    return ListenableBuilder(
      listenable: _shiftService,
      builder: (context, _) {
        final current = _shiftService.currentShift;
        return SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCurrentShiftCard(current),
              SizedBox(height: 30.h),
              Text(
                'shift_history'.tr(),
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 15.h),
              _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : _buildHistoryList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopBody(BuildContext context) {
    return ListenableBuilder(
      listenable: _shiftService,
      builder: (context, _) {
        final current = _shiftService.currentShift;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: DesktopMetrics.contentMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeader(
                    title: 'shift_management'.tr(),
                    actions: [
                      FilledButton.icon(
                        onPressed: () => current != null
                            ? _showCloseShiftDialog()
                            : _showOpenShiftDialog(),
                        icon: Icon(
                          current != null
                              ? Icons.lock_outline_rounded
                              : Icons.lock_open_rounded,
                          size: 18,
                        ),
                        label: Text(
                          current != null ? 'close_shift'.tr() : 'open_new_shift'.tr(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.lg),
                  _buildDesktopSummary(current),
                  const SizedBox(height: AppSpace.lg),
                  _buildDesktopHistoryTable(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopSummary(Shift? current) {
    final isOpen = current != null;
    final balancedCount = _history
        .where(
          (s) =>
              s.status == ShiftStatus.closed &&
              (s.closingBalanceActual ?? 0) - (s.closingBalanceSystem ?? 0) == 0,
        )
        .length;

    return ResponsiveGrid(
      columns: 4,
      spacing: AppSpace.lg,
      runSpacing: AppSpace.lg,
      children: [
        StatCard(
          title: isOpen ? 'shift_is_open'.tr() : 'no_active_shift'.tr(),
          value: isOpen ? '${current.openingBalance} YER' : '--',
          icon: isOpen ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
          color: isOpen ? AppColors.success : Colors.grey,
          subtitle: isOpen
              ? '${'started_at'.tr()}: ${DateFormat('HH:mm').format(current.startTime)}'
              : 'open_new_shift'.tr(),
          onTap: () => isOpen ? _showCloseShiftDialog() : _showOpenShiftDialog(),
        ),
        StatCard(
          title: 'shift_history'.tr(),
          value: '${_history.length}',
          icon: Icons.history_rounded,
          color: AppColors.primary,
        ),
        StatCard(
          title: 'open'.tr(),
          value: '${_history.where((s) => s.status == ShiftStatus.open).length}',
          icon: Icons.lock_open_rounded,
          color: AppColors.warning,
        ),
        StatCard(
          title: 'balanced'.tr(),
          value: '$balancedCount',
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.success,
        ),
      ],
    );
  }

  Widget _buildDesktopHistoryTable() {
    final colors = AppColors.of(context);
    return DesktopTable(
      headers: [
        'date'.tr(),
        'opening_balance'.tr(),
        'total'.tr(),
        'status'.tr(),
      ],
      flexes: const [3, 2, 2, 2],
      rows: [
        for (final shift in _history)
          _buildShiftRow(colors, shift),
      ],
      isLoading: _isLoading,
      emptyMessage: 'no_history'.tr(),
    );
  }

  List<Widget> _buildShiftRow(AppColorSet colors, Shift shift) {
    final variance = (shift.closingBalanceActual ?? 0) - (shift.closingBalanceSystem ?? 0);
    final isOpen = shift.status == ShiftStatus.open;

    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('yyyy/MM/dd').format(shift.startTime),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          Text(
            '${DateFormat('HH:mm').format(shift.startTime)} - ${shift.endTime != null ? DateFormat('HH:mm').format(shift.endTime!) : '--'}',
            style: TextStyle(fontSize: 11, color: colors.textSecondary),
          ),
        ],
      ),
      Text('${shift.openingBalance} YER', style: const TextStyle(fontSize: 12)),
      Text(
        shift.closingBalanceActual != null ? '${shift.closingBalanceActual} YER' : '--',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
      isOpen
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                'open'.tr(),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.warning),
              ),
            )
          : variance == 0
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'balanced'.tr(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.success),
                  ),
                )
              : Text(
                  '${variance > 0 ? '+' : ''}$variance',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: variance == 0 ? colors.success : colors.error,
                  ),
                ),
    ];
  }

  Widget _buildCurrentShiftCard(Shift? current) {
    bool isOpen = current != null;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: isOpen ? Colors.green.shade50 : AppColors.surface,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: isOpen ? Colors.green.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(
            isOpen ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
            size: 50.sp,
            color: isOpen ? Colors.green : Colors.grey,
          ),
          SizedBox(height: 16.h),
          Text(
            isOpen ? 'shift_is_open'.tr() : 'no_active_shift'.tr(),
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
          ),
          if (isOpen) ...[
            SizedBox(height: 8.h),
            Text(
              '${'started_at'.tr()}: ${DateFormat('HH:mm').format(current.startTime)}',
              style: TextStyle(color: Colors.grey, fontSize: 14.sp),
            ),
            SizedBox(height: 4.h),
            Text(
              '${'opening_balance'.tr()}: ${current.openingBalance} YER',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
          SizedBox(height: 24.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => isOpen ? _showCloseShiftDialog() : _showOpenShiftDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: isOpen ? Colors.red : AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: Text(isOpen ? 'close_shift'.tr() : 'open_new_shift'.tr()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_history.isEmpty) {
      return Center(child: Text('no_history'.tr(), style: const TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final shift = _history[index];
        final variance = (shift.closingBalanceActual ?? 0) - (shift.closingBalanceSystem ?? 0);
        
        return Card(
          margin: EdgeInsets.only(bottom: 12.h),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          child: ListTile(
            title: Text(DateFormat('yyyy/MM/dd').format(shift.startTime)),
            subtitle: Text('${DateFormat('HH:mm').format(shift.startTime)} - ${shift.endTime != null ? DateFormat('HH:mm').format(shift.endTime!) : '--'}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${shift.closingBalanceActual ?? '--'} YER',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (shift.status == ShiftStatus.closed)
                  Text(
                    variance == 0 ? 'balanced'.tr() : '${variance > 0 ? '+' : ''}$variance',
                    style: TextStyle(
                      color: variance == 0 ? Colors.green : Colors.red,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOpenShiftDialog() {
    final controller = TextEditingController(text: '0');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('open_new_shift'.tr()),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'opening_cash_in_drawer'.tr(),
            suffixText: 'YER',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(controller.text) ?? 0.0;
              await _shiftService.openShift(_authService.currentUser!.id!, val);
              Navigator.pop(context);
              _loadHistory();
            },
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );
  }

  void _showCloseShiftDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('close_shift'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('enter_actual_cash_desc'.tr()),
            SizedBox(height: 16.h),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'actual_cash_counted'.tr(),
                suffixText: 'YER',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(controller.text) ?? 0.0;
              await _shiftService.closeShift(val);
              Navigator.pop(context);
              _loadHistory();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text('confirm_close'.tr()),
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
