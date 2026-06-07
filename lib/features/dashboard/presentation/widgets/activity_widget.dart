import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/audit/domain/audit_log.dart';
import 'package:cg6_flights/features/dashboard/application/dashboard_providers.dart';
import 'package:cg6_flights/features/dashboard/domain/dashboard_widget_config.dart';
import 'package:cg6_flights/core/state/timezone_provider.dart';
import 'package:cg6_flights/features/dashboard/presentation/widgets/dashboard_widget_base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ActivityWidget extends ConsumerWidget {
  const ActivityWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(recentActivityProvider);
    final tz = ref.watch(timezoneProvider);

    final child = activityAsync.when(
      loading: () => const _Centered(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, _) => const _Centered(child: Icon(Icons.error_outline, size: 20)),
      data: (r) => _ActivityContent(
        logs: switch (r) { AppSuccess(data: final d) => d, _ => [] },
        tz: tz,
      ),
    );

    return DashboardWidgetWrapper(
      config: DashboardWidgetConfig.byId('activity')!,
      child: child,
    );
  }
}

class _ActivityContent extends StatelessWidget {
  const _ActivityContent({required this.logs, required this.tz});
  final List<AuditLog> logs;
  final int tz;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recent = logs.take(8).toList();
    if (recent.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('Sin actividad reciente', style: TextStyle(fontSize: 12))),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ...recent.map((log) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(children: [
            Text(
              formatTimeWithOffset(log.createdAt, tz),
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 10),
            ),
            const SizedBox(width: 4),
            _dot(log.result),
            const SizedBox(width: 4),
            Expanded(child: Text('${log.action} ${log.resourceType}', style: theme.textTheme.labelSmall?.copyWith(fontSize: 11), overflow: TextOverflow.ellipsis)),
          ]),
        )),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: InkWell(
            onTap: () => context.go('/audit'),
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

  Widget _dot(String result) {
    final color = switch (result) {
      'success' => Colors.green, 'denied' => Colors.orange, 'failed' => Colors.red, _ => Colors.grey,
    };
    return Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
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
