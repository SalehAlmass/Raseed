enum DebtMode { block, warning }

class AppSettings {
  final double maxDebt;
  final int reminderDays;
  final bool strictMode; // Keep for backward compatibility or as general toggle
  final DebtMode debtMode;
  final String currency;
  final bool onboardingCompleted;
  final double vipThreshold;
  final int inactiveDays;
  final int deadDays;

  AppSettings({
    this.maxDebt = 1000.0,
    this.reminderDays = 30,
    this.strictMode = false,
    this.debtMode = DebtMode.block,
    this.currency = 'YER',
    this.onboardingCompleted = false,
    this.vipThreshold = 100000.0,
    this.inactiveDays = 30,
    this.deadDays = 90,
  });

  Map<String, dynamic> toMap() {
    return {
      'max_debt': maxDebt,
      'reminder_days': reminderDays,
      'strict_mode': strictMode ? 1 : 0,
      'debt_mode': debtMode.name,
      'currency': currency,
      'onboarding_completed': onboardingCompleted ? 1 : 0,
      'vip_threshold': vipThreshold,
      'inactive_days': inactiveDays,
      'dead_days': deadDays,
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
      vipThreshold: (map['vip_threshold'] as num?)?.toDouble() ?? 100000.0,
      inactiveDays: map['inactive_days'] ?? 30,
      deadDays: map['dead_days'] ?? 90,
    );
  }

  AppSettings copyWith({
    double? maxDebt,
    int? reminderDays,
    bool? strictMode,
    DebtMode? debtMode,
    String? currency,
    bool? onboardingCompleted,
    double? vipThreshold,
    int? inactiveDays,
    int? deadDays,
  }) {
    return AppSettings(
      maxDebt: maxDebt ?? this.maxDebt,
      reminderDays: reminderDays ?? this.reminderDays,
      strictMode: strictMode ?? this.strictMode,
      debtMode: debtMode ?? this.debtMode,
      currency: currency ?? this.currency,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      vipThreshold: vipThreshold ?? this.vipThreshold,
      inactiveDays: inactiveDays ?? this.inactiveDays,
      deadDays: deadDays ?? this.deadDays,
    );
  }
}
