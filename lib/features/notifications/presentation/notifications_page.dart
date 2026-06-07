import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/notifications/application/notification_providers.dart';
import 'package:cg6_flights/features/notifications/data/notification_repository.dart';
import 'package:cg6_flights/features/notifications/domain/notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  bool _showAll = true;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    final theme = Theme.of(context);
    final notifAsync = ref.watch(notificationsProvider);
    final repo = ref.read(notificationRepositoryProvider);

    final all = switch (notifAsync.asData?.value) {
      AppSuccess(data: final list) => list,
      _ => <AppNotification>[],
    };
    final filtered = _showAll ? all : all.where((n) => !n.isRead).toList();
    final hasUnread = all.any((n) => !n.isRead);
    final loading = notifAsync is AsyncLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).t('notifications.title')),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: () {
                final unreadIds = all.where((n) => !n.isRead).map((n) => n.id);
                repo.markAllAsRead(unreadIds);
              },
              child: const Text('Marcar todas leídas'),
            ),
          IconButton(
            icon: Icon(_showAll ? Icons.filter_list : Icons.filter_list_off, size: 20),
            tooltip: _showAll ? AppLocalizations.of(context).t('notifications.filterUnread') : AppLocalizations.of(context).t('notifications.filterAll'),
            onPressed: () => setState(() => _showAll = !_showAll),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : filtered.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.notifications_off_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant),
                    SizedBox(height: 12),
                    Text(_showAll ? 'Sin notificaciones' : 'Sin notificaciones no leídas',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  ]),
                )
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final n = filtered[i];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: n.isRead
                            ? theme.colorScheme.surfaceContainerHighest
                            : theme.colorScheme.primary.withValues(alpha: 0.1),
                        child: Icon(
                          n.isRead ? Icons.notifications_none : Icons.notifications_active,
                          size: 16,
                          color: n.isRead ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.primary,
                        ),
                      ),
                      title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.w600, fontSize: 14)),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(height: 2),
                        Text(n.body, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
                        SizedBox(height: 2),
                        Text(_timeFormat(n.createdAt), style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6))),
                      ]),
                      onTap: () {
                        if (!n.isRead) repo.markAsRead(n.id);
                      },
                    );
                  },
                ),
    );
  }

  String _timeFormat(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
