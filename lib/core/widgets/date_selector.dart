import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../theme/colors.dart';

class DateSelector extends StatefulWidget {
  final DateTime initialDate;
  final Function(DateTime) onDateSelected;

  const DateSelector({
    super.key,
    required this.initialDate,
    required this.onDateSelected,
  });

  @override
  State<DateSelector> createState() => _DateSelectorState();
}

class _DateSelectorState extends State<DateSelector> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (date != null) {
          setState(() => _selectedDate = date);
          widget.onDateSelected(date);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 15.h),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
            SizedBox(width: 10.w),
            Text(
              DateFormat('MMMM dd, yyyy').format(_selectedDate),
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp),
            ),
            const Spacer(),
            Icon(Icons.edit, color: Colors.grey.withOpacity(0.5), size: 16),
          ],
        ),
      ),
    );
  }
}
