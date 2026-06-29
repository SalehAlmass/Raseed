import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:rseed/core/services/settings_service.dart';
import 'core/routes/app_router.dart';
import 'core/routes/routes.dart';
import 'core/theme/app_theme.dart';
import 'core/services/theme_service.dart';
import 'core/di/injection_container.dart' as di;
import 'core/localization/localization_manager.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'core/services/subscription_service.dart';
import 'package:timeago/timeago.dart' as timeago;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  Locale savedLocale = const Locale('ar');

  try {
    await EasyLocalization.ensureInitialized();
  } catch (e) {
    debugPrint('EasyLocalization initialization failed: $e');
  }

  try {
    await di.init();
  } catch (e) {
    debugPrint('Dependency Injection failed: $e');
  }

  try {
    if (di.sl.isRegistered<SubscriptionService>()) {
      await di.sl<SubscriptionService>().initTrial();
    }
  } catch (e) {
    debugPrint('SubscriptionService initialization failed: $e');
  }

  try {
    if (di.sl.isRegistered<SettingsService>()) {
      final settings = await di.sl<SettingsService>().getSettings();
      savedLocale = Locale(settings.languageCode);
    }
  } catch (e) {
    debugPrint('SettingsService loading failed: $e');
  }

  timeago.setLocaleMessages('ar', timeago.ArMessages());

  runApp(
    EasyLocalization(
      supportedLocales: LocalizationManager.supportedLocales,
      path: LocalizationManager.translationsPath,
      fallbackLocale: LocalizationManager.fallbackLocale,
      startLocale: savedLocale,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = di.sl<ThemeService>();

    return ListenableBuilder(
      listenable: themeService,
      builder: (context, child) {
        return ScreenUtilInit(
          designSize: const Size(375, 812),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) {
            return MaterialApp(
              title: 'تاجر ماس',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeService.themeMode,
              initialRoute: Routes.splash,
              onGenerateRoute: AppRouter.generateRoute,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
            );
          },
        );
      },
    );
  }
}
