import 'package:cg6_flights/app/i18n/app_localizations.dart';
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
    final t = AppLocalizations.of(context).t;
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
              child: Row(
                children: [
                  if (editMode && dragHandle != null) ...[
                    dragHandle!,
                    const SizedBox(width: 4),
                  ],
                  Icon(config.icon, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    _titleFor(config.id, context),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
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
                ],
              ),
            ),
            // Content (collapsible)
            if (isExpanded) child,
          ],
        ),
      ),
    );
  }

  String _titleFor(String id, BuildContext context) {
    final t = AppLocalizations.of(context).t;
    return switch (id) {
      'map' => t('dashboard.widget.map'),
      'zulu_clock' => t('dashboard.widget.zuluClock'),
      'romeo_clock' => t('dashboard.widget.romeoClock'),
      'kpis' => t('dashboard.widget.kpis'),
      'timeline' => t('dashboard.widget.timeline'),
      'upcoming' => t('dashboard.widget.upcoming'),
      'metar' => t('dashboard.widget.metar'),
      'operability' => t('dashboard.widget.operability'),
      'notifications' => t('dashboard.widget.notifications'),
      'activity' => t('dashboard.widget.activity'),
      'fleet' => t('dashboard.widget.fleet'),
      'resumen' => t('dashboard.widget.resumen'),
      'quick_actions' => t('dashboard.widget.quickActions'),
      'calendar_mini' => t('dashboard.widget.calendarMini'),
      _ => id,
    };
  }
}
