import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/dashboard/application/dashboard_providers.dart';
import 'package:cg6_flights/features/dashboard/domain/dashboard_widget_config.dart';
import 'package:cg6_flights/features/dashboard/presentation/widgets/dashboard_widget_base.dart';
import 'package:cg6_flights/features/messages/domain/message_post.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class NotificationsWidget extends ConsumerWidget {
  const NotificationsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(recentPostsProvider);

    final child = postsAsync.when(
      loading: () => const _Centered(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, _) => const _Centered(child: Icon(Icons.error_outline, size: 20)),
      data: (result) => switch (result) {
        AppSuccess(data: final posts) => _NotificationsContent(posts: posts),
        AppFailure() => const _Centered(child: Icon(Icons.error_outline, size: 20)),
      },
    );

    return DashboardWidgetWrapper(
      config: DashboardWidgetConfig.byId('notifications')!,
      child: child,
    );
  }
}

class _NotificationsContent extends StatelessWidget {
  const _NotificationsContent({required this.posts});
  final List<MessagePost> posts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recent = posts.take(5).toList();

    if (recent.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('Sin notificaciones', style: TextStyle(fontSize: 12))),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ...recent.map((post) => _PostRow(post: post, theme: theme)),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: InkWell(
            onTap: () => context.go('/messages'),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Text('Ver más →', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _PostRow extends StatelessWidget {
  const _PostRow({required this.post, required this.theme});
  final MessagePost post;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(post.scope == MessagePostScope.global ? Icons.public : Icons.group, size: 12, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(post.body, style: theme.textTheme.labelSmall?.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(post.shortTime, style: theme.textTheme.labelSmall?.copyWith(fontSize: 9, color: theme.colorScheme.onSurfaceVariant)),
          ]),
        ),
      ]),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Center(child: child),
  );
}
