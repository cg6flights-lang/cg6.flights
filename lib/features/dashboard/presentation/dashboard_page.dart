import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/realtime/realtime_invalidator.dart';
import 'package:cg6_flights/features/auth/application/session_controller.dart';
import 'package:cg6_flights/features/dashboard/application/dashboard_preferences.dart';
import 'package:cg6_flights/features/dashboard/application/dashboard_providers.dart';
import 'package:cg6_flights/features/dashboard/domain/dashboard_widget_config.dart';
import 'package:cg6_flights/features/dashboard/presentation/widgets/activity_widget.dart';
import 'package:cg6_flights/features/dashboard/presentation/widgets/aviation_clock_widget.dart';
import 'package:cg6_flights/features/dashboard/presentation/widgets/calendar_mini_widget.dart';
import 'package:cg6_flights/features/dashboard/presentation/widgets/fleet_status_widget.dart';
import 'package:cg6_flights/features/dashboard/presentation/widgets/kpis_widget.dart';
import 'package:cg6_flights/features/dashboard/presentation/widgets/map_widget.dart';
import 'package:cg6_flights/features/dashboard/presentation/widgets/metar_dashboard_widget.dart';
import 'package:cg6_flights/features/dashboard/presentation/widgets/notifications_widget.dart';
import 'package:cg6_flights/features/dashboard/presentation/widgets/operability_chart_widget.dart';
import 'package:cg6_flights/features/dashboard/presentation/widgets/quick_actions_widget.dart';
import 'package:cg6_flights/features/dashboard/presentation/widgets/resumen_widget.dart';
import 'package:cg6_flights/features/dashboard/presentation/widgets/timeline_widget.dart';
import 'package:cg6_flights/features/dashboard/presentation/widgets/upcoming_flights_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});
  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool _editMode = false;
  static const _clockWidgetIds = {'zulu_clock', 'romeo_clock'};
  RealtimeInvalidator? _realtime;

  @override
  void initState() {
    super.initState();
    _realtime = RealtimeInvalidator(
      channelName: 'dashboard-page',
      tables: const [
        'flight_orders',
        'flight_order_items',
        'flight_order_state_events',
        'aircraft',
      ],
      onChange: () {
        if (!mounted) return;
        ref.invalidate(todayFlightsProvider);
        ref.invalidate(aircraftStatusProvider);
        ref.invalidate(dashboardFleetProvider);
      },
    );
  }

  @override
  void dispose() {
    _realtime?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(sessionControllerProvider).user;
    final allPrefs = ref.watch(dashboardPreferencesProvider);

    final visible = allPrefs.where((p) => p.visible).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            theme: theme,
            l10n: l10n,
            roleLabel: user?.role?.labelEs,
            editMode: _editMode,
            onEditToggle: () => setState(() => _editMode = !_editMode),
            onCustomize: () => _showCustomizeSheet(),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: visible.isEmpty
                ? const Center(
                    child: Text(
                      'Sin widgets visibles.',
                      style: TextStyle(fontSize: 14),
                    ),
                  )
                : _editMode
                ? _buildEditView(allPrefs, theme)
                : _buildGrid(visible, theme),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  NORMAL GRID
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildGrid(List<WidgetPref> visible, ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final twoCols = width >= 700;
        final leftFrac = width >= 1100 ? 2 / 3 : 1 / 2;
        const gap = 8.0;

        final clocks = visible
            .where((p) => _clockWidgetIds.contains(p.id))
            .toList();
        final wide = visible
            .where((p) => p.span >= 2 && !_clockWidgetIds.contains(p.id))
            .toList();
        final narrow = visible
            .where((p) => p.span == 1 && !_clockWidgetIds.contains(p.id))
            .toList();

        if (!twoCols) {
          return SingleChildScrollView(
            child: Column(
              children: [
                for (final w in visible)
                  Padding(
                    padding: EdgeInsets.only(bottom: gap),
                    child: _widgetFor(w.id),
                  ),
              ],
            ),
          );
        }

        final leftW = (width - gap) * leftFrac;
        final rightW = (width - gap) * (1 - leftFrac);

        return SingleChildScrollView(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: leftW,
                child: Column(
                  children: [
                    if (clocks.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(bottom: gap),
                        child: _buildClockRow(clocks, gap),
                      ),
                    for (final w in wide)
                      Padding(
                        padding: EdgeInsets.only(bottom: gap),
                        child: _widgetFor(w.id),
                      ),
                  ],
                ),
              ),
              SizedBox(width: gap),
              SizedBox(
                width: rightW,
                child: Column(
                  children: [
                    for (final w in narrow)
                      Padding(
                        padding: EdgeInsets.only(bottom: gap),
                        child: _widgetFor(w.id),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClockRow(List<WidgetPref> clocks, double gap) {
    if (clocks.length == 1) return _widgetFor(clocks.first.id);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < clocks.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(child: _widgetFor(clocks[i].id)),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  EDIT VIEW
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildEditView(List<WidgetPref> all, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Long-press ≡ para arrastrar y reordenar. -/+ cambia ancho. 👁 visibilidad.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            itemCount: all.length,
            onReorder: (oldIndex, newIndex) {
              ref
                  .read(dashboardPreferencesProvider.notifier)
                  .move(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final pref = all[index];
              final config = DashboardWidgetConfig.byId(pref.id);
              if (config == null) return const SizedBox.shrink();

              final visibilityIcon = pref.visible
                  ? Icons.visibility
                  : Icons.visibility_off;
              final visibilityColor = pref.visible
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4);

              return Card(
                key: ValueKey(pref.id),
                margin: const EdgeInsets.only(bottom: 6),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: index,
                        child: Icon(
                          Icons.drag_indicator,
                          size: 22,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        config.icon,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context).t(config.titleKey),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      _spanChip(pref, theme),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => ref
                            .read(dashboardPreferencesProvider.notifier)
                            .toggleVisibility(pref.id),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            visibilityIcon,
                            size: 20,
                            color: visibilityColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _spanChip(WidgetPref pref, ThemeData theme) {
    final notifier = ref.read(dashboardPreferencesProvider.notifier);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            if (pref.span > 1) notifier.setSpan(pref.id, pref.span - 1);
          },
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: const Icon(Icons.remove, size: 14),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            '${pref.span}',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        InkWell(
          onTap: () {
            if (pref.span < 3) notifier.setSpan(pref.id, pref.span + 1);
          },
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: const Icon(Icons.add, size: 14),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════

  Widget _widgetFor(String id) {
    final session = ref.watch(sessionControllerProvider);
    final unitId = session.user?.unitId;
    final squadronId = session.user?.squadronId;
    final isGlobal = session.user?.role?.isGlobal ?? false;

    return switch (id) {
      'map' => const MapWidget(),
      'zulu_clock' => const ZuluClockWidget(),
      'romeo_clock' => const RomeoClockWidget(),
      'kpis' => KpisWidget(
        unitId: isGlobal ? null : unitId,
        squadronId: isGlobal ? null : squadronId,
      ),
      'timeline' => TimelineWidget(
        unitId: isGlobal ? null : unitId,
        squadronId: isGlobal ? null : squadronId,
      ),
      'upcoming' => UpcomingFlightsWidget(
        unitId: isGlobal ? null : unitId,
        squadronId: isGlobal ? null : squadronId,
      ),
      'metar' => const MetarDashboardWidget(),
      'operability' => const OperabilityChartWidget(),
      'notifications' => const NotificationsWidget(),
      'activity' => ActivityWidget(
        unitId: isGlobal ? null : unitId,
        squadronId: isGlobal ? null : squadronId,
      ),
      'fleet' => FleetStatusWidget(
        unitId: isGlobal ? null : unitId,
        squadronId: isGlobal ? null : squadronId,
      ),
      'resumen' => ResumenWidget(
        unitId: isGlobal ? null : unitId,
        squadronId: isGlobal ? null : squadronId,
      ),
      'quick_actions' => const QuickActionsWidget(),
      'calendar_mini' => const CalendarMiniWidget(),
      _ => const SizedBox.shrink(),
    };
  }

  void _showCustomizeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => const _CustomizeSheet(),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.theme,
    required this.l10n,
    required this.roleLabel,
    required this.editMode,
    required this.onEditToggle,
    required this.onCustomize,
  });
  final ThemeData theme;
  final AppLocalizations l10n;
  final String? roleLabel;
  final bool editMode;
  final VoidCallback onEditToggle;
  final VoidCallback onCustomize;

  @override
  Widget build(BuildContext context) {
    final title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.dashboard_outlined,
          color: theme.colorScheme.primary,
          size: 22,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Dashboard operacional',
            style: theme.textTheme.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (roleLabel != null) ...[
          const SizedBox(width: 10),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Text(
                roleLabel!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ],
    );
    final actions = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        children: [
          _Btn(
            icon: editMode ? Icons.check : Icons.edit_outlined,
            label: editMode ? 'Listo' : 'Editar',
            onTap: onEditToggle,
          ),
          const SizedBox(width: 6),
          _Btn(icon: Icons.tune, label: 'Personalizar', onTap: onCustomize),
          const SizedBox(width: 6),
          _Btn(
            icon: Icons.assignment_outlined,
            label: 'Nueva OV',
            onTap: () => context.go('/flight-orders'),
          ),
          const SizedBox(width: 6),
          _Btn(
            icon: Icons.flight_takeoff,
            label: 'Vuelos',
            onTap: () => context.go('/flights'),
          ),
          const SizedBox(width: 6),
          _Btn(
            icon: Icons.mark_unread_chat_alt_outlined,
            label: 'Mensajes',
            onTap: () => context.go('/messages'),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [title, const SizedBox(height: 8), actions],
          );
        }
        return Row(
          children: [
            Expanded(child: title),
            const SizedBox(width: 12),
            Expanded(child: actions),
          ],
        );
      },
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label, style: theme.textTheme.labelSmall),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// ── Customize sheet ───────────────────────────────────────────────────

class _CustomizeSheet extends ConsumerWidget {
  const _CustomizeSheet();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prefs = ref.watch(dashboardPreferencesProvider);
    return SizedBox(
      height: 500,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Text(
                  'Personalizar Dashboard',
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => ref
                      .read(dashboardPreferencesProvider.notifier)
                      .resetToDefaults(),
                  icon: const Icon(Icons.restore, size: 16),
                  label: const Text('Restablecer'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: prefs.length,
              onReorder: (o, n) =>
                  ref.read(dashboardPreferencesProvider.notifier).move(o, n),
              itemBuilder: (ctx, i) {
                final p = prefs[i];
                final c = DashboardWidgetConfig.byId(p.id);
                if (c == null) return const SizedBox.shrink();
                return ListTile(
                  key: ValueKey(p.id),
                  leading: Icon(
                    Icons.drag_handle,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  title: Row(
                    children: [
                      Icon(c.icon, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context).t(c.titleKey)),
                    ],
                  ),
                  trailing: Switch(
                    value: p.visible,
                    onChanged: (_) => ref
                        .read(dashboardPreferencesProvider.notifier)
                        .toggleVisibility(p.id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
