import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/donation_policy.dart';
import 'preferences.dart';

/// Persistencia de los ajustes de la app.
///
/// Todo lo que guarda cabe en `SharedPreferences`: son unos pocos escalares,
/// no hay motivo para montar una base de datos. Lo importante es que la lista
/// de claves esté en un único sitio, porque es la misma lista que viaja en la
/// copia de seguridad.
class LocalPreferencesStore {
  LocalPreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  static const themeKey = 'app.theme';
  static const themeModeKey = 'app.themeMode';
  static const languageKey = 'app.language';
  static const manualSeenKey = 'app.manualSeen';
  static const expenseNotificationsKey = 'notifications.expense';
  static const refundNotificationsKey = 'notifications.refund';
  static const requestNotificationsKey = 'notifications.request';
  static const donationKey = 'donation.state';

  /// Claves que se exportan y se restauran.
  static const backupKeys = <String>[
    themeKey,
    themeModeKey,
    languageKey,
    manualSeenKey,
    expenseNotificationsKey,
    refundNotificationsKey,
    requestNotificationsKey,
    donationKey,
  ];

  String getThemeId() => _prefs.getString(themeKey) ?? 'light';

  AppThemeMode getThemeMode() {
    final raw = _prefs.getString(themeModeKey);
    return AppThemeMode.values.firstWhere(
      (mode) => mode.name == raw,
      // Sin preferencia guardada se sigue al sistema: es lo que la gente
      // espera de una app moderna y lo que pide el ajuste de accesibilidad.
      orElse: () => AppThemeMode.system,
    );
  }

  String getLanguageCode() => _prefs.getString(languageKey) ?? 'es';
  bool getHasSeenManual() => _prefs.getBool(manualSeenKey) ?? false;
  bool getExpenseNotificationsEnabled() => _prefs.getBool(expenseNotificationsKey) ?? true;
  bool getRefundNotificationsEnabled() => _prefs.getBool(refundNotificationsKey) ?? true;
  bool getRefundRequestNotificationsEnabled() => _prefs.getBool(requestNotificationsKey) ?? true;

  DonationState getDonationState() {
    final raw = _prefs.getString(donationKey);
    if (raw == null || raw.isEmpty) {
      return const DonationState();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return DonationState.fromJson(Map<String, Object?>.from(decoded));
      }
    } on FormatException {
      // Un ajuste corrupto no puede impedir que la app arranque.
    }
    return const DonationState();
  }

  /// Lee todos los ajustes de una vez.
  AppPreferences read() {
    return AppPreferences(
      themeId: getThemeId(),
      themeMode: getThemeMode(),
      languageCode: getLanguageCode(),
      hasSeenManual: getHasSeenManual(),
      expenseNotificationsEnabled: getExpenseNotificationsEnabled(),
      refundNotificationsEnabled: getRefundNotificationsEnabled(),
      refundRequestNotificationsEnabled: getRefundRequestNotificationsEnabled(),
      donation: getDonationState(),
    );
  }

  Future<void> setThemeId(String value) => _prefs.setString(themeKey, value);
  Future<void> setThemeMode(String value) => _prefs.setString(themeModeKey, value);
  Future<void> setLanguageCode(String value) => _prefs.setString(languageKey, value);
  Future<void> setHasSeenManual(bool value) => _prefs.setBool(manualSeenKey, value);
  Future<void> setExpenseNotificationsEnabled(bool value) => _prefs.setBool(expenseNotificationsKey, value);
  Future<void> setRefundNotificationsEnabled(bool value) => _prefs.setBool(refundNotificationsKey, value);
  Future<void> setRefundRequestNotificationsEnabled(bool value) => _prefs.setBool(requestNotificationsKey, value);
  Future<void> setDonationState(DonationState value) => _prefs.setString(donationKey, jsonEncode(value.toJson()));

  /// Ajustes en forma de mapa, para meterlos en la copia de seguridad.
  Map<String, Object?> toBackupMap() {
    final values = <String, Object?>{};
    for (final key in backupKeys) {
      final value = _prefs.get(key);
      if (value != null) {
        values[key] = value;
      }
    }
    return values;
  }

  /// Restaura los ajustes de una copia.
  ///
  /// Solo se aceptan las claves conocidas y solo con el tipo que les
  /// corresponde: una copia manipulada no puede meter basura en los ajustes.
  Future<void> restoreFromBackup(Map<String, Object?> values) async {
    for (final key in backupKeys) {
      final value = values[key];
      if (value == null) {
        continue;
      }
      if (value is String) {
        await _prefs.setString(key, value);
      } else if (value is bool) {
        await _prefs.setBool(key, value);
      } else if (value is int) {
        await _prefs.setInt(key, value);
      } else if (value is double) {
        await _prefs.setDouble(key, value);
      }
    }
  }
}
