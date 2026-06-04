import 'package:cg6_flights/features/dashboard/domain/dashboard_widget_config.dart';
import 'package:flutter/material.dart';

class DashboardWidgetWrapper extends StatelessWidget {
  const DashboardWidgetWrapper({
    super.key,
    required this.config,
    required this.child,
    this.editMode = false,
    this.isDragged = false,
    this.isExpanded = true,
    this.onToggleExpand,
    this.dragHandle,
  });

  final DashboardWidgetConfig config;
  final Widget child;
  final bool editMode;
  final bool isDragged;
  final bool isExpanded;
  final VoidCallback? onToggleExpand;
  final Widget? dragHandle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isDragged ? 0.3 : 1.0,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(children: [
                if (editMode && dragHandle != null) ...[
                  dragHandle!,
                  const SizedBox(width: 4),
                ],
                Icon(config.icon, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  _titleFor(config.id),
                  style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (editMode && onToggleExpand != null)
                  InkWell(
                    onTap: onToggleExpand,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ]),
            ),
            // Content (collapsible)
            if (isExpanded) child,
          ],
        ),
      ),
    );
  }

  String _titleFor(String id) {
    return switch (id) {
      'map' => 'Mapa de Operaciones',
      'kpis' => 'KPIs',
      'timeline' => 'Timeline de Vuelos',
      'upcoming' => 'Próximos Vuelos',
      'metar' => 'METAR',
      'operability' => 'Operatividad',
      'notifications' => 'Notificaciones',
      'activity' => 'Actividad',
      'fleet' => 'Flota',
      'resumen' => 'Resumen del Día',
      'quick_actions' => 'Acciones Rápidas',
      'calendar_mini' => 'Calendario',
      _ => id,
    };
  }
}
