import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_feature.dart';

class SubscriptionService {
  static const String _trialStartKey = 'trial_start_date';
  static const String _lastUsedDateKey = 'last_used_date';
  static const String _isSubscribedKey = 'is_subscribed';
  static const String _isTamperedKey = 'is_clock_tampered';
  static const int _trialDurationDays = 10;

  final SharedPreferences _prefs;

  SubscriptionService(this._prefs);

  /// Initializes the trial and handles anti-tamper logic.
  Future<void> initTrial() async {
    final now = DateTime.now();
    
    // 1. Initialize trial start date if not exists
    if (!_prefs.containsKey(_trialStartKey)) {
      await _prefs.setString(_trialStartKey, now.toIso8601String());
    }

    // 2. Check for clock tampering (Method 2)
    final lastUsedStr = _prefs.getString(_lastUsedDateKey);
    if (lastUsedStr != null) {
      final lastUsed = DateTime.parse(lastUsedStr);
      if (now.isBefore(lastUsed)) {
        // User moved the clock backwards!
        await _prefs.setBool(_isTamperedKey, true);
      }
    }

    // 3. Update last used date if current time is ahead
    if (!isClockTampered) {
      await _prefs.setString(_lastUsedDateKey, now.toIso8601String());
    }
  }

  /// Returns true if the user tried to cheat by changing the system clock.
  bool get isClockTampered => _prefs.getBool(_isTamperedKey) ?? false;

  /// Returns the start date of the trial.
  DateTime? get trialStartDate {
    final dateStr = _prefs.getString(_trialStartKey);
    return dateStr != null ? DateTime.parse(dateStr) : null;
  }

  /// Returns the number of days remaining in the trial.
  int get remainingDays {
    if (isClockTampered) return 0; // Lock if tampering detected

    final start = trialStartDate;
    if (start == null) return _trialDurationDays;
    
    final difference = DateTime.now().difference(start).inDays;
    final remaining = _trialDurationDays - difference;
    return remaining < 0 ? 0 : remaining;
  }

  /// Returns true if the trial is still active or the user is subscribed.
  bool get isPremiumActive {
    return isSubscribed || remainingDays > 0;
  }

  /// Returns true if the user has a paid subscription.
  bool get isSubscribed {
    return _prefs.getBool(_isSubscribedKey) ?? false;
  }

  /// Simulates activating a subscription.
  Future<void> activateSubscription() async {
    await _prefs.setBool(_isSubscribedKey, true);
    await _prefs.setBool(_isTamperedKey, false); // Clear tamper on real sub
  }

  /// Central method to check if a feature can be used.
  bool canUseFeature(AppFeature feature) {
    if (isPremiumActive) return true;

    // After expiration or tampering, certain features are restricted
    switch (feature) {
      case AppFeature.addCustomer:
      case AppFeature.addSale:
      case AppFeature.editInventory:
      case AppFeature.viewReports:
        return false;
      default:
        return true;
    }
  }
}
