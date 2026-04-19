/// Application Configuration
class AppConfig {
  AppConfig._();

  static const String appName = 'Flutter Raseed App';
  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';

  // Developer Info
  static const String developerName = 'Saleh Al-Mass';
  static const String developerGithub = 'https://github.com/SalehAlMass';
  static const String developerProfile = 'salehalmass.com';
  static const String developerLinkedIn =
      'https://www.linkedin.com/in/salehalmass';
  static const String developerEmail = 'salehalmass18@gmail.com';
  static const String developerWhatsApp = 'https://wa.me/00967777359678';
  // Environment
  static const bool isProduction = false;
  static const bool enableLogging = true;

  // API Configuration
  static String get baseUrl {
    return isProduction
        ? 'https://api.production.com'
        : 'https://api.development.com';
  }
}
