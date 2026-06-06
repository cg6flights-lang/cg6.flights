import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/notifications/data/notification_repository.dart';
import 'package:cg6_flights/features/notifications/domain/notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationsProvider = StreamProvider<AppResult<List<AppNotification>>>((ref) {
  final repo = ref.read(notificationRepositoryProvider);
  return repo.watchNotifications();
});

final unreadCountProvider = FutureProvider<int>((ref) {
  final repo = ref.read(notificationRepositoryProvider);
  return repo.getUnreadCount().then((r) => switch (r) {
    AppSuccess(data: final c) => c,
    _ => 0,
  });
});
