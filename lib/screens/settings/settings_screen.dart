import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/app_text.dart';
import '../../app/preferences.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/app_info.dart';
import '../../core/backup_format.dart';
import '../../core/donation_config.dart';
import '../../models/app_models.dart';
import '../../services/backup_service.dart';
import '../../widgets/donation/donation_sheet.dart';
import '../../widgets/language_flag.dart';
import '../notifications/notifications_screen.dart';
import 'about_screen.dart';
import 'help_screen.dart';
import 'settings_sections.dart';

/// Señal para que la pantalla principal vuelva a lanzar el tour guiado.
///
/// Es un contador y no un booleano para que dos peticiones seguidas se
/// distingan: con un booleano, pedirlo dos veces no cambiaría el estado y la
/// segunda no dispararía nada.
final replayTourProvider = StateProvider<int>((ref) => 0);

/// Ajustes: el punto único de entrada a tema, idioma, datos, compartir,
/// donación, ayuda y «Acerca de».
///
/// Todo va en secciones plegadas, cada una con su valor actual resumido en el
/// encabezado. Antes la pantalla medía dos pantallazos solo entre las trece
/// paletas y los catorce idiomas, y había que recorrerla entera para llegar a
/// exportar los datos.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(appPreferencesProvider);
    final notifier = ref.read(appPreferencesProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 4, bottom: 12),
              child: Text(
                tr(
                  context,
                  es: 'Ajustes',
                  en: 'Settings',
                  gl: 'Axustes',
                  ca: 'Ajustos',
                  eu: 'Ezarpenak',
                  fr: 'Reglages',
                  it: 'Impostazioni',
                  pt: 'Ajustes',
                  de: 'Einstellungen',
                  el: 'Ρυθμίσεις',
                  ru: 'Настройки',
                  ar: 'الإعدادات',
                  zh: '设置',
                  ja: '設定',
                ),
                style: Theme.of(context).textTheme.displaySmall,
              ),
            ),
            _ProfileCard(user: user),
            const SizedBox(height: 12),
            _AppearanceSection(preferences: preferences, notifier: notifier),
            _LanguageSection(preferences: preferences, notifier: notifier),
            _NotificationsSection(preferences: preferences, notifier: notifier, user: user),
            _DataSection(user: user),
            const _AppSection(),
            _AccountSection(user: user),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(radius: 24, child: Text(user.displayName.isEmpty ? '?' : user.displayName.substring(0, 1).toUpperCase())),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Tema
// -----------------------------------------------------------------------------

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({required this.preferences, required this.notifier});

  final AppPreferences preferences;
  final AppPreferencesNotifier notifier;

  String _modeLabel(BuildContext context, AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return tr(
          context,
          es: 'Sistema',
          en: 'System',
          gl: 'Sistema',
          ca: 'Sistema',
          eu: 'Sistema',
          fr: 'Système',
          it: 'Sistema',
          pt: 'Sistema',
          de: 'System',
          el: 'Σύστημα',
          ru: 'Система',
          ar: 'النظام',
          zh: '系统',
          ja: 'システム',
        );
      case AppThemeMode.light:
        return tr(
          context,
          es: 'Claro',
          en: 'Light',
          gl: 'Claro',
          ca: 'Clar',
          eu: 'Argia',
          fr: 'Clair',
          it: 'Chiaro',
          pt: 'Claro',
          de: 'Hell',
          el: 'Ανοιχτό',
          ru: 'Светлая',
          ar: 'فاتح',
          zh: '浅色',
          ja: 'ライト',
        );
      case AppThemeMode.dark:
        return tr(
          context,
          es: 'Oscuro',
          en: 'Dark',
          gl: 'Escuro',
          ca: 'Fosc',
          eu: 'Iluna',
          fr: 'Sombre',
          it: 'Scuro',
          pt: 'Escuro',
          de: 'Dunkel',
          el: 'Σκοτεινό',
          ru: 'Тёмная',
          ar: 'داكن',
          zh: '深色',
          ja: 'ダーク',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      icon: Icons.palette_outlined,
      title: tr(
        context,
        es: 'Tema',
        en: 'Theme',
        gl: 'Tema',
        ca: 'Tema',
        eu: 'Gaia',
        fr: 'Thème',
        it: 'Tema',
        pt: 'Tema',
        de: 'Thema',
        el: 'Θέμα',
        ru: 'Тема',
        ar: 'السمة',
        zh: '主题',
        ja: 'テーマ',
      ),
      summary: '${preferences.theme.label} · ${_modeLabel(context, preferences.themeMode)}',
      children: [
        SettingsRow(
          label: tr(
            context,
            es: 'Cuándo se ve oscura',
            en: 'When it looks dark',
            gl: 'Cando se ve escura',
            ca: 'Quan es veu fosca',
            eu: 'Noiz ikusten den iluna',
            fr: 'Quand elle est sombre',
            it: 'Quando appare scura',
            pt: 'Quando fica escura',
            de: 'Wann dunkel',
            el: 'Πότε είναι σκοτεινό',
            ru: 'Когда тёмная',
            ar: 'متى تظهر داكنة',
            zh: '何时变深色',
            ja: 'ダークにする条件',
          ),
          child: SegmentedButton<AppThemeMode>(
            segments: [
              ButtonSegment<AppThemeMode>(
                value: AppThemeMode.system,
                icon: const Icon(Icons.brightness_auto_rounded, size: 18),
                label: Text(_modeLabel(context, AppThemeMode.system)),
              ),
              ButtonSegment<AppThemeMode>(
                value: AppThemeMode.light,
                icon: const Icon(Icons.light_mode_rounded, size: 18),
                label: Text(_modeLabel(context, AppThemeMode.light)),
              ),
              ButtonSegment<AppThemeMode>(
                value: AppThemeMode.dark,
                icon: const Icon(Icons.dark_mode_rounded, size: 18),
                label: Text(_modeLabel(context, AppThemeMode.dark)),
              ),
            ],
            selected: <AppThemeMode>{preferences.themeMode},
            onSelectionChanged: (selection) => notifier.selectThemeMode(selection.first),
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
          ),
        ),
        SettingsRow(
          label: tr(
            context,
            es: 'Paleta',
            en: 'Palette',
            gl: 'Paleta',
            ca: 'Paleta',
            eu: 'Paleta',
            fr: 'Palette',
            it: 'Palette',
            pt: 'Paleta',
            de: 'Palette',
            el: 'Παλέτα',
            ru: 'Палитра',
            ar: 'لوحة الألوان',
            zh: '配色',
            ja: 'パレット',
          ),
          help: tr(
            context,
            es: 'Cada paleta tiene su versión clara y su versión oscura.',
            en: 'Each palette has a light and a dark version.',
            gl: 'Cada paleta ten a súa versión clara e a súa versión escura.',
            ca: 'Cada paleta té la versió clara i la fosca.',
            eu: 'Paleta bakoitzak bere bertsio argia eta iluna ditu.',
            fr: 'Chaque palette a sa version claire et sa version sombre.',
            it: 'Ogni palette ha la sua versione chiara e scura.',
            pt: 'Cada paleta tem a sua versão clara e escura.',
            de: 'Jede Palette hat eine helle und eine dunkle Fassung.',
            el: 'Κάθε παλέτα έχει ανοιχτή και σκοτεινή έκδοση.',
            ru: 'У каждой палитры есть светлый и тёмный вариант.',
            ar: 'لكل لوحة ألوان نسخة فاتحة وأخرى داكنة.',
            zh: '每套配色都有浅色和深色两个版本。',
            ja: '各パレットにライトとダークがあります。',
          ),
          child: DropdownButtonFormField<String>(
            initialValue: preferences.themeId,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
            items: [
              for (final option in appThemeOptions)
                DropdownMenuItem<String>(
                  value: option.id,
                  child: Row(
                    children: [
                      _PaletteDots(option: option),
                      const SizedBox(width: 12),
                      Expanded(child: Text(option.label, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                notifier.selectTheme(value);
              }
            },
          ),
        ),
      ],
    );
  }
}

/// Los colores que definen una paleta, para poder elegir mirando y no leyendo.
class _PaletteDots extends StatelessWidget {
  const _PaletteDots({required this.option});

  final AppThemeOption option;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 22,
      decoration: BoxDecoration(
        color: option.canvas,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(color: option.accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: option.secondary, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Idioma
// -----------------------------------------------------------------------------

class _LanguageSection extends StatelessWidget {
  const _LanguageSection({required this.preferences, required this.notifier});

  final AppPreferences preferences;
  final AppPreferencesNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      icon: Icons.translate_rounded,
      title: tr(
        context,
        es: 'Idioma',
        en: 'Language',
        gl: 'Idioma',
        ca: 'Idioma',
        eu: 'Hizkuntza',
        fr: 'Langue',
        it: 'Lingua',
        pt: 'Idioma',
        de: 'Sprache',
        el: 'Γλώσσα',
        ru: 'Язык',
        ar: 'اللغة',
        zh: '语言',
        ja: '言語',
      ),
      summary: preferences.language.label,
      children: [
        SettingsRow(
          label: tr(
            context,
            es: 'Idioma de la app',
            en: 'App language',
            gl: 'Idioma da app',
            ca: 'Idioma de l app',
            eu: 'Aplikazioaren hizkuntza',
            fr: 'Langue de l application',
            it: 'Lingua dell app',
            pt: 'Idioma da app',
            de: 'App-Sprache',
            el: 'Γλώσσα εφαρμογής',
            ru: 'Язык приложения',
            ar: 'لغة التطبيق',
            zh: '应用语言',
            ja: 'アプリの言語',
          ),
          help: tr(
            context,
            es: 'Cambia también el formato de fechas y cantidades.',
            en: 'It also changes the format of dates and amounts.',
            gl: 'Cambia tamén o formato de datas e cantidades.',
            ca: 'També canvia el format de dates i imports.',
            eu: 'Daten eta zenbatekoen formatua ere aldatzen du.',
            fr: 'Change aussi le format des dates et des montants.',
            it: 'Cambia anche il formato di date e importi.',
            pt: 'Muda também o formato de datas e valores.',
            de: 'Ändert auch das Format von Datum und Beträgen.',
            el: 'Αλλάζει και τη μορφή ημερομηνιών και ποσών.',
            ru: 'Меняет также формат дат и сумм.',
            ar: 'يغير أيضا تنسيق التواريخ والمبالغ.',
            zh: '同时改变日期和金额的格式。',
            ja: '日付と金額の書式も変わります。',
          ),
          child: DropdownButtonFormField<String>(
            initialValue: preferences.languageCode,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
            items: [
              for (final option in appLanguageOptions)
                DropdownMenuItem<String>(
                  value: option.code,
                  child: Row(
                    children: [
                      LanguageFlag(code: option.code, size: 18),
                      const SizedBox(width: 12),
                      // El nombre va escrito en su propio idioma: quien no
                      // entiende el idioma actual tiene que reconocer el suyo.
                      Expanded(child: Text(option.label, overflow: TextOverflow.ellipsis)),
                      if (option.isRtl)
                        Icon(Icons.format_textdirection_r_to_l_rounded, size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                notifier.selectLanguage(value);
              }
            },
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Notificaciones
// -----------------------------------------------------------------------------

class _NotificationsSection extends StatelessWidget {
  const _NotificationsSection({required this.preferences, required this.notifier, required this.user});

  final AppPreferences preferences;
  final AppPreferencesNotifier notifier;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final activas = <bool>[
      preferences.expenseNotificationsEnabled,
      preferences.refundNotificationsEnabled,
      preferences.refundRequestNotificationsEnabled,
    ].where((valor) => valor).length;

    return SettingsSection(
      icon: Icons.notifications_none_rounded,
      title: tr(
        context,
        es: 'Notificaciones',
        en: 'Notifications',
        gl: 'Notificacións',
        ca: 'Notificacions',
        eu: 'Jakinarazpenak',
        fr: 'Notifications',
        it: 'Notifiche',
        pt: 'Notificações',
        de: 'Benachrichtigungen',
        el: 'Ειδοποιήσεις',
        ru: 'Уведомления',
        ar: 'الإشعارات',
        zh: '通知',
        ja: '通知',
      ),
      summary: tr(
        context,
        es: '$activas de 3 activadas',
        en: '$activas of 3 on',
        gl: '$activas de 3 activadas',
        ca: '$activas de 3 activades',
        eu: '3tik $activas aktibo',
        fr: '$activas sur 3 activées',
        it: '$activas su 3 attive',
        pt: '$activas de 3 ativadas',
        de: '$activas von 3 aktiv',
        el: '$activas από 3 ενεργές',
        ru: '$activas из 3 включено',
        ar: '$activas من 3 مفعلة',
        zh: '已开启 $activas / 3',
        ja: '3 件中 $activas 件オン',
      ),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: preferences.expenseNotificationsEnabled,
          onChanged: notifier.setExpenseNotificationsEnabled,
          title: Text(
            tr(
              context,
              es: 'Nuevos gastos',
              en: 'New expenses',
              gl: 'Novos gastos',
              ca: 'Noves despeses',
              eu: 'Gastu berriak',
              fr: 'Nouvelles depenses',
              it: 'Nuove spese',
              pt: 'Novas despesas',
            ),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: preferences.refundNotificationsEnabled,
          onChanged: notifier.setRefundNotificationsEnabled,
          title: Text(
            tr(
              context,
              es: 'Reembolsos registrados',
              en: 'Recorded reimbursements',
              gl: 'Reembolsos rexistrados',
              ca: 'Reemborsaments registrats',
              eu: 'Erregistratutako itzulketak',
              fr: 'Remboursements enregistres',
              it: 'Rimborsi registrati',
              pt: 'Reembolsos registados',
            ),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: preferences.refundRequestNotificationsEnabled,
          onChanged: notifier.setRefundRequestNotificationsEnabled,
          title: Text(
            tr(
              context,
              es: 'Solicitudes de reembolso',
              en: 'Reimbursement requests',
              gl: 'Solicitudes de reembolso',
              ca: 'Sol·licituds de reemborsament',
              eu: 'Itzulketa eskaerak',
              fr: 'Demandes de remboursement',
              it: 'Richieste di rimborso',
              pt: 'Pedidos de reembolso',
            ),
          ),
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NotificationsScreen(user: user))),
          icon: const Icon(Icons.notifications_active_outlined, size: 18),
          label: Text(
            tr(
              context,
              es: 'Abrir centro de notificaciones',
              en: 'Open notification center',
              gl: 'Abrir centro de notificacións',
              ca: 'Obre el centre de notificacions',
              eu: 'Ireki jakinarazpen gunea',
              fr: 'Ouvrir le centre de notifications',
              it: 'Apri centro notifiche',
              pt: 'Abrir centro de notificações',
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Datos
// -----------------------------------------------------------------------------

class _DataSection extends ConsumerStatefulWidget {
  const _DataSection({required this.user});

  final AppUser user;

  @override
  ConsumerState<_DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends ConsumerState<_DataSection> {
  bool _busy = false;

  /// Grupos del usuario, tomados de la suscripción activa.
  ///
  /// Se rellenan en `build` con `ref.watch` y no con `ref.read`:
  /// `groupsProvider` es `autoDispose`, así que leerlo desde un callback sin
  /// tener suscripción lo crea y lo destruye en el acto, y devolvería siempre
  /// una lista vacía. La copia de seguridad habría salido sin ningún grupo.
  List<ExpenseGroup> _groups = const <ExpenseGroup>[];

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final service = ref.read(backupServiceProvider);
      final result = await service.export(
        groups: _groups,
        preferences: ref.read(appPreferencesProvider.notifier).toBackupMap(),
        appVersion: AppInfo.version,
      );

      if (!mounted) {
        return;
      }

      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(result.filePath, mimeType: backupMimeType, name: result.fileName)],
          subject: 'ShardPay · ${result.fileName}',
        ),
      );

      if (!mounted) {
        return;
      }
      _snack(
        tr(
          context,
          es: 'Copia creada con ${result.groupCount} grupos (${_readableSize(result.byteSize)}).',
          en: 'Backup created with ${result.groupCount} groups (${_readableSize(result.byteSize)}).',
          gl: 'Copia creada con ${result.groupCount} grupos (${_readableSize(result.byteSize)}).',
          fr: 'Sauvegarde créée avec ${result.groupCount} groupes (${_readableSize(result.byteSize)}).',
          it: 'Copia creata con ${result.groupCount} gruppi (${_readableSize(result.byteSize)}).',
          pt: 'Cópia criada com ${result.groupCount} grupos (${_readableSize(result.byteSize)}).',
        ),
      );
    } catch (error) {
      if (mounted) {
        _snack(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _import() async {
    final file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[
        const XTypeGroup(
          label: 'ShardPay',
          extensions: <String>['bak', 'shardpay'],
          mimeTypes: <String>[backupMimeType, 'application/gzip', 'application/octet-stream'],
        ),
      ],
    );

    if (file == null || !mounted) {
      return;
    }

    setState(() => _busy = true);
    final service = ref.read(backupServiceProvider);

    BackupDocument document;
    try {
      // Se valida ANTES de preguntar nada y antes de tocar ningún dato: si el
      // fichero no sirve, el usuario se entera sin haber perdido nada.
      document = await service.read(file.path);
    } on BackupFormatException catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        _snack(describeBackupError(context, error.error));
      }
      return;
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        _snack(error.toString());
      }
      return;
    }

    if (!mounted) {
      setState(() => _busy = false);
      return;
    }

    final mode = await _askImportMode(document);
    if (mode == null || !mounted) {
      setState(() => _busy = false);
      return;
    }

    try {
      final result = await service.import(
        document: document,
        mode: mode,
        user: widget.user,
        currentGroups: _groups,
        currentPreferences: ref.read(appPreferencesProvider.notifier).toBackupMap(),
        appVersion: AppInfo.version,
        applyPreferences: ref.read(appPreferencesProvider.notifier).restoreFromBackup,
      );

      if (!mounted) {
        return;
      }
      _snack(
        tr(
          context,
          es: 'Restaurados ${result.restoredGroups} grupos. ${result.skippedGroups} ya existían.',
          en: '${result.restoredGroups} groups restored. ${result.skippedGroups} already existed.',
          gl: 'Restaurados ${result.restoredGroups} grupos. ${result.skippedGroups} xa existían.',
          fr: '${result.restoredGroups} groupes restaurés. ${result.skippedGroups} existaient déjà.',
          it: 'Ripristinati ${result.restoredGroups} gruppi. ${result.skippedGroups} esistevano già.',
          pt: 'Restaurados ${result.restoredGroups} grupos. ${result.skippedGroups} já existiam.',
        ),
      );
    } catch (error) {
      if (mounted) {
        _snack(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// Explica con claridad qué va a ocurrir antes de tocar nada.
  Future<BackupImportMode?> _askImportMode(BackupDocument document) {
    final createdAt = DateFormat.yMMMMd(localeTag(context)).add_Hm().format(document.createdAt.toLocal());

    return showDialog<BackupImportMode>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            tr(
              context,
              es: 'Importar copia',
              en: 'Import backup',
              gl: 'Importar copia',
              fr: 'Importer la sauvegarde',
              it: 'Importa copia',
              pt: 'Importar cópia',
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(
                  context,
                  es: 'Copia del $createdAt · versión ${document.appVersion} · ${groupCountLabel(context, document.payload.groups.length)}.',
                  en: 'Backup from $createdAt · version ${document.appVersion} · ${groupCountLabel(context, document.payload.groups.length)}.',
                  gl: 'Copia do $createdAt · versión ${document.appVersion} · ${groupCountLabel(context, document.payload.groups.length)}.',
                  fr: 'Sauvegarde du $createdAt · version ${document.appVersion} · ${groupCountLabel(context, document.payload.groups.length)}.',
                  it: 'Copia del $createdAt · versione ${document.appVersion} · ${groupCountLabel(context, document.payload.groups.length)}.',
                  pt: 'Cópia de $createdAt · versão ${document.appVersion} · ${groupCountLabel(context, document.payload.groups.length)}.',
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              Text(
                tr(
                  context,
                  es: 'Antes de tocar nada se guardará una copia automática del estado actual. Los grupos que ya existen no se sobrescriben: pueden tener gastos añadidos por otras personas.',
                  en: 'A backup of the current state is saved automatically before anything is touched. Groups that already exist are not overwritten: they may contain expenses added by other people.',
                  gl: 'Antes de tocar nada gardarase unha copia automática do estado actual. Os grupos que xa existen non se sobrescriben: poden ter gastos engadidos por outras persoas.',
                  fr: 'Une sauvegarde de l état actuel est enregistrée avant toute modification. Les groupes existants ne sont pas écrasés : ils peuvent contenir des dépenses ajoutées par d autres.',
                  it: 'Prima di toccare qualsiasi cosa si salva una copia automatica dello stato attuale. I gruppi esistenti non vengono sovrascritti.',
                  pt: 'Antes de mexer em algo guarda-se uma cópia automática do estado atual. Os grupos já existentes não são substituídos.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(tr(context, es: 'Cancelar', en: 'Cancel', gl: 'Cancelar', fr: 'Annuler', it: 'Annulla', pt: 'Cancelar')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(BackupImportMode.preferencesOnly),
              child: Text(
                tr(
                  context,
                  es: 'Solo ajustes',
                  en: 'Settings only',
                  gl: 'Só axustes',
                  fr: 'Réglages seuls',
                  it: 'Solo impostazioni',
                  pt: 'Só definições',
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(BackupImportMode.restoreMissingGroups),
              child: Text(
                tr(
                  context,
                  es: 'Ajustes y grupos',
                  en: 'Settings and groups',
                  gl: 'Axustes e grupos',
                  fr: 'Réglages et groupes',
                  it: 'Impostazioni e gruppi',
                  pt: 'Definições e grupos',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _readableSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} kB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    _groups = ref.watch(groupsProvider(widget.user.id)).valueOrNull ?? const <ExpenseGroup>[];

    return SettingsSection(
      icon: Icons.inventory_2_outlined,
      title: tr(
        context,
        es: 'Tus datos',
        en: 'Your data',
        gl: 'Os teus datos',
        ca: 'Les teves dades',
        eu: 'Zure datuak',
        fr: 'Vos données',
        it: 'I tuoi dati',
        pt: 'Os teus dados',
        de: 'Deine Daten',
        el: 'Τα δεδομένα σου',
        ru: 'Ваши данные',
        ar: 'بياناتك',
        zh: '你的数据',
        ja: 'あなたのデータ',
      ),
      summary: tr(
        context,
        es: '${groupCountLabel(context, _groups.length)} · fichero .shardpay.bak',
        en: '${groupCountLabel(context, _groups.length)} · .shardpay.bak file',
        gl: '${groupCountLabel(context, _groups.length)} · ficheiro .shardpay.bak',
        ca: '${groupCountLabel(context, _groups.length)} · fitxer .shardpay.bak',
        eu: '${groupCountLabel(context, _groups.length)} · .shardpay.bak fitxategia',
        fr: '${groupCountLabel(context, _groups.length)} · fichier .shardpay.bak',
        it: '${groupCountLabel(context, _groups.length)} · file .shardpay.bak',
        pt: '${groupCountLabel(context, _groups.length)} · ficheiro .shardpay.bak',
        de: '${groupCountLabel(context, _groups.length)} · .shardpay.bak-Datei',
        el: '${groupCountLabel(context, _groups.length)} · αρχείο .shardpay.bak',
        ru: 'Групп: ${_groups.length} · файл .shardpay.bak',
        ar: '${groupCountLabel(context, _groups.length)} · ملف .shardpay.bak',
        zh: '${groupCountLabel(context, _groups.length)} · .shardpay.bak 文件',
        ja: '${_groups.length} グループ · .shardpay.bak ファイル',
      ),
      children: [
        if (_busy) const Padding(padding: EdgeInsets.only(bottom: 12), child: LinearProgressIndicator()),
        FilledButton.tonalIcon(
          onPressed: _busy ? null : _export,
          icon: const Icon(Icons.ios_share_rounded, size: 18),
          label: Text(
            tr(
              context,
              es: 'Exportar mis datos',
              en: 'Export my data',
              gl: 'Exportar os meus datos',
              ca: 'Exporta les meves dades',
              eu: 'Esportatu nire datuak',
              fr: 'Exporter mes données',
              it: 'Esporta i miei dati',
              pt: 'Exportar os meus dados',
              de: 'Meine Daten exportieren',
              el: 'Εξαγωγή των δεδομένων μου',
              ru: 'Экспортировать мои данные',
              ar: 'تصدير بياناتي',
              zh: '导出我的数据',
              ja: 'データを書き出す',
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _import,
          icon: const Icon(Icons.settings_backup_restore_rounded, size: 18),
          label: Text(
            tr(
              context,
              es: 'Importar una copia',
              en: 'Import a backup',
              gl: 'Importar unha copia',
              ca: 'Importa una còpia',
              eu: 'Inportatu kopia bat',
              fr: 'Importer une sauvegarde',
              it: 'Importa una copia',
              pt: 'Importar uma cópia',
              de: 'Sicherung importieren',
              el: 'Εισαγωγή αντιγράφου',
              ru: 'Импортировать копию',
              ar: 'استيراد نسخة',
              zh: '导入备份',
              ja: 'バックアップを読み込む',
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// ShardPay: tour, ayuda, compartir, donación y «Acerca de»
// -----------------------------------------------------------------------------

class _AppSection extends ConsumerWidget {
  const _AppSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSection(
      icon: Icons.info_outline_rounded,
      title: 'ShardPay',
      summary: '${AppInfo.version} (${AppInfo.buildNumber})',
      children: [
        _CompactTile(
          icon: Icons.explore_outlined,
          label: tr(
            context,
            es: 'Ver el tour guiado',
            en: 'Replay the guided tour',
            gl: 'Ver o tour guiado',
            ca: 'Torna a veure el tour',
            eu: 'Ikusi bisita gidatua',
            fr: 'Revoir la visite guidée',
            it: 'Rivedi il tour guidato',
            pt: 'Ver a visita guiada',
            de: 'Geführte Tour erneut ansehen',
            el: 'Δες ξανά την ξενάγηση',
            ru: 'Пройти тур заново',
            ar: 'إعادة الجولة الإرشادية',
            zh: '重看引导教程',
            ja: 'ガイドツアーをもう一度',
          ),
          help: tr(
            context,
            es: 'Se abre sobre la pantalla de grupos.',
            en: 'It opens over the groups screen.',
            gl: 'Ábrese sobre a pantalla de grupos.',
            ca: 'S obre sobre la pantalla de grups.',
            eu: 'Taldeen pantailaren gainean irekitzen da.',
            fr: 'Elle s ouvre sur l écran des groupes.',
            it: 'Si apre sulla schermata dei gruppi.',
            pt: 'Abre sobre o ecrã de grupos.',
            de: 'Öffnet sich über dem Gruppen-Bildschirm.',
            el: 'Ανοίγει πάνω από την οθόνη ομάδων.',
            ru: 'Откроется поверх экрана групп.',
            ar: 'تفتح فوق شاشة المجموعات.',
            zh: '将在群组页面上打开。',
            ja: 'グループ画面の上で開きます。',
          ),
          // El tour ilumina botones de la pantalla de grupos, así que lo lanza
          // esa pantalla: iluminar un widget que no está montado no enseña nada.
          onTap: () => ref.read(replayTourProvider.notifier).state++,
        ),
        _CompactTile(
          icon: Icons.help_outline_rounded,
          label: tr(
            context,
            es: 'Ayuda',
            en: 'Help',
            gl: 'Axuda',
            ca: 'Ajuda',
            eu: 'Laguntza',
            fr: 'Aide',
            it: 'Aiuto',
            pt: 'Ajuda',
            de: 'Hilfe',
            el: 'Βοήθεια',
            ru: 'Помощь',
            ar: 'مساعدة',
            zh: '帮助',
            ja: 'ヘルプ',
          ),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpScreen())),
        ),
        const _ShareButton(),
        if (DonationConfig.isEnabled) const _DonationCallout(),
        _CompactTile(
          icon: Icons.badge_outlined,
          label: tr(
            context,
            es: 'Acerca de',
            en: 'About',
            gl: 'Acerca de',
            ca: 'Quant a',
            eu: 'Honi buruz',
            fr: 'À propos',
            it: 'Informazioni',
            pt: 'Acerca de',
            de: 'Über',
            el: 'Σχετικά',
            ru: 'О приложении',
            ar: 'حول',
            zh: '关于',
            ja: 'このアプリについて',
          ),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutScreen())),
        ),
      ],
    );
  }
}

class _CompactTile extends StatelessWidget {
  const _CompactTile({required this.icon, required this.label, required this.onTap, this.help});

  final IconData icon;
  final String label;
  final String? help;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, size: 21),
      title: Text(label),
      subtitle: help == null ? null : Text(help!),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
    );
  }
}

// -----------------------------------------------------------------------------
// Cuenta
// -----------------------------------------------------------------------------

class _AccountSection extends ConsumerWidget {
  const _AccountSection({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSection(
      icon: Icons.person_outline_rounded,
      title: tr(
        context,
        es: 'Cuenta',
        en: 'Account',
        gl: 'Conta',
        ca: 'Compte',
        eu: 'Kontua',
        fr: 'Compte',
        it: 'Account',
        pt: 'Conta',
        de: 'Konto',
        el: 'Λογαριασμός',
        ru: 'Аккаунт',
        ar: 'الحساب',
        zh: '账户',
        ja: 'アカウント',
      ),
      summary: tr(
        context,
        es: 'Creada el ${DateFormat.yMMMd(localeTag(context)).format(user.createdAt)}',
        en: 'Created on ${DateFormat.yMMMd(localeTag(context)).format(user.createdAt)}',
        gl: 'Creada o ${DateFormat.yMMMd(localeTag(context)).format(user.createdAt)}',
        fr: 'Créé le ${DateFormat.yMMMd(localeTag(context)).format(user.createdAt)}',
        it: 'Creato il ${DateFormat.yMMMd(localeTag(context)).format(user.createdAt)}',
        pt: 'Criada em ${DateFormat.yMMMd(localeTag(context)).format(user.createdAt)}',
      ),
      children: [
        FilledButton.tonalIcon(
          onPressed: () async => ref.read(repositoryProvider).signOut(),
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: Text(
            tr(
              context,
              es: 'Cerrar sesión',
              en: 'Sign out',
              gl: 'Pechar sesión',
              ca: 'Tanca la sessió',
              eu: 'Amaitu saioa',
              fr: 'Se deconnecter',
              it: 'Esci',
              pt: 'Terminar sessão',
              de: 'Abmelden',
              el: 'Αποσύνδεση',
              ru: 'Выйти',
              ar: 'تسجيل الخروج',
              zh: '退出登录',
              ja: 'サインアウト',
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _confirmDeleteProfile(context, ref),
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFC62828)),
          icon: const Icon(Icons.delete_forever_rounded, size: 18),
          label: Text(
            tr(
              context,
              es: 'Eliminar perfil',
              en: 'Delete profile',
              gl: 'Eliminar perfil',
              ca: 'Elimina el perfil',
              eu: 'Ezabatu profila',
              fr: 'Supprimer le profil',
              it: 'Elimina profilo',
              pt: 'Eliminar perfil',
              de: 'Profil löschen',
              el: 'Διαγραφή προφίλ',
              ru: 'Удалить профиль',
              ar: 'حذف الملف الشخصي',
              zh: '删除个人资料',
              ja: 'プロフィールを削除',
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteProfile(BuildContext context, WidgetRef ref) async {
    final approved =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(
                tr(
                  context,
                  es: 'Eliminar perfil',
                  en: 'Delete profile',
                  gl: 'Eliminar perfil',
                  fr: 'Supprimer le profil',
                  it: 'Elimina profilo',
                  pt: 'Eliminar perfil',
                ),
              ),
              content: Text(
                tr(
                  context,
                  es: 'Tu cuenta se eliminará. Tus participaciones quedarán archivadas en los grupos para conservar el histórico.',
                  en: 'Your account will be deleted. Your group participation will remain archived to preserve history.',
                  gl: 'A túa conta eliminarase. As túas participacións quedarán arquivadas para conservar o histórico.',
                  fr: 'Votre compte sera supprime. Votre participation restera archivee pour conserver l historique.',
                  it: 'Il tuo account verra eliminato. La partecipazione restera archiviata per conservare lo storico.',
                  pt: 'A tua conta sera eliminada. As tuas participacoes ficarao arquivadas para preservar o historico.',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(tr(context, es: 'Cancelar', en: 'Cancel', gl: 'Cancelar', fr: 'Annuler', it: 'Annulla', pt: 'Cancelar')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC62828),
                    foregroundColor: colorOn(const Color(0xFFC62828)),
                  ),
                  child: Text(tr(context, es: 'Eliminar', en: 'Delete', gl: 'Eliminar', fr: 'Supprimer', it: 'Elimina', pt: 'Eliminar')),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!approved || !context.mounted) {
      return;
    }

    try {
      await ref.read(repositoryProvider).deleteUserProfile(user);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))));
      }
    }
  }
}

/// Traduce los motivos de rechazo de una copia.
String describeBackupError(BuildContext context, BackupError error) {
  switch (error) {
    case BackupError.unreadable:
      return tr(
        context,
        es: 'Ese fichero no se puede leer. ¿Seguro que es una copia de ShardPay?',
        en: 'That file cannot be read. Are you sure it is a ShardPay backup?',
        gl: 'Ese ficheiro non se pode ler. Seguro que é unha copia de ShardPay?',
        fr: 'Ce fichier est illisible. Êtes-vous sûr que c est une sauvegarde ShardPay ?',
        it: 'Quel file non è leggibile. Sicuro che sia una copia di ShardPay?',
        pt: 'Esse ficheiro não se consegue ler. De certeza que é uma cópia do ShardPay?',
      );
    case BackupError.notAShardPayBackup:
      return tr(
        context,
        es: 'Ese fichero no es una copia de ShardPay.',
        en: 'That file is not a ShardPay backup.',
        gl: 'Ese ficheiro non é unha copia de ShardPay.',
        fr: 'Ce fichier n est pas une sauvegarde ShardPay.',
        it: 'Quel file non è una copia di ShardPay.',
        pt: 'Esse ficheiro não é uma cópia do ShardPay.',
      );
    case BackupError.schemaTooNew:
      return tr(
        context,
        es: 'Esa copia viene de una versión más nueva de la app. Actualiza ShardPay e inténtalo otra vez.',
        en: 'That backup comes from a newer version of the app. Update ShardPay and try again.',
        gl: 'Esa copia vén dunha versión máis nova da app. Actualiza ShardPay e inténtao outra vez.',
        fr: 'Cette sauvegarde provient d une version plus récente. Mettez ShardPay à jour et réessayez.',
        it: 'Quella copia proviene da una versione più recente. Aggiorna ShardPay e riprova.',
        pt: 'Essa cópia vem de uma versão mais recente da app. Atualiza o ShardPay e tenta de novo.',
      );
    case BackupError.checksumMismatch:
      return tr(
        context,
        es: 'La copia está dañada o se ha modificado. No se ha restaurado nada.',
        en: 'The backup is damaged or has been modified. Nothing was restored.',
        gl: 'A copia está danada ou modificouse. Non se restaurou nada.',
        fr: 'La sauvegarde est endommagée ou a été modifiée. Rien n a été restauré.',
        it: 'La copia è danneggiata o è stata modificata. Non è stato ripristinato nulla.',
        pt: 'A cópia está danificada ou foi modificada. Não se restaurou nada.',
      );
    case BackupError.empty:
      return tr(
        context,
        es: 'Esa copia está vacía: no hay nada que restaurar.',
        en: 'That backup is empty: there is nothing to restore.',
        gl: 'Esa copia está baleira: non hai nada que restaurar.',
        fr: 'Cette sauvegarde est vide : il n y a rien à restaurer.',
        it: 'Quella copia è vuota: non c è nulla da ripristinare.',
        pt: 'Essa cópia está vazia: não há nada para restaurar.',
      );
  }
}

/// Botón de compartir la app, del mismo tamaño que el de invitar a un café.
///
/// **Con contorno y no relleno**, y esto no es una preferencia: se probó con
/// `FilledButton.tonal` y en varias paletas el color tonal es casi el mismo
/// naranja que el relleno, así que salían dos botones idénticos uno encima de
/// otro y la jerarquía desaparecía. El contorno se distingue en las trece
/// paletas, que es lo que tiene que cumplir.
///
/// Los dos son igual de grandes: lo que cambia es cuál pesa más. El único
/// relleno de la sección es el de invitar a un café.
class _ShareButton extends StatelessWidget {
  const _ShareButton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
            // El borde lleva el acento; el texto NO. Medido con `contrastRatio`:
            // en la paleta clara, `primary` sobre `surface` da 3,58:1, por
            // debajo del 4,5:1 que exige AA para texto de 16sp. El borde sí
            // puede ir de acento porque como elemento no textual le basta 3:1.
            side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
            foregroundColor: theme.colorScheme.onSurface,
            textStyle: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          icon: const Icon(Icons.share_rounded),
          onPressed: () => SharePlus.instance.share(
            ShareParams(
              text: tr(
                context,
                es: 'Uso ShardPay para repartir gastos en grupo: lee los tickets con la cámara y calcula quién debe qué. ${AppInfo.shareUrl}',
                en: 'I use ShardPay to split group expenses: it reads receipts with the camera and works out who owes what. ${AppInfo.shareUrl}',
                gl: 'Uso ShardPay para repartir gastos en grupo: le os tickets coa cámara e calcula quen debe que. ${AppInfo.shareUrl}',
                ca: 'Faig servir ShardPay per repartir despeses en grup: llegeix els tiquets amb la càmera. ${AppInfo.shareUrl}',
                eu: 'ShardPay erabiltzen dut taldeko gastuak banatzeko: tiketak kamerarekin irakurtzen ditu. ${AppInfo.shareUrl}',
                fr: 'J utilise ShardPay pour partager les dépenses de groupe : il lit les tickets avec l appareil photo. ${AppInfo.shareUrl}',
                it: 'Uso ShardPay per dividere le spese di gruppo: legge gli scontrini con la fotocamera. ${AppInfo.shareUrl}',
                pt: 'Uso o ShardPay para dividir despesas de grupo: lê as faturas com a câmara. ${AppInfo.shareUrl}',
                de: 'Ich teile Gruppenausgaben mit ShardPay: Es liest Belege mit der Kamera. ${AppInfo.shareUrl}',
                el: 'Χρησιμοποιώ το ShardPay για να μοιράζω έξοδα: διαβάζει τις αποδείξεις με την κάμερα. ${AppInfo.shareUrl}',
                ru: 'Я делю расходы с ShardPay: он читает чеки камерой. ${AppInfo.shareUrl}',
                ar: 'أستخدم ShardPay لتقسيم مصاريف المجموعة: يقرأ الإيصالات بالكاميرا. ${AppInfo.shareUrl}',
                zh: '我用 ShardPay 分摊团体开销，它能用相机识别小票。${AppInfo.shareUrl}',
                ja: 'グループの支出を ShardPay で分けています。カメラでレシートを読み取ります。${AppInfo.shareUrl}',
              ),
            ),
          ),
          label: Text(
            tr(
              context,
              es: 'Compartir ShardPay',
              en: 'Share ShardPay',
              gl: 'Compartir ShardPay',
              ca: 'Comparteix ShardPay',
              eu: 'Partekatu ShardPay',
              fr: 'Partager ShardPay',
              it: 'Condividi ShardPay',
              pt: 'Partilhar o ShardPay',
              de: 'ShardPay teilen',
              el: 'Μοιράσου το ShardPay',
              ru: 'Поделиться ShardPay',
              ar: 'شارك ShardPay',
              zh: '分享 ShardPay',
              ja: 'ShardPay を共有',
            ),
          ),
        ),
      ),
    );
  }
}

/// El acceso a la donación dentro de Ajustes.
///
/// Antes era una fila de lista más, entre «Compartir» y «Acerca de», y se
/// perdía: la única forma de invitar a un café era acertar a pulsar un renglón
/// que no parecía un botón. Ahora es un bloque con su botón grande.
///
/// Lo que **no** cambia, porque es lo que hace que esto no sea una compra: el
/// texto sigue diciendo que la app es gratuita y completa y que la donación no
/// desbloquea nada. Véase ADR-0008.
class _DonationCallout extends ConsumerWidget {
  const _DonationCallout();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final amount = NumberFormat.simpleCurrency(
      locale: localeTag(context),
      name: DonationConfig.currencyCode,
      decimalDigits: 0,
    ).format(DonationConfig.suggestedAmount);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6, bottom: 2),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_cafe_rounded, color: theme.colorScheme.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr(
                    context,
                    es: '¿Te invito yo o me invitas tú?',
                    en: 'My treat, or yours?',
                    gl: 'Convídoche eu ou convídasme ti?',
                    ca: 'Convido jo o convides tu?',
                    eu: 'Nik gonbidatzen zaitut ala zuk ni?',
                    fr: 'C est moi qui offre, ou vous ?',
                    it: 'Offro io o offri tu?',
                    pt: 'Pago eu ou pagas tu?',
                    de: 'Geht auf mich, oder auf dich?',
                    el: 'Κερνάω εγώ ή κερνάς εσύ;',
                    ru: 'Я угощаю или вы?',
                    ar: 'أنا أدعوك أم تدعوني؟',
                    zh: '我请你，还是你请我？',
                    ja: '私がおごる？　それとも…',
                  ),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              context,
              es: 'ShardPay es gratuita y completa, sin anuncios y sin recoger tus datos. Invitarme a un café no desbloquea nada.',
              en: 'ShardPay is free and complete, with no ads and no data collection. Buying me a coffee unlocks nothing.',
              gl: 'ShardPay é gratuíta e completa, sen anuncios e sen recoller os teus datos. Convidarme a un café non desbloquea nada.',
              ca: 'ShardPay és gratuïta i completa, sense anuncis ni recollida de dades. Convidar-me a un cafè no desbloqueja res.',
              eu: 'ShardPay doakoa eta osoa da, iragarkirik gabe eta zure daturik jaso gabe. Kafe batek ez du ezer desblokeatzen.',
              fr: 'ShardPay est gratuite et complète, sans publicité ni collecte de données. M offrir un café ne débloque rien.',
              it: 'ShardPay è gratuita e completa, senza pubblicità e senza raccogliere dati. Offrirmi un caffè non sblocca nulla.',
              pt: 'O ShardPay é gratuito e completo, sem anúncios e sem recolher dados. Oferecer-me um café não desbloqueia nada.',
              de: 'ShardPay ist kostenlos und vollständig, ohne Werbung und ohne Datensammlung. Ein Kaffee schaltet nichts frei.',
              el: 'Το ShardPay είναι δωρεάν και πλήρες, χωρίς διαφημίσεις και χωρίς συλλογή δεδομένων. Ένας καφές δεν ξεκλειδώνει τίποτα.',
              ru: 'ShardPay бесплатен и полон, без рекламы и без сбора данных. Кофе ничего не открывает.',
              ar: 'تطبيق ShardPay مجاني وكامل، بلا إعلانات وبلا جمع بيانات. القهوة لا تفتح أي شيء.',
              zh: 'ShardPay 免费且完整，没有广告，也不收集你的数据。请我喝咖啡不会解锁任何东西。',
              ja: 'ShardPay は無料で全機能が使え、広告もデータ収集もありません。コーヒーをおごっても何も解放されません。',
            ),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.35),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () => showDonationSheet(context, ref, fromSettings: true),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                textStyle: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              icon: const Icon(Icons.local_cafe_rounded),
              label: Text(
                tr(
                  context,
                  es: 'Invítame a un café · $amount',
                  en: 'Buy me a coffee · $amount',
                  gl: 'Convídame a un café · $amount',
                  ca: 'Convida m a un cafè · $amount',
                  eu: 'Gonbidatu kafe batera · $amount',
                  fr: 'Offrez-moi un café · $amount',
                  it: 'Offrimi un caffè · $amount',
                  pt: 'Oferece-me um café · $amount',
                  de: 'Spendier mir einen Kaffee · $amount',
                  el: 'Κέρασέ με έναν καφέ · $amount',
                  ru: 'Угостить кофе · $amount',
                  ar: 'ادعني إلى قهوة · $amount',
                  zh: '请我喝杯咖啡 · $amount',
                  ja: 'コーヒーをおごる · $amount',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
