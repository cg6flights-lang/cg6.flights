import 'dart:math' as math;

import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/core/security/app_permission.dart';
import 'package:cg6_flights/features/auth/application/session_controller.dart';
import 'package:cg6_flights/features/calendar/data/calendar_repository.dart';
import 'package:cg6_flights/features/calendar/domain/calendar_event.dart';
import 'package:cg6_flights/features/calendar/presentation/calendar_event_form_dialog.dart';
import 'package:cg6_flights/shared/widgets/data_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _calendarEventsProvider = FutureProvider.autoDispose
    .family<AppResult<List<CalendarEvent>>, _Range>(
      (ref, range) => ref
          .read(calendarRepositoryProvider)
          .listEvents(from: range.from, to: range.to),
    );

enum _CalendarTab { overview, calendar, activities }

enum _CalendarDetailAction { edit, start, complete }

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  late DateTime _visibleMonth;
  late DateTime _selectedDate;
  _CalendarTab _tab = _CalendarTab.overview;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  _Range get _range {
    final from = DateTime(_visibleMonth.year, _visibleMonth.month);
    final to = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
      23,
      59,
      59,
    );
    return _Range(from, to);
  }

  void _previousMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
      final now = DateTime.now();
      _selectedDate =
          _visibleMonth.year == now.year && _visibleMonth.month == now.month
          ? DateTime(now.year, now.month, now.day)
          : DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
      final now = DateTime.now();
      _selectedDate =
          _visibleMonth.year == now.year && _visibleMonth.month == now.month
          ? DateTime(now.year, now.month, now.day)
          : DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    });
  }

  Future<void> _openEventDialog({CalendarEvent? event}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          CalendarEventFormDialog(event: event, initialDate: _selectedDate),
    );
    if (saved == true && mounted) {
      ref.invalidate(_calendarEventsProvider(_range));
    }
  }

  Future<void> _deleteEvent(CalendarEvent event) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.t('calendar.deleteEvent')),
        content: Text(l10n.t('calendar.deleteConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.t('common.cancel')),
          ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: Text(l10n.t('calendar.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await ref
        .read(calendarRepositoryProvider)
        .deleteEvent(event.id);
    if (!mounted) return;
    switch (result) {
      case AppSuccess<void>():
        ref.invalidate(_calendarEventsProvider(_range));
      case AppFailure<void>(error: final error):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _updateEventStatus(
    CalendarEvent event,
    CalendarEventStatus status,
  ) async {
    final result = await ref
        .read(calendarRepositoryProvider)
        .updateEventStatus(eventId: event.id, status: status);
    if (!mounted) return;
    switch (result) {
      case AppSuccess<void>():
        ref.invalidate(_calendarEventsProvider(_range));
      case AppFailure<void>(error: final error):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _openEventDetail(CalendarEvent event) async {
    final canManage = ref
        .read(sessionControllerProvider)
        .can(AppPermission.calendarManage);
    final action = await showDialog<_CalendarDetailAction>(
      context: context,
      builder: (_) =>
          _CalendarEventDetailDialog(event: event, canManage: canManage),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _CalendarDetailAction.edit:
        await _openEventDialog(event: event);
      case _CalendarDetailAction.start:
        await _updateEventStatus(event, CalendarEventStatus.inProgress);
      case _CalendarDetailAction.complete:
        await _updateEventStatus(event, CalendarEventStatus.completed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionControllerProvider);
    final canManage = session.can(AppPermission.calendarManage);
    final eventsAsync = ref.watch(_calendarEventsProvider(_range));
    final compact = MediaQuery.sizeOf(context).width < 620;

    return Padding(
      padding: EdgeInsets.all(compact ? 12 : 24),
      child: eventsAsync.when(
        loading: () => DataStateView(
          kind: DataStateKind.loading,
          title: l10n.t('calendar.loading'),
        ),
        error: (error, stackTrace) => DataStateView(
          kind: DataStateKind.systemError,
          title: l10n.t('calendar.loadFailed'),
          onRetry: () => ref.invalidate(_calendarEventsProvider(_range)),
        ),
        data: (result) => switch (result) {
          AppFailure<List<CalendarEvent>>(error: final error) => DataStateView(
            kind: DataStateKind.systemError,
            title: error.message,
            onRetry: () => ref.invalidate(_calendarEventsProvider(_range)),
          ),
          AppSuccess<List<CalendarEvent>>(data: final events) =>
            _CalendarContent(
              tab: _tab,
              visibleMonth: _visibleMonth,
              selectedDate: _selectedDate,
              events: events,
              canManage: canManage,
              onTabChanged: (tab) => setState(() => _tab = tab),
              onPreviousMonth: _previousMonth,
              onNextMonth: _nextMonth,
              onSelectDate: (date) => setState(() {
                _selectedDate = date;
              }),
              onRefresh: () => ref.invalidate(_calendarEventsProvider(_range)),
              onAdd: canManage ? () => _openEventDialog() : null,
              onEdit: canManage
                  ? (event) => _openEventDialog(event: event)
                  : null,
              onDelete: canManage ? _deleteEvent : null,
              onStatusChange: canManage ? _updateEventStatus : null,
              onOpenDetail: _openEventDetail,
            ),
        },
      ),
    );
  }
}

class _CalendarContent extends StatelessWidget {
  const _CalendarContent({
    required this.tab,
    required this.visibleMonth,
    required this.selectedDate,
    required this.events,
    required this.canManage,
    required this.onTabChanged,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectDate,
    required this.onRefresh,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChange,
    required this.onOpenDetail,
  });

  final _CalendarTab tab;
  final DateTime visibleMonth;
  final DateTime selectedDate;
  final List<CalendarEvent> events;
  final bool canManage;
  final ValueChanged<_CalendarTab> onTabChanged;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDate;
  final VoidCallback onRefresh;
  final VoidCallback? onAdd;
  final ValueChanged<CalendarEvent>? onEdit;
  final ValueChanged<CalendarEvent>? onDelete;
  final void Function(CalendarEvent event, CalendarEventStatus status)?
  onStatusChange;
  final ValueChanged<CalendarEvent> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final monthEvents = _eventsInVisibleMonth(events, visibleMonth);
    final selectedDayEvents =
        monthEvents.where((event) => event.occursOn(selectedDate)).toList()
          ..sort((a, b) => a.localStart.compareTo(b.localStart));
    final visibleEvents = _visibleEventsForTab(monthEvents, selectedDate, tab);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final actions = Row(
                mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: compact
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                children: [
                  IconButton(
                    tooltip: l10n.t('calendar.refresh'),
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh),
                  ),
                  if (canManage) ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add),
                      label: Text(l10n.t('calendar.addNew')),
                    ),
                  ],
                ],
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: _CalendarTabs(
                        selected: tab,
                        onChanged: onTabChanged,
                      ),
                    ),
                    const SizedBox(height: 10),
                    actions,
                  ],
                );
              }
              return Row(
                children: [
                  _CalendarTabs(selected: tab, onChanged: onTabChanged),
                  const Spacer(),
                  actions,
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 920;
                  final calendar = _MonthCalendarPanel(
                    visibleMonth: visibleMonth,
                    selectedDate: selectedDate,
                    events: monthEvents,
                    onPreviousMonth: onPreviousMonth,
                    onNextMonth: onNextMonth,
                    onSelectDate: onSelectDate,
                  );
                  final list = _UpcomingEventsPanel(
                    title: _eventListTitle(tab, l10n),
                    selectedDate: selectedDate,
                    events: visibleEvents,
                    canManage: canManage,
                    onAdd: onAdd,
                    onEdit: onEdit,
                    onDelete: onDelete,
                  );
                  if (!wide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [calendar, const SizedBox(height: 18), list],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 9, child: calendar),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: SizedBox(
                          height: 430,
                          child: VerticalDivider(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      Expanded(flex: 10, child: list),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (selectedDayEvents.isNotEmpty) ...[
            _DailyActivitiesPanel(
              selectedDate: selectedDate,
              events: selectedDayEvents,
              canManage: canManage,
              onEdit: onEdit,
              onStatusChange: onStatusChange,
            ),
            const SizedBox(height: 18),
          ],
          _CalendarGanttPanel(
            visibleMonth: visibleMonth,
            selectedDate: selectedDate,
            events: monthEvents,
            onEventTap: onOpenDetail,
          ),
          const SizedBox(height: 18),
          _CalendarSummary(events: monthEvents),
        ],
      ),
    );
  }
}

class _CalendarTabs extends StatelessWidget {
  const _CalendarTabs({required this.selected, required this.onChanged});

  final _CalendarTab selected;
  final ValueChanged<_CalendarTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TabPill(
              label: l10n.t('calendar.tabOverview'),
              selected: selected == _CalendarTab.overview,
              onTap: () => onChanged(_CalendarTab.overview),
            ),
            _TabPill(
              label: l10n.t('calendar.tabCalendar'),
              selected: selected == _CalendarTab.calendar,
              onTap: () => onChanged(_CalendarTab.calendar),
            ),
            _TabPill(
              label: l10n.t('calendar.tabActivities'),
              selected: selected == _CalendarTab.activities,
              onTap: () => onChanged(_CalendarTab.activities),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? theme.colorScheme.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              color: selected
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthCalendarPanel extends StatelessWidget {
  const _MonthCalendarPanel({
    required this.visibleMonth,
    required this.selectedDate,
    required this.events,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectDate,
  });

  final DateTime visibleMonth;
  final DateTime selectedDate;
  final List<CalendarEvent> events;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final days = _monthGridDays(visibleMonth);
    final weekDays = [
      l10n.t('calendar.weekSun'),
      l10n.t('calendar.weekMon'),
      l10n.t('calendar.weekTue'),
      l10n.t('calendar.weekWed'),
      l10n.t('calendar.weekThu'),
      l10n.t('calendar.weekFri'),
      l10n.t('calendar.weekSat'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_monthName(visibleMonth.month, l10n)} ${visibleMonth.year}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton(
              tooltip: l10n.t('calendar.previousMonth'),
              onPressed: onPreviousMonth,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: l10n.t('calendar.nextMonth'),
              onPressed: onNextMonth,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 7,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.3,
          ),
          itemBuilder: (context, index) => Center(
            child: Text(
              weekDays[index],
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: days.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.05,
          ),
          itemBuilder: (context, index) {
            final date = days[index];
            final dayEvents = events
                .where((event) => event.occursOn(date))
                .toList();
            return _DayCell(
              date: date,
              visibleMonth: visibleMonth,
              selected: _sameDay(date, selectedDate),
              today: _sameDay(date, DateTime.now()),
              events: dayEvents,
              onTap: () => onSelectDate(date),
            );
          },
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.visibleMonth,
    required this.selected,
    required this.today,
    required this.events,
    required this.onTap,
  });

  final DateTime date;
  final DateTime visibleMonth;
  final bool selected;
  final bool today;
  final List<CalendarEvent> events;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final inMonth = date.month == visibleMonth.month;
    final background = selected
        ? scheme.inverseSurface
        : scheme.surfaceContainerHighest.withValues(
            alpha: inMonth ? 0.42 : 0.2,
          );
    final foreground = selected
        ? scheme.onInverseSurface
        : (inMonth
              ? scheme.onSurface
              : scheme.onSurfaceVariant.withValues(alpha: 0.48));

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: today ? scheme.primary : Colors.transparent,
              width: today ? 1.4 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                date.day.toString(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final event in events.take(3))
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _eventTypeColor(event.eventType, scheme),
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox.square(dimension: 5),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingEventsPanel extends StatelessWidget {
  const _UpcomingEventsPanel({
    required this.title,
    required this.selectedDate,
    required this.events,
    required this.canManage,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final DateTime selectedDate;
  final List<CalendarEvent> events;
  final bool canManage;
  final VoidCallback? onAdd;
  final ValueChanged<CalendarEvent>? onEdit;
  final ValueChanged<CalendarEvent>? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 440;
            final titleText = Text(
              title,
              maxLines: compact ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            );
            final actions = Row(
              mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: compact
                  ? MainAxisAlignment.spaceBetween
                  : MainAxisAlignment.start,
              children: [
                _SmallFilterPill(label: l10n.t('calendar.filterAll')),
                if (canManage) ...[
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: onAdd,
                    child: Text(l10n.t('calendar.addNew')),
                  ),
                ],
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [titleText, const SizedBox(height: 10), actions],
              );
            }
            return Row(
              children: [
                Expanded(child: titleText),
                actions,
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        if (events.isEmpty)
          DataStateView(
            kind: DataStateKind.empty,
            title: l10n.t('calendar.empty'),
            message: l10n.t('calendar.emptyBody'),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: events.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final event = events[index];
              return _EventCard(
                event: event,
                onEdit: onEdit == null ? null : () => onEdit!(event),
                onDelete: onDelete == null ? null : () => onDelete!(event),
              );
            },
          ),
      ],
    );
  }
}

class _SmallFilterPill extends StatelessWidget {
  const _SmallFilterPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.keyboard_arrow_down, size: 16),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, this.onEdit, this.onDelete});

  final CalendarEvent event;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final statusColor = _eventStatusColor(event.status, scheme);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _EventDateBadge(event: event),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (onEdit != null || onDelete != null)
                        PopupMenuButton<String>(
                          tooltip: l10n.t('calendar.actions'),
                          icon: const Icon(Icons.more_horiz, size: 20),
                          onSelected: (value) {
                            if (value == 'edit') onEdit?.call();
                            if (value == 'delete') onDelete?.call();
                          },
                          itemBuilder: (context) => [
                            if (onEdit != null)
                              PopupMenuItem(
                                value: 'edit',
                                child: Text(l10n.t('calendar.editEvent')),
                              ),
                            if (onDelete != null)
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(l10n.t('calendar.delete')),
                              ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 7,
                    children: [
                      _EventChip(
                        label: _eventStatusLabel(event.status, l10n),
                        color: statusColor,
                      ),
                      _EventChip(
                        label: _eventTypeLabel(event.eventType, l10n),
                        color: _eventTypeColor(event.eventType, scheme),
                      ),
                      _IconText(
                        icon: Icons.schedule_outlined,
                        label: event.shortTime,
                      ),
                      if ((event.location ?? '').trim().isNotEmpty)
                        _IconText(
                          icon: Icons.place_outlined,
                          label: event.location!,
                        ),
                    ],
                  ),
                  if ((event.description ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      event.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventDateBadge extends StatelessWidget {
  const _EventDateBadge({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        width: 58,
        height: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              event.localStart.day.toString().padLeft(2, '0'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              _shortWeekDay(event.localStart, AppLocalizations.of(context)),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventChip extends StatelessWidget {
  const _EventChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _IconText extends StatelessWidget {
  const _IconText({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DailyActivitiesPanel extends StatelessWidget {
  const _DailyActivitiesPanel({
    required this.selectedDate,
    required this.events,
    required this.canManage,
    required this.onEdit,
    required this.onStatusChange,
  });

  final DateTime selectedDate;
  final List<CalendarEvent> events;
  final bool canManage;
  final ValueChanged<CalendarEvent>? onEdit;
  final void Function(CalendarEvent event, CalendarEventStatus status)?
  onStatusChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.today_outlined, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${l10n.t('calendar.todayActivities')} · ${_formatDateLabel(selectedDate, l10n)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            if (!canManage) ...[
              const SizedBox(height: 8),
              Text(
                l10n.t('calendar.readOnlyNotice'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final event in events)
                  _DailyActivityCard(
                    event: event,
                    canManage: canManage,
                    onEdit: onEdit == null ? null : () => onEdit!(event),
                    onStart:
                        onStatusChange == null ||
                            event.status != CalendarEventStatus.scheduled
                        ? null
                        : () => onStatusChange!(
                            event,
                            CalendarEventStatus.inProgress,
                          ),
                    onComplete:
                        onStatusChange == null ||
                            event.status == CalendarEventStatus.completed ||
                            event.status == CalendarEventStatus.cancelled
                        ? null
                        : () => onStatusChange!(
                            event,
                            CalendarEventStatus.completed,
                          ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyActivityCard extends StatelessWidget {
  const _DailyActivityCard({
    required this.event,
    required this.canManage,
    required this.onEdit,
    required this.onStart,
    required this.onComplete,
  });

  final CalendarEvent event;
  final bool canManage;
  final VoidCallback? onEdit;
  final VoidCallback? onStart;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final statusColor = _eventStatusColor(event.status, scheme);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 420),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _EventChip(
                    label: _eventStatusLabel(event.status, l10n),
                    color: statusColor,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _IconText(
                    icon: Icons.schedule_outlined,
                    label: event.shortTime,
                  ),
                  if ((event.location ?? '').trim().isNotEmpty)
                    _IconText(
                      icon: Icons.place_outlined,
                      label: event.location!,
                    ),
                ],
              ),
              if (canManage) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (onStart != null)
                      FilledButton.tonalIcon(
                        onPressed: onStart,
                        icon: const Icon(Icons.play_arrow_outlined, size: 18),
                        label: Text(l10n.t('calendar.startActivity')),
                      ),
                    OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                      label: Text(l10n.t('calendar.modifyDate')),
                    ),
                    if (onComplete != null)
                      FilledButton.icon(
                        onPressed: onComplete,
                        icon: const Icon(Icons.task_alt_outlined, size: 18),
                        label: Text(l10n.t('calendar.confirmCompleted')),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarGanttPanel extends StatelessWidget {
  const _CalendarGanttPanel({
    required this.visibleMonth,
    required this.selectedDate,
    required this.events,
    required this.onEventTap,
  });

  final DateTime visibleMonth;
  final DateTime selectedDate;
  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent> onEventTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final sorted = [...events]
      ..sort((a, b) => a.localStart.compareTo(b.localStart));
    final daysInMonth = _daysInMonth(visibleMonth);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.view_timeline_outlined, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.t('calendar.ganttTitle'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _EventChip(
                  label:
                      '${_monthName(visibleMonth.month, l10n)} ${visibleMonth.year}',
                  color: scheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (sorted.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    Icon(
                      Icons.timeline_outlined,
                      size: 34,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.t('calendar.emptyMonth'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 720;
                  final labelWidth = compact ? 138.0 : 220.0;
                  final dayWidth = compact ? 38.0 : 44.0;
                  final chartWidth = daysInMonth * dayWidth;
                  final contentWidth = math.max(
                    labelWidth + chartWidth,
                    constraints.maxWidth,
                  );
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: contentWidth,
                      child: Column(
                        children: [
                          _GanttAxisHeader(
                            visibleMonth: visibleMonth,
                            labelWidth: labelWidth,
                            dayWidth: dayWidth,
                            daysInMonth: daysInMonth,
                          ),
                          const SizedBox(height: 6),
                          for (final event in sorted)
                            _GanttRow(
                              event: event,
                              visibleMonth: visibleMonth,
                              selectedDate: selectedDate,
                              labelWidth: labelWidth,
                              dayWidth: dayWidth,
                              daysInMonth: daysInMonth,
                              onTap: () => onEventTap(event),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _GanttAxisHeader extends StatelessWidget {
  const _GanttAxisHeader({
    required this.visibleMonth,
    required this.labelWidth,
    required this.dayWidth,
    required this.daysInMonth,
  });

  final DateTime visibleMonth;
  final double labelWidth;
  final double dayWidth;
  final int daysInMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            l10n.t('calendar.duration'),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        for (var day = 1; day <= daysInMonth; day++)
          SizedBox(
            width: dayWidth,
            child: Center(
              child: Text(
                day.toString().padLeft(2, '0'),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GanttRow extends StatelessWidget {
  const _GanttRow({
    required this.event,
    required this.visibleMonth,
    required this.selectedDate,
    required this.labelWidth,
    required this.dayWidth,
    required this.daysInMonth,
    required this.onTap,
  });

  final CalendarEvent event;
  final DateTime visibleMonth;
  final DateTime selectedDate;
  final double labelWidth;
  final double dayWidth;
  final int daysInMonth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final startDay = _eventStartDayInMonth(event, visibleMonth);
    final endDay = _eventEndDayInMonth(event, visibleMonth);
    final left = (startDay - 1) * dayWidth + 4;
    final width = math.max(28.0, (endDay - startDay + 1) * dayWidth - 8);
    final today = DateTime.now();
    final selectedInMonth = _sameMonth(selectedDate, visibleMonth);
    final todayInMonth = _sameMonth(today, visibleMonth);
    final color = _eventTypeColor(event.eventType, scheme);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.shortTime,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: daysInMonth * dayWidth,
            height: 54,
            child: Stack(
              children: [
                for (var day = 1; day <= daysInMonth; day++)
                  Positioned(
                    left: (day - 1) * dayWidth,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: dayWidth,
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: scheme.outlineVariant.withValues(
                              alpha: 0.42,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (selectedInMonth)
                  Positioned(
                    left: (selectedDate.day - 1) * dayWidth,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: dayWidth,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                if (todayInMonth)
                  Positioned(
                    left: (today.day - 1) * dayWidth + (dayWidth / 2) - 1,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 2, color: scheme.primary),
                  ),
                Positioned(
                  left: left,
                  top: 8,
                  width: width,
                  height: 38,
                  child: Tooltip(
                    message:
                        '${event.title} · ${event.shortTime} · ${_eventStatusLabel(event.status, AppLocalizations.of(context))}',
                    child: Material(
                      color: color.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: onTap,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 8,
                                color: scheme.onPrimary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  event.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarEventDetailDialog extends StatelessWidget {
  const _CalendarEventDetailDialog({
    required this.event,
    required this.canManage,
  });

  final CalendarEvent event;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final canStart = canManage && event.status == CalendarEventStatus.scheduled;
    final canComplete =
        canManage &&
        event.status != CalendarEventStatus.completed &&
        event.status != CalendarEventStatus.cancelled;
    return AlertDialog(
      title: Text(event.title),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _EventChip(
                  label: _eventStatusLabel(event.status, l10n),
                  color: _eventStatusColor(event.status, scheme),
                ),
                _EventChip(
                  label: _eventTypeLabel(event.eventType, l10n),
                  color: _eventTypeColor(event.eventType, scheme),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _IconText(
              icon: Icons.calendar_today_outlined,
              label:
                  '${_formatDateLabel(event.localStart, l10n)} · ${event.shortTime}',
            ),
            if ((event.location ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              _IconText(icon: Icons.place_outlined, label: event.location!),
            ],
            if ((event.description ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                event.description!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.t('common.close')),
        ),
        if (canManage)
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.of(context).pop(_CalendarDetailAction.edit),
            icon: const Icon(Icons.edit_calendar_outlined, size: 18),
            label: Text(l10n.t('calendar.modifyDate')),
          ),
        if (canStart)
          FilledButton.tonalIcon(
            onPressed: () =>
                Navigator.of(context).pop(_CalendarDetailAction.start),
            icon: const Icon(Icons.play_arrow_outlined, size: 18),
            label: Text(l10n.t('calendar.startActivity')),
          ),
        if (canComplete)
          FilledButton.icon(
            onPressed: () =>
                Navigator.of(context).pop(_CalendarDetailAction.complete),
            icon: const Icon(Icons.task_alt_outlined, size: 18),
            label: Text(l10n.t('calendar.confirmCompleted')),
          ),
      ],
    );
  }
}

class _CalendarSummary extends StatelessWidget {
  const _CalendarSummary({required this.events});

  final List<CalendarEvent> events;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final upcoming = events
        .where(
          (event) => !event.localStart.isBefore(_startOfDay(DateTime.now())),
        )
        .length;
    final completed = events
        .where((event) => event.status == CalendarEventStatus.completed)
        .length;
    final cancelled = events
        .where((event) => event.status == CalendarEventStatus.cancelled)
        .length;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _SummaryPill(
          icon: Icons.event_available_outlined,
          label: l10n.t('calendar.summaryUpcoming'),
          value: upcoming.toString(),
        ),
        _SummaryPill(
          icon: Icons.task_alt_outlined,
          label: l10n.t('calendar.summaryCompleted'),
          value: completed.toString(),
        ),
        _SummaryPill(
          icon: Icons.cancel_outlined,
          label: l10n.t('calendar.summaryCancelled'),
          value: cancelled.toString(),
        ),
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              value,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Range {
  const _Range(this.from, this.to);

  final DateTime from;
  final DateTime to;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Range && from == other.from && to == other.to;

  @override
  int get hashCode => Object.hash(from, to);
}

List<CalendarEvent> _visibleEventsForTab(
  List<CalendarEvent> events,
  DateTime selectedDate,
  _CalendarTab tab,
) {
  final sorted = [...events]
    ..sort((a, b) => a.localStart.compareTo(b.localStart));
  return switch (tab) {
    _CalendarTab.calendar =>
      sorted.where((event) => event.occursOn(selectedDate)).take(12).toList(),
    _CalendarTab.activities => sorted,
    _CalendarTab.overview => sorted,
  };
}

String _eventListTitle(_CalendarTab tab, AppLocalizations l10n) {
  return switch (tab) {
    _CalendarTab.overview => l10n.t('calendar.monthActivities'),
    _CalendarTab.calendar => l10n.t('calendar.selectedDayEvents'),
    _CalendarTab.activities => l10n.t('calendar.allActivities'),
  };
}

List<CalendarEvent> _eventsInVisibleMonth(
  List<CalendarEvent> events,
  DateTime visibleMonth,
) {
  final start = DateTime(visibleMonth.year, visibleMonth.month);
  final end = _monthEnd(visibleMonth);
  return events
      .where(
        (event) =>
            !event.localEnd.isBefore(start) && !event.localStart.isAfter(end),
      )
      .toList()
    ..sort((a, b) => a.localStart.compareTo(b.localStart));
}

List<DateTime> _monthGridDays(DateTime visibleMonth) {
  final firstDay = DateTime(visibleMonth.year, visibleMonth.month);
  final start = firstDay.subtract(Duration(days: firstDay.weekday % 7));
  return [for (var i = 0; i < 42; i++) start.add(Duration(days: i))];
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime _startOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

DateTime _monthEnd(DateTime visibleMonth) =>
    DateTime(visibleMonth.year, visibleMonth.month + 1, 0, 23, 59, 59);

bool _sameMonth(DateTime date, DateTime month) =>
    date.year == month.year && date.month == month.month;

int _daysInMonth(DateTime visibleMonth) =>
    DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;

int _eventStartDayInMonth(CalendarEvent event, DateTime visibleMonth) {
  return _sameMonth(event.localStart, visibleMonth) ? event.localStart.day : 1;
}

int _eventEndDayInMonth(CalendarEvent event, DateTime visibleMonth) {
  return _sameMonth(event.localEnd, visibleMonth)
      ? event.localEnd.day
      : _daysInMonth(visibleMonth);
}

String _formatDateLabel(DateTime date, AppLocalizations l10n) {
  return '${_shortWeekDay(date, l10n)} ${date.day.toString().padLeft(2, '0')} ${_monthName(date.month, l10n)}';
}

String _monthName(int month, AppLocalizations l10n) {
  return switch (month) {
    1 => l10n.t('calendar.monthJan'),
    2 => l10n.t('calendar.monthFeb'),
    3 => l10n.t('calendar.monthMar'),
    4 => l10n.t('calendar.monthApr'),
    5 => l10n.t('calendar.monthMay'),
    6 => l10n.t('calendar.monthJun'),
    7 => l10n.t('calendar.monthJul'),
    8 => l10n.t('calendar.monthAug'),
    9 => l10n.t('calendar.monthSep'),
    10 => l10n.t('calendar.monthOct'),
    11 => l10n.t('calendar.monthNov'),
    _ => l10n.t('calendar.monthDec'),
  };
}

String _shortWeekDay(DateTime date, AppLocalizations l10n) {
  return switch (date.weekday % 7) {
    0 => l10n.t('calendar.weekSun'),
    1 => l10n.t('calendar.weekMon'),
    2 => l10n.t('calendar.weekTue'),
    3 => l10n.t('calendar.weekWed'),
    4 => l10n.t('calendar.weekThu'),
    5 => l10n.t('calendar.weekFri'),
    _ => l10n.t('calendar.weekSat'),
  };
}

String _eventTypeLabel(CalendarEventType type, AppLocalizations l10n) {
  return switch (type) {
    CalendarEventType.operations => l10n.t('calendar.typeOperations'),
    CalendarEventType.training => l10n.t('calendar.typeTraining'),
    CalendarEventType.maintenance => l10n.t('calendar.typeMaintenance'),
    CalendarEventType.briefing => l10n.t('calendar.typeBriefing'),
    CalendarEventType.administrative => l10n.t('calendar.typeAdministrative'),
    CalendarEventType.other => l10n.t('calendar.typeOther'),
  };
}

String _eventStatusLabel(CalendarEventStatus status, AppLocalizations l10n) {
  return switch (status) {
    CalendarEventStatus.scheduled => l10n.t('calendar.statusScheduled'),
    CalendarEventStatus.inProgress => l10n.t('calendar.statusInProgress'),
    CalendarEventStatus.completed => l10n.t('calendar.statusCompleted'),
    CalendarEventStatus.cancelled => l10n.t('calendar.statusCancelled'),
  };
}

Color _eventStatusColor(CalendarEventStatus status, ColorScheme scheme) {
  return switch (status) {
    CalendarEventStatus.scheduled => scheme.primary,
    CalendarEventStatus.inProgress => const Color(0xFFE0A100),
    CalendarEventStatus.completed => const Color(0xFF2E9D57),
    CalendarEventStatus.cancelled => scheme.error,
  };
}

Color _eventTypeColor(CalendarEventType type, ColorScheme scheme) {
  return switch (type) {
    CalendarEventType.operations => scheme.primary,
    CalendarEventType.training => const Color(0xFF7C5CFF),
    CalendarEventType.maintenance => const Color(0xFFD68132),
    CalendarEventType.briefing => const Color(0xFF1D8A99),
    CalendarEventType.administrative => const Color(0xFF68717A),
    CalendarEventType.other => scheme.tertiary,
  };
}
