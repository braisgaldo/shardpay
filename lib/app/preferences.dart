import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/donation_policy.dart';
import 'local_preferences_store.dart';

/// Una paleta de la app.
///
/// Todos los colores del proyecto salen de aquí: no hay colores sueltos
/// repartidos por las pantallas. Cambiar de tema cambia la app entera sin
/// reiniciar.
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
    required this.counterpartId,
  });

  final String id;
  final String label;
  final Brightness brightness;
  final Color canvas;
  final Color card;
  final Color ink;
  final Color accent;
  final Color secondary;

  /// Paleta hermana del brillo contrario.
  ///
  /// Es lo que hace posible «Seguir el sistema»: el usuario elige una estética
  /// y la app cambia de claro a oscuro sin salirse de ella.
  final String counterpartId;

  bool get isDark => brightness == Brightness.dark;
}

/// Cómo se decide el brillo de la app.
enum AppThemeMode {
  /// Sigue el ajuste del sistema operativo.
  system,

  /// Siempre claro.
  light,

  /// Siempre oscuro.
  dark,
}

class AppLanguageOption {
  const AppLanguageOption({
    required this.code,
    required this.label,
    required this.locale,
    this.isRtl = false,
    this.usesNeutralIcon = false,
  });

  final String code;

  /// Nombre del idioma escrito en su propio idioma.
  final String label;

  final Locale locale;

  /// El idioma se escribe de derecha a izquierda.
  final bool isRtl;

  /// Se muestra un icono neutro de idioma en lugar de una bandera nacional.
  ///
  /// El inglés y el árabe no pertenecen a un país concreto, y elegirle uno a
  /// dedo es una decisión política gratuita en una app de dividir cuentas.
  final bool usesNeutralIcon;

  TextDirection get textDirection => isRtl ? TextDirection.rtl : TextDirection.ltr;
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
    counterpartId: 'dark',
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
    counterpartId: 'light',
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
    counterpartId: 'aurora',
  ),
  AppThemeOption(
    id: 'forest',
    label: 'Bosque',
    brightness: Brightness.light,
    canvas: Color(0xFFF1F6EF),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF1C2A1D),
    accent: Color(0xFF2F6B37),
    secondary: Color(0xFFA7C957),
    counterpartId: 'graphite',
  ),
  AppThemeOption(
    id: 'rose',
    label: 'Rosa Solar',
    brightness: Brightness.light,
    canvas: Color(0xFFFFF1F3),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF2A1620),
    accent: Color(0xFFC0245A),
    secondary: Color(0xFFFFC2D1),
    counterpartId: 'ember',
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
    counterpartId: 'forest',
  ),
  AppThemeOption(
    id: 'sunset',
    label: 'Atardecer Cálido',
    brightness: Brightness.light,
    canvas: Color(0xFFFFF4EE),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF2F1B16),
    accent: Color(0xFFC4471A),
    secondary: Color(0xFFFFB703),
    counterpartId: 'ember',
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
    counterpartId: 'ocean',
  ),
  AppThemeOption(
    id: 'plum',
    label: 'Ciruela',
    brightness: Brightness.light,
    canvas: Color(0xFFF8F1F8),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF24162C),
    accent: Color(0xFF6A22A8),
    secondary: Color(0xFFFFC8DD),
    counterpartId: 'aurora',
  ),
  AppThemeOption(
    id: 'lagoon',
    label: 'Laguna Mineral',
    brightness: Brightness.light,
    canvas: Color(0xFFEAF7F4),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF15313A),
    accent: Color(0xFF0E7490),
    secondary: Color(0xFF67E8F9),
    counterpartId: 'volt',
  ),
  AppThemeOption(
    id: 'ember',
    label: 'Ascua',
    brightness: Brightness.dark,
    canvas: Color(0xFF16110F),
    card: Color(0xFF221917),
    ink: Color(0xFFF8EEE8),
    accent: Color(0xFFFF7B54),
    secondary: Color(0xFFFFC15E),
    counterpartId: 'sunset',
  ),
  AppThemeOption(
    id: 'matcha',
    label: 'Matcha',
    brightness: Brightness.light,
    canvas: Color(0xFFF4F8EF),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF1D2B1F),
    accent: Color(0xFF4A7522),
    secondary: Color(0xFFCFE7A3),
    counterpartId: 'graphite',
  ),
  AppThemeOption(
    id: 'volt',
    label: 'Voltaje',
    brightness: Brightness.dark,
    canvas: Color(0xFF09131E),
    card: Color(0xFF102033),
    ink: Color(0xFFF2FAFF),
    accent: Color(0xFF00C2FF),
    secondary: Color(0xFFFFD166),
    counterpartId: 'lagoon',
  ),
];

/// Idiomas de la app.
///
/// Cubre los trece exigidos —inglés, castellano, francés, alemán, chino
/// mandarín simplificado, japonés, ruso, italiano, griego, árabe, gallego,
/// catalán y euskera— más el portugués, que ya estaba.
const appLanguageOptions = [
  AppLanguageOption(code: 'es', label: 'Español', locale: Locale('es')),
  AppLanguageOption(code: 'en', label: 'English', locale: Locale('en'), usesNeutralIcon: true),
  AppLanguageOption(code: 'gl', label: 'Galego', locale: Locale('gl')),
  AppLanguageOption(code: 'ca', label: 'Català', locale: Locale('ca')),
  AppLanguageOption(code: 'eu', label: 'Euskara', locale: Locale('eu')),
  AppLanguageOption(code: 'fr', label: 'Français', locale: Locale('fr')),
  AppLanguageOption(code: 'it', label: 'Italiano', locale: Locale('it')),
  AppLanguageOption(code: 'pt', label: 'Português', locale: Locale('pt')),
  AppLanguageOption(code: 'de', label: 'Deutsch', locale: Locale('de')),
  AppLanguageOption(code: 'el', label: 'Ελληνικά', locale: Locale('el')),
  AppLanguageOption(code: 'ru', label: 'Русский', locale: Locale('ru')),
  AppLanguageOption(code: 'ar', label: 'العربية', locale: Locale('ar'), isRtl: true, usesNeutralIcon: true),
  AppLanguageOption(code: 'zh', label: '中文', locale: Locale('zh')),
  AppLanguageOption(code: 'ja', label: '日本語', locale: Locale('ja')),
];

/// Idiomas que la app declara soportar, en el orden en que se ofrecen.
List<Locale> get supportedAppLocales => appLanguageOptions.map((option) => option.locale).toList(growable: false);

class AppPreferences {
  const AppPreferences({
    required this.themeId,
    required this.themeMode,
    required this.languageCode,
    required this.hasSeenManual,
    required this.expenseNotificationsEnabled,
    required this.refundNotificationsEnabled,
    required this.refundRequestNotificationsEnabled,
    required this.donation,
  });

  final String themeId;
  final AppThemeMode themeMode;
  final String languageCode;
  final bool hasSeenManual;
  final bool expenseNotificationsEnabled;
  final bool refundNotificationsEnabled;
  final bool refundRequestNotificationsEnabled;
  final DonationState donation;

  AppThemeOption get theme => themeById(themeId);

  AppLanguageOption get language =>
      appLanguageOptions.firstWhere((option) => option.code == languageCode, orElse: () => appLanguageOptions.first);

  /// Paleta clara que se aplicará, sea cual sea la elegida.
  AppThemeOption get lightTheme => theme.isDark ? themeById(theme.counterpartId) : theme;

  /// Paleta oscura que se aplicará, sea cual sea la elegida.
  AppThemeOption get darkTheme => theme.isDark ? theme : themeById(theme.counterpartId);

  /// Paleta efectiva para una luminosidad del sistema dada.
  AppThemeOption resolvedTheme(Brightness platformBrightness) {
    switch (themeMode) {
      case AppThemeMode.light:
        return lightTheme;
      case AppThemeMode.dark:
        return darkTheme;
      case AppThemeMode.system:
        return platformBrightness == Brightness.dark ? darkTheme : lightTheme;
    }
  }

  AppPreferences copyWith({
    String? themeId,
    AppThemeMode? themeMode,
    String? languageCode,
    bool? hasSeenManual,
    bool? expenseNotificationsEnabled,
    bool? refundNotificationsEnabled,
    bool? refundRequestNotificationsEnabled,
    DonationState? donation,
  }) {
    return AppPreferences(
      themeId: themeId ?? this.themeId,
      themeMode: themeMode ?? this.themeMode,
      languageCode: languageCode ?? this.languageCode,
      hasSeenManual: hasSeenManual ?? this.hasSeenManual,
      expenseNotificationsEnabled: expenseNotificationsEnabled ?? this.expenseNotificationsEnabled,
      refundNotificationsEnabled: refundNotificationsEnabled ?? this.refundNotificationsEnabled,
      refundRequestNotificationsEnabled: refundRequestNotificationsEnabled ?? this.refundRequestNotificationsEnabled,
      donation: donation ?? this.donation,
    );
  }
}

AppThemeOption themeById(String id) {
  return appThemeOptions.firstWhere((option) => option.id == id, orElse: () => appThemeOptions.first);
}

class AppPreferencesNotifier extends StateNotifier<AppPreferences> {
  AppPreferencesNotifier(this._store) : super(_store.read());

  final LocalPreferencesStore _store;

  static const _donationPolicy = DonationPolicy();

  /// Sesión actual: ¿el usuario ha hecho algo real con la app?
  ///
  /// No se persiste a propósito. Se reinicia en cada arranque porque la regla
  /// del aviso de donación habla de «la sesión en la que haya hecho algo real».
  bool _sessionHadRealUse = false;

  bool get sessionHadRealUse => _sessionHadRealUse;

  void selectTheme(String themeId) {
    state = state.copyWith(themeId: themeId);
    _store.setThemeId(themeId);
  }

  void selectThemeMode(AppThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _store.setThemeMode(mode.name);
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

  // ---------------------------------------------------------------------------
  // Donación
  // ---------------------------------------------------------------------------

  /// Registra un uso real: crear un gasto, importar un ticket o registrar un
  /// reembolso. Mirar los saldos no cuenta.
  void registerRealUse() {
    _sessionHadRealUse = true;
    _updateDonation(_donationPolicy.afterRealUse(state.donation));
  }

  bool shouldShowDonationPrompt({DateTime? now}) {
    return _donationPolicy.shouldPrompt(state: state.donation, now: now ?? DateTime.now(), sessionHadRealUse: _sessionHadRealUse);
  }

  void markDonationPromptShown({DateTime? now}) {
    _updateDonation(_donationPolicy.afterPrompt(state.donation, now ?? DateTime.now()));
  }

  void dismissDonationForever() {
    _updateDonation(_donationPolicy.afterDismissForever(state.donation));
  }

  void _updateDonation(DonationState donation) {
    state = state.copyWith(donation: donation);
    _store.setDonationState(donation);
  }

  // ---------------------------------------------------------------------------
  // Copia de seguridad
  // ---------------------------------------------------------------------------

  /// Ajustes que viajan en la exportación de datos.
  Map<String, Object?> toBackupMap() => _store.toBackupMap();

  /// Restaura los ajustes de una copia y los aplica en caliente.
  Future<void> restoreFromBackup(Map<String, Object?> values) async {
    await _store.restoreFromBackup(values);
    state = _store.read();
  }
}
