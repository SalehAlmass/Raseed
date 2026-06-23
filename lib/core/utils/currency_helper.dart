import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';

class CurrencyHelper {
  static String getSymbol(String code) {
    if (code.toUpperCase() == 'YER') {
      return 'currency_symbol_yer'.tr();
    }
    return code;
  }

  static NumberFormat getFormatter(String code) {
    return NumberFormat.currency(
      symbol: '${getSymbol(code)} ',
      decimalDigits: 0,
    );
  }
}
