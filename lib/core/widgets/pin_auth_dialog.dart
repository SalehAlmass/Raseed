import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:rseed/core/theme/colors.dart';


class PinAuthDialog extends StatefulWidget {
  final String correctPin;

  const PinAuthDialog({Key? key, required this.correctPin}) : super(key: key);

  @override
  State<PinAuthDialog> createState() => _PinAuthDialogState();
}

class _PinAuthDialogState extends State<PinAuthDialog> {
  final TextEditingController _pinController = TextEditingController();
  String _errorText = '';

  void _verifyPin() {
    if (_pinController.text == widget.correctPin) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _errorText = 'incorrect_password'.tr();
        _pinController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      title: Column(
        children: [
          Icon(Icons.lock_person_rounded, size: 50.sp, color: AppColors.primary),
          SizedBox(height: 10.h),
          Text(
            'enter_master_password'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            autofocus: true,
            style: TextStyle(fontSize: 24.sp, letterSpacing: 10.w),
            decoration: InputDecoration(
              counterText: '',
              errorText: _errorText.isEmpty ? null : _errorText,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15.r)),
            ),
            onSubmitted: (_) => _verifyPin(),
          ),
          SizedBox(height: 10.h),
          Text(
            'access_restricted'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.sp, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: _verifyPin,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
          ),
          child: Text('unlock'.tr(), style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
