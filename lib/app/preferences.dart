import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_preferences_store.dart';

class AppThemeOption {
  const AppThemeOption({
    required this.id,
    required this.label,
    required this.brightness,
    required this.canvas,
    required this.card,
    required this.ink,
    required this.accent,
    required this.secondary,
  });

  final String id;
  final String label;
  final Brightness brightness;
  final Color canvas;
  final Color card;
  final Color ink;
  final Color accent;
  final Color secondary;
}

class AppLanguageOption {
  const AppLanguageOption({
    required this.code,
    required this.label,
    required this.locale,
  });

  final String code;
  final String label;
  final Locale locale;
}

const appThemeOptions = [
  AppThemeOption(
    id: 'light',
    label: 'Claro Arena',
    brightness: Brightness.light,
    canvas: Color(0xFFF6EFE8),
    card: Color(0xFFFFFBF8),
    ink: Color(0xFF101522),
    accent: Color(0xFFE4572E),
    secondary: Color(0xFFF3C677),
  ),
  AppThemeOption(
    id: 'dark',
    label: 'Oscuro Carbón',
    brightness: Brightness.dark,
    canvas: Color(0xFF0E121A),
    card: Color(0xFF161C27),
    ink: Color(0xFFF6F2EC),
    accent: Color(0xFFFF7A59),
    secondary: Color(0xFF4CC9F0),
  ),
  AppThemeOption(
    id: 'ocean',
    label: 'Océano',
    brightness: Brightness.light,
    canvas: Color(0xFFEAF6F8),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF0B2239),
    accent: Color(0xFF0077B6),
    secondary: Color(0xFF90E0EF),
  ),
  AppThemeOption(
    id: 'forest',
    label: 'Bosque',
    brightness: Brightness.light,
    canvas: Color(0xFFF1F6EF),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF1C2A1D),
    accent: Color(0xFF3A7D44),
    secondary: Color(0xFFA7C957),
  ),
  AppThemeOption(
    id: 'rose',
    label: 'Rosa Solar',
    brightness: Brightness.light,
    canvas: Color(0xFFFFF1F3),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF2A1620),
    accent: Color(0xFFD6336C),
    secondary: Color(0xFFFFC2D1),
  ),
  AppThemeOption(
    id: 'graphite',
    label: 'Grafito Neón',
    brightness: Brightness.dark,
    canvas: Color(0xFF121212),
    card: Color(0xFF1E1E1E),
    ink: Color(0xFFF5F5F5),
    accent: Color(0xFF9EF01A),
    secondary: Color(0xFF70E000),
  ),
  AppThemeOption(
    id: 'sunset',
    label: 'Atardecer Cálido',
    brightness: Brightness.light,
    canvas: Color(0xFFFFF4EE),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF2F1B16),
    accent: Color(0xFFFF6B35),
    secondary: Color(0xFFFFB703),
  ),
  AppThemeOption(
    id: 'aurora',
    label: 'Aurora',
    brightness: Brightness.dark,
    canvas: Color(0xFF0A1020),
    card: Color(0xFF111A2D),
    ink: Color(0xFFF3F7FF),
    accent: Color(0xFF52D1DC),
    secondary: Color(0xFFFFC857),
  ),
  AppThemeOption(
    id: 'plum',
    label: 'Ciruela',
    brightness: Brightness.light,
    canvas: Color(0xFFF8F1F8),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF24162C),
    accent: Color(0xFF7B2CBF),
    secondary: Color(0xFFFFC8DD),
  ),
];

const appLanguageOptions = [
  AppLanguageOption(code: 'es', label: 'Español', locale: Locale('es')),
  AppLanguageOption(code: 'en', label: 'English', locale: Locale('en')),
  AppLanguageOption(code: 'gl', label: 'Galego', locale: Locale('gl')),
  AppLanguageOption(code: 'fr', label: 'Français', locale: Locale('fr')),
  AppLanguageOption(code: 'it', label: 'Italiano', locale: Locale('it')),
  AppLanguageOption(code: 'pt', label: 'Português', locale: Locale('pt')),
  AppLanguageOption(code: 'de', label: 'Deutsch', locale: Locale('de')),
  AppLanguageOption(code: 'ru', label: 'Русский', locale: Locale('ru')),
  AppLanguageOption(code: 'zh', label: '中文', locale: Locale('zh')),
  AppLanguageOption(code: 'ja', label: '日本語', locale: Locale('ja')),
];

class AppPreferences {
  const AppPreferences({
    required this.themeId,
    required this.languageCode,
    required this.hasSeenManual,
    required this.expenseNotificationsEnabled,
    required this.refundNotificationsEnabled,
    required this.refundRequestNotificationsEnabled,
  });

  final String themeId;
  final String languageCode;
  final bool hasSeenManual;
  final bool expenseNotificationsEnabled;
  final bool refundNotificationsEnabled;
  final bool refundRequestNotificationsEnabled;

  AppThemeOption get theme => appThemeOptions.firstWhere((option) => option.id == themeId, orElse: () => appThemeOptions.first);
  AppLanguageOption get language => appLanguageOptions.firstWhere((option) => option.code == languageCode, orElse: () => appLanguageOptions.first);

  AppPreferences copyWith({
    String? themeId,
    String? languageCode,
    bool? hasSeenManual,
    bool? expenseNotificationsEnabled,
    bool? refundNotificationsEnabled,
    bool? refundRequestNotificationsEnabled,
  }) {
    return AppPreferences(
      themeId: themeId ?? this.themeId,
      languageCode: languageCode ?? this.languageCode,
      hasSeenManual: hasSeenManual ?? this.hasSeenManual,
      expenseNotificationsEnabled: expenseNotificationsEnabled ?? this.expenseNotificationsEnabled,
      refundNotificationsEnabled: refundNotificationsEnabled ?? this.refundNotificationsEnabled,
      refundRequestNotificationsEnabled: refundRequestNotificationsEnabled ?? this.refundRequestNotificationsEnabled,
    );
  }
}

class AppPreferencesNotifier extends StateNotifier<AppPreferences> {
  AppPreferencesNotifier(this._store)
      : super(
          AppPreferences(
            themeId: _store.getThemeId(),
            languageCode: _store.getLanguageCode(),
            hasSeenManual: _store.getHasSeenManual(),
            expenseNotificationsEnabled: _store.getExpenseNotificationsEnabled(),
            refundNotificationsEnabled: _store.getRefundNotificationsEnabled(),
            refundRequestNotificationsEnabled: _store.getRefundRequestNotificationsEnabled(),
          ),
        );

  final LocalPreferencesStore _store;

  void selectTheme(String themeId) {
    state = state.copyWith(themeId: themeId);
    _store.setThemeId(themeId);
  }

  void selectLanguage(String languageCode) {
    state = state.copyWith(languageCode: languageCode);
    _store.setLanguageCode(languageCode);
  }

  void markManualSeen() {
    state = state.copyWith(hasSeenManual: true);
    _store.setHasSeenManual(true);
  }

  void setExpenseNotificationsEnabled(bool value) {
    state = state.copyWith(expenseNotificationsEnabled: value);
    _store.setExpenseNotificationsEnabled(value);
  }

  void setRefundNotificationsEnabled(bool value) {
    state = state.copyWith(refundNotificationsEnabled: value);
    _store.setRefundNotificationsEnabled(value);
  }

  void setRefundRequestNotificationsEnabled(bool value) {
    state = state.copyWith(refundRequestNotificationsEnabled: value);
    _store.setRefundRequestNotificationsEnabled(value);
  }
}
