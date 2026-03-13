import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/app_text.dart';
import '../../app/preferences.dart';
import '../../app/providers.dart';
import '../../models/app_models.dart';
import '../../widgets/language_flag.dart';
import '../../widgets/manual/user_manual_sheet.dart';
import '../notifications/notifications_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(appPreferencesProvider);
    final notifier = ref.read(appPreferencesProvider.notifier);
    final notificationsState = ref.watch(notificationsProvider(user.id));
    final unreadCount = notificationsState.maybeWhen(
      data: (items) => items.where((item) => !item.isRead).length,
      orElse: () => 0,
    );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            tr(context, es: 'Ajustes', en: 'Settings', gl: 'Axustes', fr: 'Reglages', it: 'Impostazioni', pt: 'Ajustes'),
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(radius: 26, child: Text(user.displayName.substring(0, 1).toUpperCase())),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.displayName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(user.email, style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 4),
                        Text(
                          tr(
                            context,
                            es: 'Cuenta creada: ${DateFormat.yMMMMd(localeTag(context)).format(user.createdAt)}',
                            en: 'Account created: ${DateFormat.yMMMMd(localeTag(context)).format(user.createdAt)}',
                            gl: 'Conta creada: ${DateFormat.yMMMMd(localeTag(context)).format(user.createdAt)}',
                            fr: 'Compte cree le : ${DateFormat.yMMMMd(localeTag(context)).format(user.createdAt)}',
                            it: 'Account creato il: ${DateFormat.yMMMMd(localeTag(context)).format(user.createdAt)}',
                            pt: 'Conta criada em: ${DateFormat.yMMMMd(localeTag(context)).format(user.createdAt)}',
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr(
                            context,
                            es: 'ID de usuario: ${user.id}',
                            en: 'User ID: ${user.id}',
                            gl: 'ID de usuario: ${user.id}',
                            fr: 'ID utilisateur : ${user.id}',
                            it: 'ID utente: ${user.id}',
                            pt: 'ID do utilizador: ${user.id}',
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(context, es: 'Tema', en: 'Theme', gl: 'Tema', fr: 'Theme', it: 'Tema', pt: 'Tema'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      context,
                      es: 'Elige una paleta para toda la app.',
                      en: 'Choose one palette for the whole app.',
                      gl: 'Escolle unha paleta para toda a app.',
                      fr: 'Choisissez une palette pour toute l app.',
                      it: 'Scegli una palette per tutta l app.',
                      pt: 'Escolhe uma paleta para toda a app.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: preferences.themeId,
                    decoration: InputDecoration(
                      labelText: tr(context, es: 'Modo visual', en: 'Visual mode', gl: 'Modo visual', fr: 'Mode visuel', it: 'Modalita visiva', pt: 'Modo visual'),
                    ),
                    items: appThemeOptions.map((option) {
                      return DropdownMenuItem(
                        value: option.id,
                        child: Row(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: option.accent,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: option.secondary),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${option.label} · ${option.brightness == Brightness.dark ? tr(context, es: 'oscuro', en: 'dark', gl: 'escuro', fr: 'sombre', it: 'scuro', pt: 'escuro') : tr(context, es: 'claro', en: 'light', gl: 'claro', fr: 'clair', it: 'chiaro', pt: 'claro')}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        notifier.selectTheme(value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(context, es: 'Idioma', en: 'Language', gl: 'Idioma', fr: 'Langue', it: 'Lingua', pt: 'Idioma'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      context,
                      es: 'Cambia el idioma de la interfaz y de los formatos.',
                      en: 'Change interface and formatting language.',
                      gl: 'Cambia o idioma da interface e dos formatos.',
                      fr: 'Changez la langue de l interface et des formats.',
                      it: 'Cambia la lingua dell interfaccia e dei formati.',
                      pt: 'Muda o idioma da interface e dos formatos.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: preferences.languageCode,
                    decoration: InputDecoration(
                      labelText: tr(context, es: 'Idioma activo', en: 'Active language', gl: 'Idioma activo', fr: 'Langue active', it: 'Lingua attiva', pt: 'Idioma ativo'),
                    ),
                    items: appLanguageOptions.map((option) {
                      return DropdownMenuItem(
                        value: option.code,
                        child: Row(
                          children: [
                            LanguageFlag(code: option.code),
                            const SizedBox(width: 10),
                            Expanded(child: Text(option.label, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        notifier.selectLanguage(value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr(context, es: 'Notificaciones', en: 'Notifications', gl: 'Notificacions', fr: 'Notifications', it: 'Notifiche', pt: 'Notificacoes'),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            tr(context, es: '$unreadCount sin leer', en: '$unreadCount unread', gl: '$unreadCount sen ler', fr: '$unreadCount non lues', it: '$unreadCount non lette', pt: '$unreadCount por ler'),
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: preferences.expenseNotificationsEnabled,
                    onChanged: notifier.setExpenseNotificationsEnabled,
                    title: Text(tr(context, es: 'Nuevos gastos', en: 'New expenses', gl: 'Novos gastos', fr: 'Nouvelles depenses', it: 'Nuove spese', pt: 'Novas despesas')),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: preferences.refundNotificationsEnabled,
                    onChanged: notifier.setRefundNotificationsEnabled,
                    title: Text(tr(context, es: 'Reembolsos registrados', en: 'Recorded reimbursements', gl: 'Reembolsos rexistrados', fr: 'Remboursements enregistres', it: 'Rimborsi registrati', pt: 'Reembolsos registados')),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: preferences.refundRequestNotificationsEnabled,
                    onChanged: notifier.setRefundRequestNotificationsEnabled,
                    title: Text(tr(context, es: 'Solicitudes de reembolso', en: 'Reimbursement requests', gl: 'Solicitudes de reembolso', fr: 'Demandes de remboursement', it: 'Richieste di rimborso', pt: 'Pedidos de reembolso')),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NotificationsScreen(user: user))),
                    icon: const Icon(Icons.notifications_active_rounded),
                    label: Text(tr(context, es: 'Abrir centro de notificaciones', en: 'Open notification center', gl: 'Abrir centro de notificacions', fr: 'Ouvrir le centre de notifications', it: 'Apri centro notifiche', pt: 'Abrir centro de notificacoes')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(context, es: 'Manual', en: 'Manual', gl: 'Manual', fr: 'Guide', it: 'Manuale', pt: 'Manual'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(context, es: 'Puedes volver a abrir la guía rápida cuando quieras.', en: 'You can reopen the quick guide whenever you want.', gl: 'Podes volver abrir a guia rapida cando queiras.', fr: 'Vous pouvez rouvrir le guide rapide quand vous voulez.', it: 'Puoi riaprire la guida rapida quando vuoi.', pt: 'Podes voltar a abrir o guia rapido quando quiseres.'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      await showUserManualSheet(context);
                      notifier.markManualSeen();
                    },
                    icon: const Icon(Icons.menu_book_rounded),
                    label: Text(tr(context, es: 'Abrir manual', en: 'Open manual', gl: 'Abrir manual', fr: 'Ouvrir le guide', it: 'Apri manuale', pt: 'Abrir manual')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async => ref.read(repositoryProvider).signOut(),
            icon: const Icon(Icons.logout_rounded),
            label: Text(tr(context, es: 'Cerrar sesión', en: 'Sign out', gl: 'Pechar sesion', fr: 'Se deconnecter', it: 'Esci', pt: 'Terminar sessao')),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _confirmDeleteProfile(context, ref),
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFC62828)),
            icon: const Icon(Icons.delete_forever_rounded),
            label: Text(tr(context, es: 'Eliminar perfil', en: 'Delete profile', gl: 'Eliminar perfil', fr: 'Supprimer le profil', it: 'Elimina profilo', pt: 'Eliminar perfil')),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteProfile(BuildContext context, WidgetRef ref) async {
    final approved = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(tr(context, es: 'Eliminar perfil', en: 'Delete profile', gl: 'Eliminar perfil', fr: 'Supprimer le profil', it: 'Elimina profilo', pt: 'Eliminar perfil')),
              content: Text(tr(context, es: 'Tu cuenta se eliminará. Tus participaciones quedarán archivadas en los grupos para conservar el histórico.', en: 'Your account will be deleted. Your group participation will remain archived to preserve history.', gl: 'A tua conta eliminarase. As tuas participacions quedaran arquivadas para conservar o historico.', fr: 'Votre compte sera supprime. Votre participation restera archivee pour conserver l historique.', it: 'Il tuo account verra eliminato. La partecipazione restera archiviata per conservare lo storico.', pt: 'A tua conta sera eliminada. As tuas participacoes ficarao arquivadas para preservar o historico.')),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(tr(context, es: 'Cancelar', en: 'Cancel', gl: 'Cancelar', fr: 'Annuler', it: 'Annulla', pt: 'Cancelar'))),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828), foregroundColor: Colors.white),
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