import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_feature.dart';

class SubscriptionService {
  static const String _trialStartKey = 'trial_start_date';
  static const String _isSubscribedKey = 'is_subscribed';
  static const int _trialDurationDays = 10;

  final SharedPreferences _prefs;

  SubscriptionService(this._prefs);

  /// Initializes the trial start date if it doesn't exist.
  Future<void> initTrial() async {
    if (!_prefs.containsKey(_trialStartKey)) {
      await _prefs.setString(_trialStartKey, DateTime.now().toIso8601String());
    }
  }

  /// Returns the start date of the trial.
  DateTime? get trialStartDate {
    final dateStr = _prefs.getString(_trialStartKey);
    return dateStr != null ? DateTime.parse(dateStr) : null;
  }

  /// Returns the number of days remaining in the trial.
  int get remainingDays {
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
  }

  /// Central method to check if a feature can be used.
  bool canUseFeature(AppFeature feature) {
    if (isPremiumActive) return true;

    // After expiration, certain features are restricted
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
