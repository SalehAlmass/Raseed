import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/routes/routes.dart';

class MasterPasswordScreen extends StatefulWidget {
  const MasterPasswordScreen({super.key});

  @override
  State<MasterPasswordScreen> createState() => _MasterPasswordScreenState();
}

class _MasterPasswordScreenState extends State<MasterPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = sl<AuthService>();
  bool _obscureText = true;
  String? _errorText;

  void _verifyPassword() async {
    final isValid = await _authService.verifyPassword(_passwordController.text);
    if (isValid) {
      if (mounted) {
        final settings = await sl<SettingsService>().getSettings();
        if (!settings.onboardingCompleted) {
          Navigator.pushReplacementNamed(context, Routes.onboarding);
        } else {
          Navigator.pushReplacementNamed(context, Routes.home);
        }
      }
    } else {
      setState(() {
        _errorText = 'incorrect_password'.tr();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 30.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeInDown(
                child: Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_person_outlined,
                    color: AppColors.primary,
                    size: 80.sp,
                  ),
                ),
              ),
              SizedBox(height: 40.h),
              FadeInUp(
                delay: const Duration(milliseconds: 200),
                child: Text(
                  'enter_master_password'.tr(),
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              FadeInUp(
                delay: const Duration(milliseconds: 300),
                child: Text(
                  'access_restricted'.tr(),
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              SizedBox(height: 50.h),
              FadeInUp(
                delay: const Duration(milliseconds: 400),
                child: TextField(
                  controller: _passwordController,
                  obscureText: _obscureText,
                  style: TextStyle(fontSize: 18.sp, letterSpacing: 2),
                  decoration: InputDecoration(
                    hintText: '******',
                    errorText: _errorText,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => setState(() => _obscureText = !_obscureText),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15.r),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 30.h),
              FadeInUp(
                delay: const Duration(milliseconds: 500),
                child: SizedBox(
                  width: double.infinity,
                  height: 55.h,
                  child: ElevatedButton(
                    onPressed: _verifyPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.r),
                      ),
                    ),
                    child: Text(
                      'unlock'.tr(),
                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
