import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/app_text.dart';
import '../../app/providers.dart';
import '../../models/app_models.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsState = ref.watch(notificationsProvider(user.id));
    final preferences = ref.watch(appPreferencesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(
            context,
            es: 'Notificaciones',
            en: 'Notifications',
            gl: 'Notificacions',
            fr: 'Notifications',
            it: 'Notifiche',
            pt: 'Notificacoes',
          ),
        ),
      ),
      body: notificationsState.when(
        data: (notifications) {
          final visible = notifications.where((notification) {
            switch (notification.type) {
              case AppNotificationType.expenseAdded:
                return preferences.expenseNotificationsEnabled;
              case AppNotificationType.reimbursementRecorded:
                return preferences.refundNotificationsEnabled;
              case AppNotificationType.reimbursementRequested:
              case AppNotificationType.groupSettlementRequested:
                return preferences.refundRequestNotificationsEnabled;
            }
          }).toList();

          if (visible.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr(
                    context,
                    es: 'No hay notificaciones con los filtros actuales.',
                    en: 'There are no notifications with the current filters.',
                    gl: 'Non hai notificacions cos filtros actuais.',
                    fr: 'Aucune notification avec les filtres actuels.',
                    it: 'Non ci sono notifiche con i filtri attuali.',
                    pt: 'Nao ha notificacoes com os filtros atuais.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: visible.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final notification = visible[index];
              return InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => ref.read(repositoryProvider).markNotificationRead(userId: user.id, notificationId: notification.id),
                child: Ink(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: notification.isRead
                        ? Theme.of(context).colorScheme.surfaceContainerLow
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: notification.isRead
                          ? Theme.of(context).colorScheme.outlineVariant
                          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.26),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: _notificationColor(notification.type).withValues(alpha: 0.16),
                        child: Icon(_notificationIcon(notification.type), color: _notificationColor(notification.type)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(notification.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(notification.message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.35)),
                            const SizedBox(height: 8),
                            Text(
                              DateFormat('dd/MM/yyyy HH:mm', localeTag(context)).format(notification.createdAt),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        error: (error, _) => Center(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

Color _notificationColor(AppNotificationType type) {
  switch (type) {
    case AppNotificationType.expenseAdded:
      return const Color(0xFF1B998B);
    case AppNotificationType.reimbursementRecorded:
      return const Color(0xFF3A86FF);
    case AppNotificationType.reimbursementRequested:
      return const Color(0xFFE4572E);
    case AppNotificationType.groupSettlementRequested:
      return const Color(0xFF6A4C93);
  }
}

IconData _notificationIcon(AppNotificationType type) {
  switch (type) {
    case AppNotificationType.expenseAdded:
      return Icons.receipt_long_rounded;
    case AppNotificationType.reimbursementRecorded:
      return Icons.payments_rounded;
    case AppNotificationType.reimbursementRequested:
      return Icons.notification_important_rounded;
    case AppNotificationType.groupSettlementRequested:
      return Icons.campaign_rounded;
  }
}
