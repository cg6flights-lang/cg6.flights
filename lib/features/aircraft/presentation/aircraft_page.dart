import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/errors/app_error.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/core/security/app_permission.dart';
import 'package:cg6_flights/features/aircraft/data/aircraft_repository.dart';
import 'package:cg6_flights/features/aircraft/domain/aircraft.dart';
import 'package:cg6_flights/features/auth/application/session_controller.dart';
import 'package:cg6_flights/features/crew/data/squadron_repository.dart';
import 'package:cg6_flights/features/crew/domain/squadron.dart';
import 'package:cg6_flights/features/units/data/units_repository.dart';
import 'package:cg6_flights/features/units/domain/unit_option.dart';
import 'package:cg6_flights/shared/widgets/data_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'aircraft_form_dialog.dart';
import 'aircraft_providers.dart';
import 'widgets/aircraft_widgets.dart';
import 'widgets/all_aircraft_overview_widget.dart';
import 'widgets/unit_aircraft_section_widget.dart';

class AircraftPage extends ConsumerWidget {
  const AircraftPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionControllerProvider);
    final aircraftAsync = ref.watch(aircraftListProvider);
    final unitsAsync = ref.watch(aircraftUnitsProvider);
    final canManage = session.can(AppPermission.aircraftManage);

    return aircraftAsync.when(
      loading: () =>
          const DataStateView(kind: DataStateKind.loading, title: ''),
      error: (_, _) => DataStateView(
        kind: DataStateKind.systemError,
        title: l10n.t('aircraft.loadFailed'),
        message: l10n.t('common.retry'),
        onRetry: () => ref.invalidate(aircraftListProvider),
      ),
      data: (result) {
        final aircraft = switch (result) {
          AppSuccess<List<Aircraft>>(data: final list) => list,
          AppFailure<List<Aircraft>>() => null,
        };

        if (aircraft == null) {
          final error = (result as AppFailure<List<Aircraft>>).error;
          return DataStateView(
            kind: _stateKindForError(error.category),
            title: l10n.t('aircraft.loadFailed'),
            message: error.message,
            onRetry: () => ref.invalidate(aircraftListProvider),
          );
        }

        if (aircraft.isEmpty) {
          return AircraftEmptyState(
            canManage: canManage,
            onAdd: () => _openForm(context, ref, session.user?.unitId),
          );
        }

        final units = unitsAsync.value ?? [];
        final selectedUnitId = ref.watch(selectedAircraftUnitProvider);
        final selectedSquadronId = ref.watch(selectedAircraftSquadronProvider);

        final baseUnitAircraft = <String, List<Aircraft>>{};
        for (final a in aircraft) {
          baseUnitAircraft.putIfAbsent(a.unitId, () => []).add(a);
        }
        final allUnits = units
            .where((u) => baseUnitAircraft.containsKey(u.id))
            .toList();
        final effectiveSelectedUnitId =
            selectedUnitId != null &&
                allUnits.any((u) => u.id == selectedUnitId)
            ? selectedUnitId
            : null;

        var filteredAircraft = aircraft;
        if (effectiveSelectedUnitId != null) {
          filteredAircraft = filteredAircraft
              .where((a) => a.unitId == effectiveSelectedUnitId)
              .toList();
        }
        if (effectiveSelectedUnitId == gru51Id && selectedSquadronId != null) {
          filteredAircraft = filteredAircraft
              .where(
                (a) =>
                    a.squadronIds.contains(selectedSquadronId) ||
                    a.squadronId == selectedSquadronId,
              )
              .toList();
        }

        final unitAircraft = <String, List<Aircraft>>{};
        for (final a in filteredAircraft) {
          unitAircraft.putIfAbsent(a.unitId, () => []).add(a);
        }
        final showUnits = effectiveSelectedUnitId != null
            ? allUnits.where((u) => u.id == effectiveSelectedUnitId).toList()
            : allUnits;
        final compact = MediaQuery.sizeOf(context).width < 620;
        final isGlobalUser = session.user?.role?.isGlobal == true;
        final isAllOverview =
            isGlobalUser &&
            effectiveSelectedUnitId == null &&
            allUnits.length > 1;

        final pagePadding = compact ? 12.0 : 24.0;

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                pagePadding,
                pagePadding,
                pagePadding,
                12,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.t('nav.aircraft'),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      if (canManage && !isAllOverview)
                        FilledButton.icon(
                          onPressed: () => _openForm(
                            context,
                            ref,
                            effectiveSelectedUnitId ?? session.user?.unitId,
                          ),
                          icon: const Icon(Icons.add, size: 20),
                          label: Text(l10n.t('aircraft.add')),
                        ),
                    ],
                  ),
                  if (isGlobalUser && allUnits.length > 1) ...[
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                l10n.t('aircraft.allUnits'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              selected: effectiveSelectedUnitId == null,
                              onSelected: (_) {
                                ref
                                    .read(selectedAircraftUnitProvider.notifier)
                                    .select(null);
                                ref
                                    .read(
                                      selectedAircraftSquadronProvider.notifier,
                                    )
                                    .select(null);
                              },
                            ),
                          ),
                          for (final u in allUnits)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(
                                  u.code,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                selected: effectiveSelectedUnitId == u.id,
                                onSelected: (_) {
                                  final nextUnitId =
                                      effectiveSelectedUnitId == u.id
                                      ? null
                                      : u.id;
                                  ref
                                      .read(
                                        selectedAircraftUnitProvider.notifier,
                                      )
                                      .select(u.id);
                                  if (nextUnitId != gru51Id) {
                                    ref
                                        .read(
                                          selectedAircraftSquadronProvider
                                              .notifier,
                                        )
                                        .select(null);
                                  }
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (effectiveSelectedUnitId == gru51Id) ...[
                      const SizedBox(height: 8),
                      Consumer(
                        builder: (context, ref, _) {
                          final squadrons =
                              ref.watch(aircraftSquadronsProvider).value ?? [];
                          final selSquadron = ref.watch(
                            selectedAircraftSquadronProvider,
                          );
                          if (squadrons.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.outline
                                        .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ...squadrons.map(
                                  (s) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: FilterChip(
                                      label: Text(
                                        s.name,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      selected: selSquadron == s.id,
                                      selectedColor: Theme.of(context)
                                          .colorScheme
                                          .tertiary
                                          .withValues(alpha: 0.18),
                                      checkmarkColor: Theme.of(
                                        context,
                                      ).colorScheme.tertiary,
                                      side: BorderSide.none,
                                      onSelected: (_) => ref
                                          .read(
                                            selectedAircraftSquadronProvider
                                                .notifier,
                                          )
                                          .select(s.id),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  pagePadding,
                  12,
                  pagePadding,
                  pagePadding,
                ),
                children: [
                  if (isAllOverview)
                    AllAircraftOverview(
                      units: allUnits,
                      aircraftByUnit: baseUnitAircraft,
                    )
                  else
                    for (final unit in showUnits)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: UnitAircraftSection(
                          unit: unit,
                          aircraft: unitAircraft[unit.id] ?? const [],
                          canManage: canManage,
                          onAdd: () => _openForm(context, ref, unit.id),
                          onEdit: (a) =>
                              _openForm(context, ref, null, aircraft: a),
                          onDeactivate: (a) =>
                              _confirmDeactivate(context, ref, a),
                        ),
                      ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref,
    String? defaultUnitId, {
    Aircraft? aircraft,
  }) async {
    final l10n = AppLocalizations.of(context);
    final unitsResult = await ref.read(unitsRepositoryProvider).listUnits();
    final List<UnitOption> activeUnits;
    switch (unitsResult) {
      case AppSuccess<List<UnitOption>>(data: final list):
        activeUnits = list.where((u) => u.active).toList();
      case AppFailure<List<UnitOption>>(error: final error):
        if (context.mounted) _showError(context, error.message);
        return;
    }

    if (activeUnits.isEmpty) {
      if (context.mounted) {
        _showError(context, l10n.t('aircraft.noActiveUnits'));
      }
      return;
    }

    if (!context.mounted) return;

    // Load squadrons and metadata
    final sqResult = await ref.read(squadronRepositoryProvider).listSquadrons();
    final squadrons = switch (sqResult) {
      AppSuccess<List<FlightSquadron>>(data: final list) => list,
      _ => <FlightSquadron>[],
    };
    final metaResult = await ref
        .read(aircraftRepositoryProvider)
        .getDistinctMetadata();
    final meta = switch (metaResult) {
      AppSuccess<Map<String, List<String>>>(data: final m) => m,
      _ => <String, List<String>>{},
    };

    if (!context.mounted) return;

    final saved = await showDialog<AircraftFormResult>(
      context: context,
      builder: (_) => AircraftFormDialog(
        aircraft: aircraft,
        units: activeUnits,
        defaultUnitId: defaultUnitId,
        squadrons: squadrons,
        manufacturers: meta['manufacturers'] ?? [],
        models: meta['models'] ?? [],
      ),
    );

    if (saved != null && context.mounted) {
      final repo = ref.read(aircraftRepositoryProvider);
      final result = await repo.saveAircraft(
        aircraftId: aircraft?.id,
        unitId: saved.unitId,
        tailNumber: saved.tailNumber,
        model: saved.model,
        manufacturer: saved.manufacturer,
        serialNumber: saved.serialNumber,
        year: saved.year,
        status: saved.status,
        inoperativeReason: saved.inoperativeReason,
        obTailNumber: saved.obTailNumber,
        displayRegistration: saved.displayRegistration,
        squadronId: saved.squadronId,
        squadronIds: saved.squadronIds,
      );
      if (!context.mounted) return;

      switch (result) {
        case AppSuccess<void>():
          ref.invalidate(aircraftListProvider);
          ref.invalidate(aircraftOperationalCurveProvider);
        case AppFailure<void>(error: final error):
          _showError(context, error.message);
      }
    }
  }

  Future<void> _confirmDeactivate(
    BuildContext context,
    WidgetRef ref,
    Aircraft aircraft,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.t('aircraft.deactivate')),
        content: Text(
          '${l10n.t('aircraft.deactivateConfirm')} ${aircraft.displayTailNumber}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.t('aircraft.deactivate')),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final result = await ref
          .read(aircraftRepositoryProvider)
          .deactivateAircraft(aircraft.id);
      if (!context.mounted) return;

      switch (result) {
        case AppSuccess<void>():
          ref.invalidate(aircraftListProvider);
          ref.invalidate(aircraftOperationalCurveProvider);
        case AppFailure<void>(error: final error):
          _showError(context, error.message);
      }
    }
  }

  DataStateKind _stateKindForError(AppErrorCategory category) {
    return switch (category) {
      AppErrorCategory.auth ||
      AppErrorCategory.authorization => DataStateKind.permissionDenied,
      AppErrorCategory.validation => DataStateKind.validationError,
      AppErrorCategory.businessRule => DataStateKind.businessError,
      AppErrorCategory.network => DataStateKind.networkError,
      _ => DataStateKind.systemError,
    };
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
