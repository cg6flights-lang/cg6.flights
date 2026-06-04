import 'package:cg6_flights/core/state/timezone_provider.dart';
import 'package:cg6_flights/features/dashboard/domain/dashboard_widget_config.dart';
import 'package:cg6_flights/features/dashboard/presentation/widgets/dashboard_widget_base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CalendarMiniWidget extends ConsumerWidget {
  const CalendarMiniWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tz = ref.watch(timezoneProvider);
    final now = toLocalTime(DateTime.now(), tz);
    final months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    final days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

    return DashboardWidgetWrapper(
      config: DashboardWidgetConfig.byId('calendar_mini')!,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        child: Column(children: [
          Text(
            '${days[now.weekday - 1]} ${now.day} · ${months[now.month - 1]} ${now.year}',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            for (final d in ['L', 'M', 'X', 'J', 'V', 'S', 'D'])
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: d == days[now.weekday - 1][0]
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                ),
                child: Center(
                  child: Text(d, style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: d == days[now.weekday - 1][0]
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                  )),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}
