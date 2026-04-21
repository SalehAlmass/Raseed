import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
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
import '../services/backup_service.dart';
import '../services/category_service.dart';
import '../services/unit_service.dart';
import '../services/google_drive_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../features/reports/services/report_service.dart';
import '../../features/reports/services/export_service.dart';
import '../../features/reports/bloc/reports_bloc.dart';

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

    // Add pretty logger in debug mode
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

  //! Services
  sl.registerLazySingleton(() => DatabaseHelper.instance);
  sl.registerLazySingleton(() => CustomerService());
  sl.registerLazySingleton<TransactionService>(() => TransactionService(sl<CustomerService>(), sl<SettingsService>()));
  sl.registerLazySingleton(() => SettingsService());

  sl.registerLazySingleton<GoogleSignIn>(() => GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/drive.file',
      'email',
    ],
  ));

  sl.registerLazySingleton<AuthService>(() => AuthService(sl<SubscriptionService>(), sl<GoogleSignIn>()));
  sl.registerLazySingleton<ProductService>(() => ProductService(sl<TransactionService>()));

  final sharedPrefs = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => sharedPrefs);
  sl.registerLazySingleton<SubscriptionService>(() => SubscriptionService(sl<SharedPreferences>()));
  
  sl.registerLazySingleton<GoogleDriveService>(() => GoogleDriveService(sl<GoogleSignIn>()));
  sl.registerLazySingleton<BackupService>(() => BackupService(sl<SharedPreferences>(), sl<GoogleDriveService>()));
  
  sl.registerLazySingleton<CategoryService>(() => CategoryService());
  sl.registerLazySingleton<UnitService>(() => UnitService());

  //! Reports
  sl.registerLazySingleton(() => ReportService());
  sl.registerLazySingleton(() => ExportService());
  sl.registerFactory(() => ReportsBloc(sl<ReportService>()));
}
