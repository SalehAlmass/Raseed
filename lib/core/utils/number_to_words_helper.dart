class NumberToWordsArabic {
  NumberToWordsArabic._();

  static const List<String> ones = [
    "", "واحد", "اثنان", "ثلاثة", "أربعة", "خمسة", "ستة", "سبعة", "ثمانية", "تسعة"
  ];
  
  static const List<String> tens = [
    "", "عشرة", "عشرون", "ثلاثون", "أربعون", "خمسون", "ستون", "سبعون", "ثمانون", "تسعون"
  ];

  static const List<String> hundreds = [
    "", "مائة", "مائتان", "ثلاثمائة", "أربعمائة", "خمسمائة", "ستمائة", "سبعمائة", "ثمانمائة", "تسعمائة"
  ];

  static String convert(int number) {
    if (number == 0) return "صفر";
    return _convertHelper(number).trim();
  }
  
  static String _convertHelper(int number) {
    if (number < 0) return "سالب ${_convertHelper(-number)}";
    
    String word = "";
    
    if (number >= 1000000000) {
      int bill = number ~/ 1000000000;
      int rem = number % 1000000000;
      if (bill == 1) {
        word += "مليار";
      } else if (bill == 2) {
        word += "ملياران";
      } else if (bill <= 10) {
        word += "${_convertHelper(bill)} مليارات";
      } else {
        word += "${_convertHelper(bill)} مليار";
      }
      if (rem > 0) word += " و ${_convertHelper(rem)}";
    } else if (number >= 1000000) {
      int mill = number ~/ 1000000;
      int rem = number % 1000000;
      if (mill == 1) {
        word += "مليون";
      } else if (mill == 2) {
        word += "مليونان";
      } else if (mill <= 10) {
        word += "${_convertHelper(mill)} ملايين";
      } else {
        word += "${_convertHelper(mill)} مليون";
      }
      if (rem > 0) word += " و ${_convertHelper(rem)}";
    } else if (number >= 1000) {
      int thous = number ~/ 1000;
      int rem = number % 1000;
      if (thous == 1) {
        word += "ألف";
      } else if (thous == 2) {
        word += "ألفان";
      } else if (thous <= 10) {
        word += "${_convertHelper(thous)} آلاف";
      } else {
        word += "${_convertHelper(thous)} ألف";
      }
      if (rem > 0) word += " و ${_convertHelper(rem)}";
    } else if (number >= 100) {
      int hund = number ~/ 100;
      int rem = number % 100;
      word += hundreds[hund];
      if (rem > 0) word += " و ${_convertHelper(rem)}";
    } else if (number >= 20) {
      int ten = number ~/ 10;
      int one = number % 10;
      if (one > 0) {
        word += "${ones[one]} و ${tens[ten]}";
      } else {
        word += tens[ten];
      }
    } else if (number >= 11) {
      int one = number % 10;
      if (one == 1) {
        word += "أحد عشر";
      } else if (one == 2) {
        word += "اثنا عشر";
      } else {
        word += "${ones[one]} عشر";
      }
    } else if (number >= 1) {
      word += ones[number];
    }
    
    return word;
  }

  static String convertToWords(double amount, String currencyCode) {
    int wholePart = amount.floor();
    int decimalPart = ((amount - wholePart) * 100).round();
    
    String currencyName = "ريال";
    String coinName = "فلس";
    
    if (currencyCode.toUpperCase() == 'SAR') {
      currencyName = "ريال سعودي";
      coinName = "هللة";
    } else if (currencyCode.toUpperCase() == 'YER') {
      currencyName = "ريال يمني";
      coinName = "فلس";
    } else if (currencyCode.toUpperCase() == 'USD') {
      currencyName = "دولار أمريكي";
      coinName = "سنت";
    }
    
    String result = "";
    if (wholePart == 0) {
      result = "صفر $currencyName";
    } else {
      String wholeWords = convert(wholePart);
      result = "$wholeWords $currencyName";
    }
    
    if (decimalPart > 0) {
      String decimalWords = convert(decimalPart);
      result += " و $decimalWords $coinName";
    }
    
    return "$result فقط لا غير";
  }
}
