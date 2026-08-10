import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/desktop_tokens.dart';
import '../../../core/routes/routes.dart';

class MasterPasswordScreen extends StatefulWidget {
  const MasterPasswordScreen({super.key});

  @override
  State<MasterPasswordScreen> createState() => _MasterPasswordScreenState();
}

class _MasterPasswordScreenState extends State<MasterPasswordScreen> {
  final TextEditingController _usernameController = TextEditingController(text: 'admin');
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = sl<AuthService>();
  bool _obscureText = true;
  String? _errorText;
  bool _isLoading = false;

  void _handleLogin() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorText = 'please_fill_all_fields'.tr());
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final success = await _authService.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (success) {
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
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= AppBreakpoints.tablet;
            if (!isDesktop) {
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 50.h),
                child: _buildFormContent(),
              );
            }
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpace.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpace.xxl),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: colors.border),
                      boxShadow: AppShadow.soft(Colors.black),
                    ),
                    child: _buildFormContent(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FadeInDown(
          child: Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
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
            'staff_login'.tr(),
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.of(context).textPrimary,
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
              color: AppColors.of(context).textSecondary,
            ),
          ),
        ),
        SizedBox(height: 40.h),
        FadeInUp(
          delay: const Duration(milliseconds: 400),
          child: TextField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: 'username'.tr(),
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15.r),
              ),
            ),
          ),
        ),
        SizedBox(height: 16.h),
        FadeInUp(
          delay: const Duration(milliseconds: 450),
          child: TextField(
            controller: _passwordController,
            obscureText: _obscureText,
            style: TextStyle(fontSize: 18.sp),
            decoration: InputDecoration(
              labelText: 'password'.tr(),
              prefixIcon: const Icon(Icons.lock_outline),
              errorText: _errorText,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.of(context).textSecondary,
                ),
                onPressed: () => setState(() => _obscureText = !_obscureText),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15.r),
              ),
            ),
            onSubmitted: (_) => _handleLogin(),
          ),
        ),
        SizedBox(height: 30.h),
        FadeInUp(
          delay: const Duration(milliseconds: 500),
          child: SizedBox(
            width: double.infinity,
            height: 55.h,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.r),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      'login_btn'.tr(),
                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
