import 'package:intl/intl.dart';

class CurrencyHelper {
  static String getSymbol(String code) {
    switch (code) {
      case 'SAR':
        return 'ر.س';
      case 'YER':
      default:
        return 'ر.ي';
    }
  }

  static NumberFormat getFormatter(String code) {
    return NumberFormat.currency(
      symbol: '${getSymbol(code)} ',
      decimalDigits: 0,
    );
  }
}
