import 'package:get_it/get_it.dart';
import 'package:rseed/core/services/shift_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../network/network_info.dart';
import '../api/api_interceptors.dart';
import '../config/app_config.dart';
import '../services/database_helper.dart';
import '../services/customer_service.dart';
import '../services/transaction_service.dart';
import '../services/settings_service.dart';
import '../services/auth_service.dart';
import '../services/product_service.dart';
import '../services/subscription_service.dart';
import '../services/category_service.dart';
import '../services/unit_service.dart';
import '../services/receipt_service.dart';
import '../services/local_backup_service.dart';
import '../services/google_drive_backup_service.dart';
import '../services/supplier_service.dart';
import '../services/supplier_transaction_service.dart';
import '../services/accounting_service.dart';
import '../services/expense_service.dart';
import '../services/procurement_service.dart';
import '../../features/reports/services/report_service.dart';
import '../../features/reports/services/export_service.dart';
import '../../features/reports/bloc/reports_bloc.dart';
import '../services/printer_service.dart';
import '../services/fiscal_year_service.dart';

final sl = GetIt.instance;

/// Initialize Dependency Injection
Future<void> init() async {
  //! Core
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));

  //! External
  sl.registerLazySingleton(() => InternetConnectionChecker.createInstance());

  sl.registerLazySingleton(() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(ApiInterceptor());

    if (AppConfig.enableLogging) {
      dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseHeader: true,
        ),
      );
    }

    return dio;
  });

  //! SharedPreferences (must be initialized before services that depend on it)
  final sharedPrefs = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => sharedPrefs);

  //! Services
  sl.registerLazySingleton(() => DatabaseHelper.instance);
  sl.registerLazySingleton(() => CustomerService());
  sl.registerLazySingleton(() => SupplierService());
  sl.registerLazySingleton(() => SupplierTransactionService());
  sl.registerLazySingleton(() => AccountingService());
  sl.registerLazySingleton(() => SettingsService());
  sl.registerLazySingleton<SubscriptionService>(() => SubscriptionService(sl<SharedPreferences>()));
  sl.registerLazySingleton<TransactionService>(() => TransactionService(sl<CustomerService>(), sl<SettingsService>()));
  sl.registerLazySingleton<ProductService>(() => ProductService(sl<TransactionService>()));
  sl.registerLazySingleton(() => ExpenseService());
  sl.registerLazySingleton(() => ProcurementService());

  // Auth
  sl.registerLazySingleton<GoogleSignIn>(() => GoogleSignIn(
    serverClientId: '406414577926-qb5rvqqaecah94e52l0de7924dhipga1.apps.googleusercontent.com',
    scopes: [
      'email',
      'https://www.googleapis.com/auth/drive.file',
      'https://www.googleapis.com/auth/drive.appdata'
    ],
  ));
  sl.registerLazySingleton<AuthService>(() => AuthService(sl<SubscriptionService>(), sl<GoogleSignIn>(), sl<SharedPreferences>()));
  sl.registerLazySingleton(() => ShiftService());
  sl.registerLazySingleton(() => FiscalYearService());

  //! Backup Services
  sl.registerLazySingleton<LocalBackupService>(() => LocalBackupService(sl<SharedPreferences>()));
  sl.registerLazySingleton<GoogleDriveBackupService>(
    () => GoogleDriveBackupService(sl<SharedPreferences>(), sl<LocalBackupService>(), sl<AuthService>()),
  );

  //! Store Services
  sl.registerLazySingleton<CategoryService>(() => CategoryService());
  sl.registerLazySingleton<UnitService>(() => UnitService());
  sl.registerLazySingleton<ReceiptService>(() => ReceiptService());
  sl.registerLazySingleton<PrinterService>(() => PrinterService());

  //! Reports
  sl.registerLazySingleton(() => ReportService());
  sl.registerLazySingleton(() => ExportService());
  sl.registerFactory(() => ReportsBloc(sl<ReportService>()));
}
