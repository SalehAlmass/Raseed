enum DebtMode { block, warning }

class AppSettings {
  final double maxDebt;
  final int reminderDays;
  final bool strictMode; // Keep for backward compatibility or as general toggle
  final DebtMode debtMode;
  final String currency;
  final bool onboardingCompleted;

  AppSettings({
    this.maxDebt = 1000.0,
    this.reminderDays = 30,
    this.strictMode = false,
    this.debtMode = DebtMode.block,
    this.currency = 'YER',
    this.onboardingCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'max_debt': maxDebt,
      'reminder_days': reminderDays,
      'strict_mode': strictMode ? 1 : 0,
      'debt_mode': debtMode.name,
      'currency': currency,
      'onboarding_completed': onboardingCompleted ? 1 : 0,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      maxDebt: (map['max_debt'] as num?)?.toDouble() ?? 1000.0,
      reminderDays: map['reminder_days'] ?? 30,
      strictMode: (map['strict_mode'] ?? 0) == 1,
      debtMode: map['debt_mode'] != null 
          ? DebtMode.values.byName(map['debt_mode']) 
          : DebtMode.block,
      currency: map['currency'] ?? 'YER',
      onboardingCompleted: (map['onboarding_completed'] ?? 0) == 1,
    );
  }

  AppSettings copyWith({
    double? maxDebt,
    int? reminderDays,
    bool? strictMode,
    DebtMode? debtMode,
    String? currency,
    bool? onboardingCompleted,
  }) {
    return AppSettings(
      maxDebt: maxDebt ?? this.maxDebt,
      reminderDays: reminderDays ?? this.reminderDays,
      strictMode: strictMode ?? this.strictMode,
      debtMode: debtMode ?? this.debtMode,
      currency: currency ?? this.currency,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }
}
