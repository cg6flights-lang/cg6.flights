import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/core/security/app_permission.dart';
import 'package:cg6_flights/core/state/locale_controller.dart';
import 'package:cg6_flights/core/state/theme_mode_controller.dart';
import 'package:cg6_flights/features/notifications/application/notification_providers.dart';
import 'package:cg6_flights/features/notifications/data/notification_repository.dart';
import 'package:cg6_flights/features/notifications/domain/notification.dart';
import 'package:cg6_flights/features/auth/application/session_controller.dart';
import 'package:cg6_flights/features/auth/domain/app_user.dart';
import 'package:cg6_flights/features/calendar/data/calendar_repository.dart';
import 'package:cg6_flights/features/calendar/domain/calendar_event.dart';
import 'package:cg6_flights/shared/widgets/app_badges.dart';
import 'package:cg6_flights/shared/widgets/profile_modal.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final _calendarPreviewProvider =
    FutureProvider.autoDispose<AppResult<List<CalendarEvent>>>((ref) {
      final today = DateTime.now();
      final from = DateTime(today.year, today.month, today.day);
      final to = from.add(
        const Duration(days: 14, hours: 23, minutes: 59, seconds: 59),
      );
      return ref
          .read(calendarRepositoryProvider)
          .listEvents(from: from, to: to);
    });

class NavigationItem {
  const NavigationItem({
    required this.path,
    required this.labelKey,
    required this.icon,
    this.permission,
  });

  final String path;
  final String labelKey;
  final IconData icon;
  final String? permission;
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child, required this.items});

  final Widget child;
  final List<NavigationItem> items;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _overlayVisible = false;
  double _overlayOpacity = 1.0;

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.child != oldWidget.child) {
      _startNavigationTransition();
    }
  }

  void _startNavigationTransition() {
    if (_overlayVisible) return;
    setState(() {
      _overlayVisible = true;
      _overlayOpacity = 1.0;
    });
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _overlayOpacity = 0.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final user = session.user;
    final langCode = ref.watch(localeControllerProvider).languageCode;
    final themeMode = ref.watch(themeModeProvider);
    final localeNotifier = ref.read(localeControllerProvider.notifier);
    final location = GoRouterState.of(context).uri.path;
    final visibleItems = widget.items
        .where(
          (item) => item.permission == null || session.can(item.permission!),
        )
        .toList();
    final selectedIndex = visibleItems.indexWhere(
      (item) => location == item.path || location.startsWith('${item.path}/'),
    );
    final safeIndex = selectedIndex < 0 ? 0 : selectedIndex;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 860;
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 12,
            title: _HeaderBrand(compact: compact),
            actions: [
              _CalendarIcon(),
              const SizedBox(width: 4),
              _NotificationBell(),
              Tooltip(
                message: themeMode == ThemeMode.dark
                    ? 'Modo claro'
                    : 'Modo oscuro',
                child: IconButton(
                  onPressed: () =>
                      ref.read(themeModeProvider.notifier).toggle(),
                  icon: Icon(
                    themeMode == ThemeMode.dark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                  ),
                ),
              ),
              _LanguageToggle(
                langCode: langCode,
                onPressed: () => localeNotifier.toggle(),
              ),
              if (user != null) _UserAvatarMenu(user: user),
              const SizedBox(width: 8),
            ],
          ),
          drawer: compact
              ? _ShellDrawer(
                  items: visibleItems,
                  selectedIndex: safeIndex,
                  onSelected: (path) {
                    Navigator.of(context).pop();
                    context.go(path);
                  },
                )
              : null,
          body: Row(
            children: [
              if (!compact)
                SizedBox(
                  width: 104,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        for (var i = 0; i < visibleItems.length; i++)
                          Tooltip(
                            message: AppLocalizations.of(
                              context,
                            ).t(visibleItems[i].labelKey),
                            child: _NavRailTile(
                              icon: visibleItems[i].icon,
                              selected: i == safeIndex,
                              onTap: () => context.go(visibleItems[i].path),
                            ),
                          ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: Stack(
                  children: [
                    // Page always mounted — loads data in background
                    widget.child,
                    // Dots overlay — covers page during 3s then fades out
                    if (_overlayVisible)
                      Positioned.fill(
                        child: AnimatedOpacity(
                          opacity: _overlayOpacity,
                          duration: const Duration(milliseconds: 350),
                          onEnd: () {
                            if (_overlayOpacity == 0.0 && mounted) {
                              setState(() => _overlayVisible = false);
                            }
                          },
                          child: const _AppLoadingOverlay(),
                        ),
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
}

// ── Loading overlay for section navigation ──────────────────────────

class _AppLoadingOverlay extends StatefulWidget {
  const _AppLoadingOverlay();

  @override
  State<_AppLoadingOverlay> createState() => _AppLoadingOverlayState();
}

class _AppLoadingOverlayState extends State<_AppLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dotsController;

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < 3; i++)
                  _OverlayDot(controller: _dotsController, index: i),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayDot extends StatelessWidget {
  const _OverlayDot({required this.controller, required this.index});
  final AnimationController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    const size = 10.0;
    final delay = index * 0.25;
    final alpha = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(delay, delay + 0.4, curve: Curves.easeInOut),
      ),
    );
    final scale = Tween<double>(begin: 0.7, end: 1.1).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(delay, delay + 0.4, curve: Curves.easeInOut),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) => Transform.scale(
          scale: scale.value,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: alpha.value),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarIcon extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final canRead = ref
        .watch(sessionControllerProvider)
        .can(AppPermission.calendarRead);
    final now = DateTime.now();
    final day = now.day.toString();
    final icon = Badge(
      smallSize: 14,
      largeSize: 18,
      padding: const EdgeInsets.all(1),
      label: Text(
        day,
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
      ),
      child: const Icon(Icons.calendar_month_outlined),
    );
    if (!canRead) {
      return Tooltip(
        message: l10n.t('calendar.loadFailed'),
        child: IconButton(onPressed: null, icon: icon),
      );
    }

    return Tooltip(
      message: l10n.t('nav.calendar'),
      child: PopupMenuButton<String>(
        offset: const Offset(0, 48),
        tooltip: l10n.t('nav.calendar'),
        onSelected: (value) {
          if (value == 'expand') context.go('/calendar');
        },
        itemBuilder: (context) => [
          const PopupMenuItem<String>(
            enabled: false,
            child: _CalendarPreviewBody(),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'expand',
            child: Row(
              children: [
                const Icon(Icons.open_in_full_outlined, size: 18),
                const SizedBox(width: 8),
                Text(l10n.t('calendar.expand')),
              ],
            ),
          ),
        ],
        child: Padding(padding: const EdgeInsets.all(8), child: icon),
      ),
    );
  }
}

class _CalendarPreviewBody extends ConsumerWidget {
  const _CalendarPreviewBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final preview = ref.watch(_calendarPreviewProvider);
    return SizedBox(
      width: 340,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_month_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.t('calendar.upcomingAlerts'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          preview.when(
            loading: () => const _HeaderPreviewLoading(),
            error: (_, _) => _HeaderPreviewEmpty(
              icon: Icons.error_outline,
              title: l10n.t('calendar.loadFailed'),
            ),
            data: (result) => switch (result) {
              AppFailure<List<CalendarEvent>>() => _HeaderPreviewEmpty(
                icon: Icons.error_outline,
                title: l10n.t('calendar.loadFailed'),
              ),
              AppSuccess<List<CalendarEvent>>(data: final events) =>
                _CalendarPreviewContent(events: events),
            },
          ),
        ],
      ),
    );
  }
}

class _CalendarPreviewContent extends StatelessWidget {
  const _CalendarPreviewContent({required this.events});

  final List<CalendarEvent> events;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sorted = [...events]
      ..sort((a, b) => a.localStart.compareTo(b.localStart));
    final activeEvents = sorted
        .where((event) => event.status != CalendarEventStatus.cancelled)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _PreviewMiniCalendar(events: activeEvents),
        const SizedBox(height: 12),
        if (activeEvents.isEmpty)
          _HeaderPreviewEmpty(
            icon: Icons.event_available_outlined,
            title: l10n.t('calendar.noAlerts'),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final event in activeEvents.take(4))
                    _PreviewEventTile(event: event),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PreviewMiniCalendar extends StatelessWidget {
  const _PreviewMiniCalendar({required this.events});

  final List<CalendarEvent> events;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    final days = _previewMonthGridDays(month);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final weekDays = [
      l10n.t('calendar.weekSun'),
      l10n.t('calendar.weekMon'),
      l10n.t('calendar.weekTue'),
      l10n.t('calendar.weekWed'),
      l10n.t('calendar.weekThu'),
      l10n.t('calendar.weekFri'),
      l10n.t('calendar.weekSat'),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_previewMonthName(month.month, l10n)} ${month.year}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _TodayPill(),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final label in weekDays)
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: days.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemBuilder: (context, index) {
                final date = days[index];
                final inMonth = date.month == month.month;
                final today = _previewSameDay(date, now);
                final hasEvent = events.any((event) => event.occursOn(date));
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: today ? scheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        date.day.toString(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: today
                              ? scheme.onPrimary
                              : inMonth
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant.withValues(alpha: 0.42),
                          fontWeight: today ? FontWeight.w900 : FontWeight.w700,
                        ),
                      ),
                      if (hasEvent)
                        Positioned(
                          bottom: 3,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: today ? scheme.onPrimary : scheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const SizedBox.square(dimension: 4),
                          ),
                        ),
                    ],
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

class _TodayPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          l10n.t('calendar.today'),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _PreviewEventTile extends StatelessWidget {
  const _PreviewEventTile({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: _previewStatusColor(
                    event.status,
                    scheme,
                  ).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SizedBox(
                  width: 42,
                  height: 48,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        event.localStart.day.toString().padLeft(2, '0'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        _previewShortWeekDay(
                          event.localStart,
                          AppLocalizations.of(context),
                        ),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
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
                    const SizedBox(height: 3),
                    Text(
                      event.shortTime,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderPreviewLoading extends StatelessWidget {
  const _HeaderPreviewLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _HeaderPreviewEmpty extends StatelessWidget {
  const _HeaderPreviewEmpty({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Icon(icon, size: 30, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

List<DateTime> _previewMonthGridDays(DateTime visibleMonth) {
  final firstDay = DateTime(visibleMonth.year, visibleMonth.month);
  final start = firstDay.subtract(Duration(days: firstDay.weekday % 7));
  return [for (var i = 0; i < 42; i++) start.add(Duration(days: i))];
}

bool _previewSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _previewMonthName(int month, AppLocalizations l10n) {
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

String _previewShortWeekDay(DateTime date, AppLocalizations l10n) {
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

Color _previewStatusColor(CalendarEventStatus status, ColorScheme scheme) {
  return switch (status) {
    CalendarEventStatus.scheduled => scheme.primary,
    CalendarEventStatus.inProgress => const Color(0xFFE0A100),
    CalendarEventStatus.completed => const Color(0xFF2E9D57),
    CalendarEventStatus.cancelled => scheme.error,
  };
}

class _NotificationBell extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifAsync = ref.watch(notificationsProvider);
    final theme = Theme.of(context);

    final notifications = notifAsync.asData?.value is AppSuccess
        ? (notifAsync.asData!.value as AppSuccess<List<AppNotification>>).data
        : <AppNotification>[];
    final unread = notifications.where((n) => !n.isRead).length;
    final latest = notifications.where((n) => !n.isRead).take(5).toList();

    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      tooltip: 'Notificaciones',
      icon: unread > 0
          ? Badge(
              label: Text(
                '${unread > 99 ? '99+' : unread}',
                style: const TextStyle(fontSize: 10),
              ),
              child: const Icon(Icons.notifications_outlined),
            )
          : const Icon(Icons.notifications_outlined),
      onSelected: (value) {
        if (value == 'all') {
          context.go('/notifications');
        } else {
          ref.read(notificationRepositoryProvider).markAsRead(value);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Row(
            children: [
              Text(
                'Notificaciones',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              if (unread > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$unread',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const PopupMenuDivider(),
        if (latest.isEmpty)
          const PopupMenuItem<String>(
            enabled: false,
            child: SizedBox(
              width: 300,
              child: Column(
                children: [
                  Icon(Icons.notifications_off_outlined, size: 36),
                  SizedBox(height: 8),
                  Text('Sin notificaciones nuevas'),
                ],
              ),
            ),
          )
        else ...[
          for (final n in latest)
            PopupMenuItem<String>(
              value: n.id,
              onTap: () =>
                  ref.read(notificationRepositoryProvider).markAsRead(n.id),
              child: SizedBox(
                width: 300,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (!n.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        if (!n.isRead) const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            n.title,
                            style: TextStyle(
                              fontWeight: n.isRead
                                  ? FontWeight.normal
                                  : FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Padding(
                      padding: EdgeInsets.only(left: n.isRead ? 0 : 16),
                      child: Text(
                        n.body,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Padding(
                      padding: EdgeInsets.only(left: n.isRead ? 0 : 16),
                      child: Text(
                        _timeAgo(n.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        if (latest.isNotEmpty) ...[
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'all',
            child: Row(
              children: [
                Icon(Icons.history, size: 18),
                SizedBox(width: 8),
                Text('Ver todas'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

class _UserAvatarMenu extends ConsumerWidget {
  const _UserAvatarMenu({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = user.displayName.isNotEmpty
        ? user.displayName[0].toUpperCase()
        : '?';

    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      tooltip: user.displayName,
      onSelected: (value) {
        switch (value) {
          case 'profile':
            showProfileModal(context, user);
          case 'audit':
            context.go('/audit');
          case 'settings':
            context.go('/settings');
          case 'logout':
            ref.read(sessionControllerProvider.notifier).signOut();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: _UserInfoHeader(user: user),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 20),
              SizedBox(width: 8),
              Text('Editar perfil'),
            ],
          ),
        ),
        if (user.can(AppPermission.auditRead))
          PopupMenuItem<String>(
            value: 'audit',
            child: Row(
              children: [
                Icon(Icons.fact_check_outlined, size: 20),
                const SizedBox(width: 8),
                const Text('Auditoría'),
              ],
            ),
          ),
        const PopupMenuItem<String>(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.tune, size: 20),
              SizedBox(width: 8),
              Text('Configuración'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(
                Icons.logout,
                size: 20,
                color: Theme.of(context).colorScheme.error,
              ),
              SizedBox(width: 8),
              Text(
                'Cerrar sesion',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
      ],
      child: CircleAvatar(
        radius: 16,
        child: Text(initial, style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({required this.langCode, required this.onPressed});

  final String langCode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nextLabel = langCode == 'es' ? 'EN' : 'ES';
    final tooltip = langCode == 'es'
        ? 'Switch to English'
        : 'Cambiar a Espanol';
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 36,
              constraints: const BoxConstraints(minWidth: 58),
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.language,
                    size: 17,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    nextLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserInfoHeader extends StatelessWidget {
  const _UserInfoHeader({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                child: Text(
                  user.displayName.isNotEmpty
                      ? user.displayName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  user.displayName,
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            user.email,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              RoleBadge(role: user.role),
              if (user.unitName != null) UnitBadge(unitName: user.unitName),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavRailTile extends StatefulWidget {
  const _NavRailTile({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavRailTile> createState() => _NavRailTileState();
}

class _NavRailTileState extends State<_NavRailTile> {
  bool _hovered = false;
  int _exitToken = 0;

  void _handleEnter(PointerEnterEvent event) {
    _exitToken++;
    if (!_hovered) setState(() => _hovered = true);
  }

  void _handleExit(PointerExitEvent event) {
    final token = ++_exitToken;
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!mounted || token != _exitToken) return;
      if (_hovered) setState(() => _hovered = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MouseRegion(
        onEnter: _handleEnter,
        onExit: _handleExit,
        child: AnimatedScale(
          scale: _hovered ? 1.35 : 1,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: GestureDetector(
            onTap: widget.onTap,
            child: SizedBox(
              width: 72,
              height: 52,
              child: Icon(widget.icon, color: color, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellDrawer extends StatelessWidget {
  const _ShellDrawer({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<NavigationItem> items;
  final int selectedIndex;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationDrawer(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) => onSelected(items[index].path),
      children: [
        const SizedBox(height: 16),
        for (final item in items)
          NavigationDrawerDestination(
            icon: Icon(item.icon),
            label: Text(AppLocalizations.of(context).t(item.labelKey)),
          ),
      ],
    );
  }
}

class _HeaderBrand extends StatelessWidget {
  const _HeaderBrand({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'cg6_logo/favicon_cg6.png',
          height: compact ? 28 : 34,
          width: compact ? 48 : 58,
          fit: BoxFit.contain,
          semanticLabel: 'CG6 Flights',
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'CG6',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF005AD2),
                    shadows: [
                      Shadow(
                        color: Color(0x660846B4),
                        offset: Offset(1.2, 1.2),
                        blurRadius: 0.8,
                      ),
                      Shadow(
                        color: Color(0x380846B4),
                        offset: Offset(0.5, 0.5),
                        blurRadius: 2.0,
                      ),
                    ],
                  ),
                ),
                if (!compact)
                  const TextSpan(
                    text: ' Flights',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF596F97),
                    ),
                  ),
                const TextSpan(
                  text: ' v1.0',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF4E6082),
                  ),
                ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
