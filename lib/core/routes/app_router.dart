import 'package:flutter/material.dart';
import 'routes.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/home/views/home_screen.dart';
import '../../features/customers/views/customer_list_screen.dart';
import '../../features/customers/views/customer_detail_screen.dart';
import '../../features/settings/views/settings_screen.dart';
import '../../features/auth/views/master_password_screen.dart';
import '../../features/store/views/store_screen.dart';
import '../../features/home/views/sale_screen.dart';
import '../models/customer.dart';
import '../models/app_transaction.dart';
import '../../features/reports/views/reports_dashboard_screen.dart';
import '../../features/reports/bloc/reports_bloc.dart';
import '../di/injection_container.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/about/views/about_screen.dart';

/// Application Router
class AppRouter {
  AppRouter._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.splash:
        return _buildRoute(const SplashScreen(), settings);
      case Routes.onboarding:
        return _buildRoute(const OnboardingScreen(), settings);
      case Routes.home:
        return _buildRoute(const HomeScreen(), settings);
      case Routes.customers:
        return _buildRoute(const CustomerListScreen(), settings);
      case Routes.customerDetail:
        final customer = settings.arguments as Customer;
        return _buildRoute(CustomerDetailScreen(customer: customer), settings);
      case Routes.settings:
        return _buildRoute(const SettingsScreen(), settings);
      case Routes.auth:
        return _buildRoute(const MasterPasswordScreen(), settings);
      case Routes.store:
        return _buildRoute(const StoreScreen(), settings);
      case Routes.sale:
        final type = settings.arguments as TransactionType? ?? TransactionType.sale;
        return _buildRoute(SaleScreen(initialType: type), settings);
      case Routes.reports:
        return _buildRoute(
          BlocProvider(
            create: (context) => sl<ReportsBloc>(),
            child: const ReportsDashboardScreen(),
          ),
          settings,
        );
      case Routes.about:
        return _buildRoute(const AboutScreen(), settings);
      default:
        return _buildRoute(
          Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
          settings,
        );
    }
  }

  static PageRouteBuilder _buildRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));

        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  static void navigateTo(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    Navigator.pushNamed(context, routeName, arguments: arguments);
  }

  static void navigateAndReplace(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    Navigator.pushReplacementNamed(context, routeName, arguments: arguments);
  }

  static void navigateAndRemoveUntil(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      routeName,
      (route) => false,
      arguments: arguments,
    );
  }

  static void goBack(BuildContext context) {
    Navigator.pop(context);
  }
}
