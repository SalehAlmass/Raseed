import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/shift.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/shift_service.dart';
import '../../../core/theme/colors.dart';

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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('shift_management'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListenableBuilder(
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
      ),
    );
  }

  Widget _buildCurrentShiftCard(Shift? current) {
    bool isOpen = current != null;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: isOpen ? Colors.green.shade50 : AppColors.surface,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: isOpen ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.2)),
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
}
