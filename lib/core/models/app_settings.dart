class AppSettings {
  final double maxDebt;
  final int reminderDays;
  final bool strictMode;
  final String currency;
  final bool onboardingCompleted;

  AppSettings({
    this.maxDebt = 1000.0,
    this.reminderDays = 30,
    this.strictMode = false,
    this.currency = 'YER',
    this.onboardingCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'max_debt': maxDebt,
      'reminder_days': reminderDays,
      'strict_mode': strictMode ? 1 : 0,
      'currency': currency,
      'onboarding_completed': onboardingCompleted ? 1 : 0,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      maxDebt: (map['max_debt'] as num?)?.toDouble() ?? 1000.0,
      reminderDays: map['reminder_days'] ?? 30,
      strictMode: (map['strict_mode'] ?? 0) == 1,
      currency: map['currency'] ?? 'YER',
      onboardingCompleted: (map['onboarding_completed'] ?? 0) == 1,
    );
  }

  AppSettings copyWith({
    double? maxDebt,
    int? reminderDays,
    bool? strictMode,
    String? currency,
    bool? onboardingCompleted,
  }) {
    return AppSettings(
      maxDebt: maxDebt ?? this.maxDebt,
      reminderDays: reminderDays ?? this.reminderDays,
      strictMode: strictMode ?? this.strictMode,
      currency: currency ?? this.currency,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }
}
