import 'package:shared_preferences/shared_preferences.dart';

class LocalPreferencesStore {
  LocalPreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  static const _themeKey = 'app.theme';
  static const _languageKey = 'app.language';
  static const _manualSeenKey = 'app.manualSeen';
  static const _expenseNotificationsKey = 'notifications.expense';
  static const _refundNotificationsKey = 'notifications.refund';
  static const _requestNotificationsKey = 'notifications.request';

  String getThemeId() => _prefs.getString(_themeKey) ?? 'light';
  String getLanguageCode() => _prefs.getString(_languageKey) ?? 'es';
  bool getHasSeenManual() => _prefs.getBool(_manualSeenKey) ?? false;
  bool getExpenseNotificationsEnabled() => _prefs.getBool(_expenseNotificationsKey) ?? true;
  bool getRefundNotificationsEnabled() => _prefs.getBool(_refundNotificationsKey) ?? true;
  bool getRefundRequestNotificationsEnabled() => _prefs.getBool(_requestNotificationsKey) ?? true;

  Future<void> setThemeId(String value) => _prefs.setString(_themeKey, value);
  Future<void> setLanguageCode(String value) => _prefs.setString(_languageKey, value);
  Future<void> setHasSeenManual(bool value) => _prefs.setBool(_manualSeenKey, value);
  Future<void> setExpenseNotificationsEnabled(bool value) => _prefs.setBool(_expenseNotificationsKey, value);
  Future<void> setRefundNotificationsEnabled(bool value) => _prefs.setBool(_refundNotificationsKey, value);
  Future<void> setRefundRequestNotificationsEnabled(bool value) => _prefs.setBool(_requestNotificationsKey, value);
}