import 'package:cg6_flights/features/dashboard/domain/dashboard_widget_config.dart';
import 'package:cg6_flights/features/dashboard/presentation/widgets/dashboard_widget_base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class QuickActionsWidget extends ConsumerWidget {
  const QuickActionsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return DashboardWidgetWrapper(
      config: DashboardWidgetConfig.byId('quick_actions')!,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        child: Wrap(spacing: 6, runSpacing: 6, children: [
          _action(Icons.assignment_add, 'Nueva OV', () => context.go('/flight-orders'), theme),
          _action(Icons.flight_takeoff, 'Vuelos', () => context.go('/flights'), theme),
          _action(Icons.flight, 'Aeronaves', () => context.go('/aircraft'), theme),
          _action(Icons.people, 'Tripulación', () => context.go('/crew'), theme),
          _action(Icons.fact_check, 'Auditoría', () => context.go('/audit'), theme),
          _action(Icons.route, 'Rutas', () => context.go('/routes'), theme),
        ]),
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap, ThemeData theme) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.labelSmall),
        ]),
      ),
    );
  }
}
