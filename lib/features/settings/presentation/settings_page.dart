import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/state/theme_mode_controller.dart';
import 'package:cg6_flights/core/state/timezone_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tzOffset = ref.watch(timezoneProvider);
    final themeMode = ref.watch(themeModeProvider);
    // Find current index for the saved offset (default to 0 = Lima)
    final tzIndex = availableTimezones.indexWhere((t) => t.$2 == tzOffset);
    final safeIndex = tzIndex >= 0 ? tzIndex : 0;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.t('nav.settings'), style: theme.textTheme.headlineSmall),
          const SizedBox(height: 24),

          // ── Timezone ──────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 20,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(l10n.t('settings.timezone'),
                          style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.t('settings.timezoneDesc'),
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: safeIndex,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: l10n.t('settings.timezone'),
                    ),
                    items: List.generate(availableTimezones.length, (i) {
                      return DropdownMenuItem<int>(
                        value: i,
                        child: Text(availableTimezones[i].$1,
                            style: const TextStyle(fontSize: 14)),
                      );
                    }),
                    onChanged: (v) {
                      if (v != null && v < availableTimezones.length) {
                        ref.read(timezoneProvider.notifier)
                            .setOffset(availableTimezones[v].$2);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Theme ─────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.brightness_6, size: 20,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(l10n.t('settings.theme'), style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.t('settings.themeDesc'),
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(
                          value: ThemeMode.light,
                          icon: const Icon(Icons.light_mode),
                          label: Text(l10n.t('settings.light'))),
                      ButtonSegment(
                          value: ThemeMode.dark,
                          icon: const Icon(Icons.dark_mode),
                          label: Text(l10n.t('settings.dark'))),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (v) {
                      ref.read(themeModeProvider.notifier).setMode(v.first);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
