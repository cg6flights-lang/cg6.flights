import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/core/security/app_permission.dart';
import 'package:cg6_flights/core/state/theme_mode_controller.dart';
import 'package:cg6_flights/core/state/timezone_provider.dart';
import 'package:cg6_flights/features/auth/application/session_controller.dart';
import 'package:cg6_flights/features/crew/data/squadron_repository.dart';
import 'package:cg6_flights/features/crew/domain/squadron.dart';
import 'package:cg6_flights/features/units/data/units_repository.dart';
import 'package:cg6_flights/features/units/domain/unit_option.dart';
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

          const SizedBox(height: 16),

          // ── Squadrons ───────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.military_tech, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Escuadrones', style: theme.textTheme.titleMedium)),
                    if (ref.watch(sessionControllerProvider).can(AppPermission.aircraftManage))
                      FilledButton.icon(
                        onPressed: () => _showAddSquadronDialog(context, ref),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Agregar'),
                        style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  const _SquadronList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddSquadronDialog(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final unitsResult = await ref.read(unitsRepositoryProvider).listUnits();
    final units = switch (unitsResult) {
      AppSuccess<List<UnitOption>>(data: final list) => list.where((u) => u.active).toList(),
      _ => <UnitOption>[],
    };

    if (!context.mounted) return;
    String selectedUnitId = units.isNotEmpty ? units.first.id : '';
    final nameCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Nuevo Escuadrón'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedUnitId,
                decoration: const InputDecoration(labelText: 'Unidad', border: OutlineInputBorder()),
                items: units.map((u) => DropdownMenuItem(value: u.id, child: Text('${u.code} — ${u.name}'))).toList(),
                onChanged: (v) => setDialogState(() => selectedUnitId = v ?? ''),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre del Escuadrón', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.t('common.cancel'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.t('common.save'))),
          ],
        ),
      ),
    );
    if (result == true && context.mounted && nameCtrl.text.trim().isNotEmpty) {
      await ref.read(squadronRepositoryProvider).createSquadron(unitId: selectedUnitId, name: nameCtrl.text.trim());
      ref.invalidate(_squadronListProvider);
    }
  }
}

final _squadronListProvider = FutureProvider<List<FlightSquadron>>((ref) async {
  final result = await ref.read(squadronRepositoryProvider).listAllSquadrons();
  return switch (result) {
    AppSuccess<List<FlightSquadron>>(data: final list) => list,
    _ => <FlightSquadron>[],
  };
});

class _SquadronList extends ConsumerWidget {
  const _SquadronList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final squadrons = ref.watch(_squadronListProvider).value ?? [];
    if (squadrons.isEmpty) return const Text('Sin escuadrones', style: TextStyle(fontSize: 13, color: Colors.grey));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in squadrons)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Icon(s.active ? Icons.check_circle : Icons.cancel, size: 14, color: s.active ? Colors.green : Colors.grey),
              const SizedBox(width: 8),
              Expanded(child: Text(s.name, style: const TextStyle(fontSize: 13))),
              TextButton.icon(
                onPressed: () async {
                  final ctrl = TextEditingController(text: s.name);
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Editar nombre'),
                      content: TextFormField(controller: ctrl, decoration: const InputDecoration(border: OutlineInputBorder())),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
                      ],
                    ),
                  );
                  if (ok == true && context.mounted && ctrl.text.trim().isNotEmpty) {
                    await ref.read(squadronRepositoryProvider).updateSquadronName(squadronId: s.id, name: ctrl.text.trim());
                    ref.invalidate(_squadronListProvider);
                  }
                },
                icon: const Icon(Icons.edit, size: 14),
                label: const Text('Editar', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: () async {
                  await ref.read(squadronRepositoryProvider).toggleSquadron(s.id);
                  ref.invalidate(_squadronListProvider);
                },
                child: Text(s.active ? 'Desactivar' : 'Activar', style: const TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ]),
          ),
      ],
    );
  }
}
