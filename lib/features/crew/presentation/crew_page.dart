import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/errors/app_error.dart';
import 'package:cg6_flights/core/realtime/realtime_invalidator.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/core/security/app_permission.dart';
import 'package:cg6_flights/features/auth/application/session_controller.dart';
import 'package:cg6_flights/features/crew/data/cadet_course_repository.dart';
import 'package:cg6_flights/features/crew/data/crew_repository.dart';
import 'package:cg6_flights/features/crew/data/grades_repository.dart';
import 'package:cg6_flights/features/crew/data/squadron_repository.dart';
import 'package:cg6_flights/features/crew/domain/cadet_course.dart';
import 'package:cg6_flights/features/crew/domain/crew_member.dart';
import 'package:cg6_flights/features/crew/domain/grade_option.dart';
import 'package:cg6_flights/features/crew/domain/squadron.dart';
import 'package:cg6_flights/features/units/data/units_repository.dart';
import 'package:cg6_flights/features/units/domain/unit_option.dart';
import 'package:cg6_flights/shared/widgets/data_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cadet_detail_modal.dart';
import 'cadet_form_dialog.dart';
import 'crew_detail_modal.dart';
import 'crew_form_dialog.dart';

final _crewListProvider = FutureProvider<AppResult<List<CrewMember>>>((
  ref,
) async {
  final repo = ref.read(crewRepositoryProvider);
  return repo.listCrewMembers();
});

final _unitsProvider = FutureProvider<List<UnitOption>>((ref) async {
  final result = await ref.read(unitsRepositoryProvider).listUnits();
  return switch (result) {
    AppSuccess<List<UnitOption>>(data: final list) =>
      list.where((u) => u.active).toList(),
    _ => <UnitOption>[],
  };
});

final _gradesProvider = FutureProvider<List<GradeOption>>((ref) async {
  final result = await ref.read(gradesRepositoryProvider).listGrades();
  return switch (result) {
    AppSuccess<List<GradeOption>>(data: final list) => list,
    _ => <GradeOption>[],
  };
});

final _cadetCoursesProvider =
    FutureProvider.family<AppResult<List<CadetCourse>>, String>((
      ref,
      unitId,
    ) async {
      return ref
          .read(cadetCourseRepositoryProvider)
          .listCourses(unitId: unitId);
    });

final _cadetsByCourseProvider =
    FutureProvider.family<AppResult<List<CrewMember>>, String>((
      ref,
      courseId,
    ) async {
      return ref
          .read(crewRepositoryProvider)
          .listCrewMembers(cadetCourseId: courseId);
    });

class CrewPage extends ConsumerStatefulWidget {
  const CrewPage({super.key});

  @override
  ConsumerState<CrewPage> createState() => _CrewPageState();
}

class _CrewPageState extends ConsumerState<CrewPage> {
  static const _gru51Id = '4317c6f3-e530-4b9c-a898-1f765ceaafb2';
  static const _edaciId = 'c95a95da-81a9-420e-b574-db15f56c5d9f';

  String? _selectedUnitId;
  String? _selectedSquadronId;
  List<FlightSquadron> _squadrons = [];
  bool _defaultUnitSet = false;
  bool _showCadets = false;
  RealtimeInvalidator? _realtime;

  @override
  void initState() {
    super.initState();
    _realtime = RealtimeInvalidator(
      channelName: 'crew-page',
      tables: const ['crew_members'],
      onChange: () {
        if (!mounted) return;
        ref.invalidate(_crewListProvider);
        ref.invalidate(_cadetsByCourseProvider);
      },
    );
  }

  @override
  void dispose() {
    _realtime?.dispose();
    super.dispose();
  }

  bool get _isGru51 => _selectedUnitId == _gru51Id;
  bool get _isEdaci => _selectedUnitId == _edaciId;

  Future<void> _loadSquadrons() async {
    final result = await ref
        .read(squadronRepositoryProvider)
        .listSquadrons(unitId: _selectedUnitId);
    if (!mounted) return;
    setState(() {
      _squadrons = switch (result) {
        AppSuccess<List<FlightSquadron>>(data: final list) => list,
        _ => <FlightSquadron>[],
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionControllerProvider);
    final crewAsync = ref.watch(_crewListProvider);
    final unitsAsync = ref.watch(_unitsProvider);
    final gradesAsync = ref.watch(_gradesProvider);
    final canManage = session.can(AppPermission.crewManage);
    final isGlobal = session.user?.role?.isGlobal ?? false;

    return crewAsync.when(
      loading: () =>
          const DataStateView(kind: DataStateKind.loading, title: ''),
      error: (_, _) => DataStateView(
        kind: DataStateKind.systemError,
        title: l10n.t('crew.loadFailed'),
        message: l10n.t('common.retry'),
        onRetry: () => ref.invalidate(_crewListProvider),
      ),
      data: (result) {
        final members = switch (result) {
          AppSuccess<List<CrewMember>>(data: final list) => list,
          AppFailure<List<CrewMember>>() => null,
        };

        if (members == null) {
          final error = (result as AppFailure<List<CrewMember>>).error;
          return DataStateView(
            kind: _stateKindForError(error.category),
            title: l10n.t('crew.loadFailed'),
            message: error.message,
            onRetry: () => ref.invalidate(_crewListProvider),
          );
        }

        final units = unitsAsync.value ?? <UnitOption>[];
        final grades = gradesAsync.value ?? <GradeOption>[];

        if (!_defaultUnitSet && units.isNotEmpty && _selectedUnitId == null) {
          _defaultUnitSet = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final defaultUnitId = units
                .firstWhere((u) => u.active, orElse: () => units.first)
                .id;
            setState(() => _selectedUnitId = defaultUnitId);
            if (defaultUnitId == _gru51Id) _loadSquadrons();
          });
        }

        var filtered = members;
        if (_selectedUnitId != null) {
          filtered = filtered
              .where((m) => m.unitId == _selectedUnitId)
              .toList();
        }
        if (_selectedSquadronId != null) {
          filtered = filtered
              .where((m) => m.squadronId == _selectedSquadronId)
              .toList();
        }

        final rosterMembers = filtered.where((m) => !m.isCadet).toList();
        final pilots = rosterMembers
            .where((m) => m.crewCategory == 'pilot')
            .toList();
        final mechanics = rosterMembers
            .where((m) => m.crewCategory == 'mechanic')
            .toList();
        final pagePadding = MediaQuery.sizeOf(context).width < 620
            ? 12.0
            : 24.0;
        final showCadets = _isEdaci && _showCadets;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            pagePadding,
            pagePadding,
            pagePadding,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CrewFixedHeader(
                units: units,
                squadrons: _squadrons,
                selectedUnitId: _selectedUnitId,
                selectedSquadronId: _selectedSquadronId,
                isGru51: _isGru51,
                isEdaci: _isEdaci,
                showCadets: showCadets,
                canManage: canManage,
                onAdd: () => _openForm(context, ref, session.user?.unitId),
                onSelectUnit: _selectUnit,
                onSelectSquadron: _selectSquadron,
                onShowRoster: () => setState(() => _showCadets = false),
                onShowCadets: () => setState(() => _showCadets = true),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: showCadets
                    ? _CadetsWorkspace(
                        unitId: _edaciId,
                        grades: grades,
                        canManage: canManage,
                        onBack: () => setState(() => _showCadets = false),
                      )
                    : members.isEmpty
                    ? _CrewEmptyState(
                        canManage: canManage,
                        onAdd: () =>
                            _openForm(context, ref, session.user?.unitId),
                      )
                    : _RosterContent(
                        pilots: pilots,
                        mechanics: mechanics,
                        grades: grades,
                        units: units,
                        canManage: canManage,
                        isGlobal: isGlobal,
                        onSelect: _openCrewDetail,
                        onEdit: (m) => _openForm(context, ref, null, member: m),
                        onDeactivate: (m) =>
                            _confirmDeactivate(context, ref, m),
                        onRefresh: () => ref.invalidate(_crewListProvider),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _selectUnit(String unitId) {
    setState(() {
      _selectedUnitId = _selectedUnitId == unitId ? null : unitId;
      _selectedSquadronId = null;
      _squadrons = [];
      _showCadets = false;
    });
    if (unitId == _gru51Id && _selectedUnitId == unitId) {
      _loadSquadrons();
    }
  }

  void _selectSquadron(String squadronId) {
    setState(() {
      _selectedSquadronId = _selectedSquadronId == squadronId
          ? null
          : squadronId;
    });
  }

  Future<void> _openCrewDetail(CrewMember member) async {
    final changed = await showCrewDetailModal(context, member, ref);
    if (changed == true && mounted) {
      ref.invalidate(_crewListProvider);
    }
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref,
    String? defaultUnitId, {
    CrewMember? member,
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
        _showError(context, l10n.t('crew.noActiveUnits'));
      }
      return;
    }

    final gradesResult = await ref.read(gradesRepositoryProvider).listGrades();
    final List<GradeOption> grades;
    switch (gradesResult) {
      case AppSuccess<List<GradeOption>>(data: final list):
        grades = list;
      case AppFailure<List<GradeOption>>(error: final error):
        if (context.mounted) _showError(context, error.message);
        return;
    }

    if (!context.mounted) return;

    final squadronsResult = await ref
        .read(squadronRepositoryProvider)
        .listSquadrons();
    final squadrons = switch (squadronsResult) {
      AppSuccess<List<FlightSquadron>>(data: final list) => list,
      _ => <FlightSquadron>[],
    };

    if (!context.mounted) return;

    final saved = await showDialog<CrewFormResult>(
      context: context,
      builder: (_) => CrewFormDialog(
        member: member,
        units: activeUnits,
        grades: grades,
        defaultUnitId: defaultUnitId,
        squadrons: squadrons,
        userRole: ref.read(sessionControllerProvider).user?.role?.key,
        userSquadronId: ref.read(sessionControllerProvider).user?.squadronId,
      ),
    );

    if (saved != null && context.mounted) {
      final repo = ref.read(crewRepositoryProvider);
      final result = await repo.saveCrewMember(
        crewMemberId: member?.id,
        unitId: saved.unitId,
        grade: saved.grade,
        firstName: saved.firstName,
        lastName: saved.lastName,
        nsa: saved.nsa,
        crewCategory: saved.crewCategory,
        appointmentDate: saved.appointmentDate,
        assignmentType: saved.assignmentType,
        qualifications: saved.qualifications,
        squadronId: saved.squadronId,
      );
      if (!context.mounted) return;

      switch (result) {
        case AppSuccess<void>():
          ref.invalidate(_crewListProvider);
        case AppFailure<void>(error: final error):
          _showError(context, error.message);
      }
    }
  }

  Future<void> _confirmDeactivate(
    BuildContext context,
    WidgetRef ref,
    CrewMember member,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('crew.deactivate')),
        content: Text(
          '${l10n.t('crew.deactivateConfirm')} ${member.fullName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.t('crew.deactivate')),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final result = await ref
          .read(crewRepositoryProvider)
          .deactivateCrewMember(member.id);
      if (!context.mounted) return;

      switch (result) {
        case AppSuccess<void>():
          ref.invalidate(_crewListProvider);
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

class _CrewFixedHeader extends StatelessWidget {
  const _CrewFixedHeader({
    required this.units,
    required this.squadrons,
    required this.selectedUnitId,
    required this.selectedSquadronId,
    required this.isGru51,
    required this.isEdaci,
    required this.showCadets,
    required this.canManage,
    required this.onAdd,
    required this.onSelectUnit,
    required this.onSelectSquadron,
    required this.onShowRoster,
    required this.onShowCadets,
  });

  final List<UnitOption> units;
  final List<FlightSquadron> squadrons;
  final String? selectedUnitId;
  final String? selectedSquadronId;
  final bool isGru51;
  final bool isEdaci;
  final bool showCadets;
  final bool canManage;
  final VoidCallback onAdd;
  final void Function(String unitId) onSelectUnit;
  final void Function(String squadronId) onSelectSquadron;
  final VoidCallback onShowRoster;
  final VoidCallback onShowCadets;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.t('nav.crew'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            if (canManage)
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 20),
                label: Text(l10n.t('crew.add')),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (units.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final unit in units.where((e) => e.active))
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        unit.code,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      selected: selectedUnitId == unit.id,
                      onSelected: (_) => onSelectUnit(unit.id),
                    ),
                  ),
                if (isGru51 && squadrons.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 3,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  for (final squadron in squadrons)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(
                          squadron.name,
                          style: const TextStyle(fontSize: 11),
                        ),
                        selected: selectedSquadronId == squadron.id,
                        selectedColor: Theme.of(
                          context,
                        ).colorScheme.tertiary.withValues(alpha: 0.18),
                        checkmarkColor: Theme.of(context).colorScheme.tertiary,
                        side: BorderSide.none,
                        onSelected: (_) => onSelectSquadron(squadron.id),
                      ),
                    ),
                ],
              ],
            ),
          ),
        if (isEdaci) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Tripulantes'),
                  selected: !showCadets,
                  avatar: const Icon(Icons.groups_2_outlined, size: 16),
                  onSelected: (_) => onShowRoster(),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Cadetes'),
                  selected: showCadets,
                  avatar: const Icon(Icons.school_outlined, size: 16),
                  onSelected: (_) => onShowCadets(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _RosterContent extends StatelessWidget {
  const _RosterContent({
    required this.pilots,
    required this.mechanics,
    required this.grades,
    required this.units,
    required this.canManage,
    required this.isGlobal,
    required this.onSelect,
    required this.onEdit,
    required this.onDeactivate,
    required this.onRefresh,
  });

  final List<CrewMember> pilots;
  final List<CrewMember> mechanics;
  final List<GradeOption> grades;
  final List<UnitOption> units;
  final bool canManage;
  final bool isGlobal;
  final void Function(CrewMember member) onSelect;
  final void Function(CrewMember member) onEdit;
  final void Function(CrewMember member) onDeactivate;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final pilotSection = _CrewSection(
          category: 'pilot',
          title: l10n.t('crew.pilot'),
          members: pilots,
          grades: grades,
          units: units,
          canManage: canManage,
          isGlobal: isGlobal,
          onSelect: onSelect,
          onEdit: onEdit,
          onDeactivate: onDeactivate,
          onRefresh: onRefresh,
        );
        final mechanicSection = _CrewSection(
          category: 'mechanic',
          title: l10n.t('crew.mechanic'),
          members: mechanics,
          grades: grades,
          units: units,
          canManage: canManage,
          isGlobal: isGlobal,
          onSelect: onSelect,
          onEdit: onEdit,
          onDeactivate: onDeactivate,
          onRefresh: onRefresh,
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: pilotSection),
                    const SizedBox(width: 16),
                    Expanded(child: mechanicSection),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    pilotSection,
                    const SizedBox(height: 16),
                    mechanicSection,
                  ],
                ),
        );
      },
    );
  }
}

class _CadetsWorkspace extends ConsumerStatefulWidget {
  const _CadetsWorkspace({
    required this.unitId,
    required this.grades,
    required this.canManage,
    required this.onBack,
  });

  final String unitId;
  final List<GradeOption> grades;
  final bool canManage;
  final VoidCallback onBack;

  @override
  ConsumerState<_CadetsWorkspace> createState() => _CadetsWorkspaceState();
}

class _CadetsWorkspaceState extends ConsumerState<_CadetsWorkspace> {
  String? _selectedCourseId;

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(_cadetCoursesProvider(widget.unitId));

    return coursesAsync.when(
      loading: () =>
          const DataStateView(kind: DataStateKind.loading, title: ''),
      error: (_, _) => DataStateView(
        kind: DataStateKind.systemError,
        title: 'No se pudo cargar cursos',
        message: 'Reintentar',
        onRetry: () => ref.invalidate(_cadetCoursesProvider(widget.unitId)),
      ),
      data: (result) {
        final courses = switch (result) {
          AppSuccess<List<CadetCourse>>(data: final list) => list,
          AppFailure<List<CadetCourse>>() => null,
        };
        if (courses == null) {
          final error = (result as AppFailure<List<CadetCourse>>).error;
          return DataStateView(
            kind: DataStateKind.systemError,
            title: 'No se pudo cargar cursos',
            message: error.message,
            onRetry: () => ref.invalidate(_cadetCoursesProvider(widget.unitId)),
          );
        }

        final selectedCourse = courses.isEmpty
            ? null
            : courses.firstWhere(
                (course) => course.id == _selectedCourseId,
                orElse: () => courses.first,
              );

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CadetsToolbar(
                courses: courses,
                selectedCourse: selectedCourse,
                canManage: widget.canManage,
                onBack: widget.onBack,
                onCourseChanged: (courseId) =>
                    setState(() => _selectedCourseId = courseId),
                onCreateCourse: _createCourse,
                onAddCadet: selectedCourse == null
                    ? null
                    : () => _addCadet(selectedCourse),
                onArchiveCourse:
                    selectedCourse == null || !selectedCourse.isActive
                    ? null
                    : () => _archiveCourse(selectedCourse),
              ),
              const SizedBox(height: 12),
              if (selectedCourse == null)
                const DataStateView(
                  kind: DataStateKind.empty,
                  title: 'Sin cursos de cadetes registrados',
                )
              else
                _CadetCourseTable(course: selectedCourse),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createCourse() async {
    final draft = await _showCourseDialog(context);
    if (draft == null || !mounted) return;

    final result = await ref
        .read(cadetCourseRepositoryProvider)
        .createCourse(
          unitId: widget.unitId,
          name: draft.name,
          startDate: draft.startDate,
          endDate: draft.endDate,
        );
    if (!mounted) return;

    switch (result) {
      case AppSuccess<CadetCourse>(data: final course):
        setState(() => _selectedCourseId = course.id);
        ref.invalidate(_cadetCoursesProvider(widget.unitId));
      case AppFailure<CadetCourse>(error: final error):
        _showSnack(error.message);
    }
  }

  Future<void> _addCadet(CadetCourse course) async {
    final cadetGrades = widget.grades
        .where((grade) => grade.category == 'pilot')
        .toList();
    final result = await showCadetFormDialog(
      context,
      cadetGrades: cadetGrades.isEmpty ? widget.grades : cadetGrades,
      course: course,
    );
    if (result == null || !mounted) return;

    final saveResult = await ref
        .read(crewRepositoryProvider)
        .saveCrewMember(
          unitId: widget.unitId,
          grade: result.grade,
          firstName: result.firstName,
          lastName: result.lastName,
          nsa: result.nsa,
          crewCategory: 'pilot',
          appointmentDate: result.trainingStart,
          assignmentType: 'nato',
          trainingStart: result.trainingStart,
          trainingEnd: result.trainingEnd,
          courseGroup: course.name,
          cadetCourseId: result.cadetCourseId,
        );
    if (!mounted) return;

    switch (saveResult) {
      case AppSuccess<void>():
        ref.invalidate(_cadetsByCourseProvider(course.id));
        ref.invalidate(_cadetCoursesProvider(widget.unitId));
      case AppFailure<void>(error: final error):
        _showSnack(error.message);
    }
  }

  Future<void> _archiveCourse(CadetCourse course) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archivar curso'),
        content: Text('¿Archivar ${course.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Archivar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final result = await ref
        .read(cadetCourseRepositoryProvider)
        .archiveCourse(course.id);
    if (!mounted) return;

    switch (result) {
      case AppSuccess<void>():
        ref.invalidate(_cadetCoursesProvider(widget.unitId));
        ref.invalidate(_cadetsByCourseProvider(course.id));
      case AppFailure<void>(error: final error):
        _showSnack(error.message);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CadetsToolbar extends StatelessWidget {
  const _CadetsToolbar({
    required this.courses,
    required this.selectedCourse,
    required this.canManage,
    required this.onBack,
    required this.onCourseChanged,
    required this.onCreateCourse,
    required this.onAddCadet,
    required this.onArchiveCourse,
  });

  final List<CadetCourse> courses;
  final CadetCourse? selectedCourse;
  final bool canManage;
  final VoidCallback onBack;
  final void Function(String? courseId) onCourseChanged;
  final VoidCallback onCreateCourse;
  final VoidCallback? onAddCadet;
  final VoidCallback? onArchiveCourse;

  @override
  Widget build(BuildContext context) {
    final selectedCourseId = selectedCourse?.id;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_outlined, size: 18),
              label: const Text('Volver a Tripulantes'),
            ),
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String>(
                initialValue: selectedCourseId,
                decoration: const InputDecoration(
                  labelText: 'Curso',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final course in courses)
                    DropdownMenuItem(
                      value: course.id,
                      child: Text(
                        '${course.name} (${course.status})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: onCourseChanged,
              ),
            ),
            if (canManage) ...[
              FilledButton.icon(
                onPressed: onCreateCourse,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuevo Curso'),
              ),
              FilledButton.tonalIcon(
                onPressed: onAddCadet,
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                label: const Text('Agregar Cadete'),
              ),
              OutlinedButton.icon(
                onPressed: onArchiveCourse,
                icon: const Icon(Icons.archive_outlined, size: 18),
                label: const Text('Archivar Curso'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CadetCourseTable extends ConsumerWidget {
  const _CadetCourseTable({required this.course});

  final CadetCourse course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cadetsAsync = ref.watch(_cadetsByCourseProvider(course.id));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: cadetsAsync.when(
          loading: () =>
              const DataStateView(kind: DataStateKind.loading, title: ''),
          error: (_, _) => DataStateView(
            kind: DataStateKind.systemError,
            title: 'No se pudo cargar cadetes',
            message: 'Reintentar',
            onRetry: () => ref.invalidate(_cadetsByCourseProvider(course.id)),
          ),
          data: (result) {
            final cadets = switch (result) {
              AppSuccess<List<CrewMember>>(data: final list) => list,
              AppFailure<List<CrewMember>>() => null,
            };

            if (cadets == null) {
              final error = (result as AppFailure<List<CrewMember>>).error;
              return DataStateView(
                kind: DataStateKind.systemError,
                title: 'No se pudo cargar cadetes',
                message: error.message,
                onRetry: () =>
                    ref.invalidate(_cadetsByCourseProvider(course.id)),
              );
            }

            if (cadets.isEmpty) {
              return const DataStateView(
                kind: DataStateKind.empty,
                title: 'Sin cadetes registrados',
              );
            }

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 620),
                child: DataTable(
                  dataRowMinHeight: 38,
                  dataRowMaxHeight: 44,
                  showCheckboxColumn: false,
                  columns: const [
                    DataColumn(label: Text('Grado')),
                    DataColumn(label: Text('Nombres')),
                    DataColumn(label: Text('Apellidos')),
                    DataColumn(label: Text('NSA')),
                    DataColumn(label: Text('Turnos')),
                  ],
                  rows: [
                    for (final cadet in cadets)
                      DataRow(
                        onSelectChanged: (_) =>
                            showCadetDetailModal(context, ref, cadet),
                        cells: [
                          DataCell(Text(cadet.grade)),
                          DataCell(Text(cadet.firstName)),
                          DataCell(Text(cadet.lastName)),
                          DataCell(Text(cadet.nsa)),
                          DataCell(Text(cadet.cadetTurn?.toString() ?? '--')),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CrewSection extends StatefulWidget {
  const _CrewSection({
    required this.category,
    required this.title,
    required this.members,
    required this.grades,
    required this.units,
    required this.canManage,
    required this.isGlobal,
    required this.onSelect,
    required this.onEdit,
    required this.onDeactivate,
    required this.onRefresh,
  });

  final String category;
  final String title;
  final List<CrewMember> members;
  final List<GradeOption> grades;
  final List<UnitOption> units;
  final bool canManage;
  final bool isGlobal;
  final void Function(CrewMember) onSelect;
  final void Function(CrewMember) onEdit;
  final void Function(CrewMember) onDeactivate;
  final VoidCallback onRefresh;

  @override
  State<_CrewSection> createState() => _CrewSectionState();
}

class _CrewSectionState extends State<_CrewSection> {
  String _gradeFilter = '';
  String _assignmentFilter = '';
  String _unitFilter = '';

  List<CrewMember> get _filteredMembers {
    return widget.members.where((member) {
      if (_gradeFilter.isNotEmpty && member.grade != _gradeFilter) {
        return false;
      }
      if (_assignmentFilter.isNotEmpty &&
          member.assignmentType != _assignmentFilter) {
        return false;
      }
      if (_unitFilter.isNotEmpty && member.unitId != _unitFilter) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final gradeOptions = widget.members.map((m) => m.grade).toSet().toList()
      ..sort();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  widget.category == 'pilot'
                      ? Icons.shield_outlined
                      : Icons.build_outlined,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${_filteredMembers.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<String>(
                    initialValue: '',
                    decoration: InputDecoration(
                      labelText: l10n.t('crew.grade'),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    isDense: true,
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text(
                          l10n.t('crew.all'),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      for (final grade in gradeOptions)
                        DropdownMenuItem(
                          value: grade,
                          child: Text(
                            grade,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _gradeFilter = value ?? ''),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<String>(
                    initialValue: '',
                    decoration: InputDecoration(
                      labelText: l10n.t('crew.assignmentType'),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    isDense: true,
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text(
                          l10n.t('crew.all'),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'nato',
                        child: Text(
                          l10n.t('crew.nato'),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'foraneo',
                        child: Text(
                          l10n.t('crew.foraneo'),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _assignmentFilter = value ?? ''),
                  ),
                ),
                if (widget.isGlobal)
                  SizedBox(
                    width: 140,
                    child: DropdownButtonFormField<String>(
                      initialValue: '',
                      decoration: InputDecoration(
                        labelText: l10n.t('aircraft.unit'),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      isDense: true,
                      items: [
                        DropdownMenuItem(
                          value: '',
                          child: Text(
                            l10n.t('crew.all'),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        for (final unit in widget.units)
                          DropdownMenuItem(
                            value: unit.id,
                            child: Text(
                              unit.code,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _unitFilter = value ?? ''),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (_filteredMembers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    l10n.t('crew.empty'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 480),
                  child: DataTable(
                    headingTextStyle: Theme.of(context).textTheme.titleSmall,
                    dataRowMinHeight: 38,
                    dataRowMaxHeight: 44,
                    showCheckboxColumn: false,
                    columns: [
                      DataColumn(label: Text(l10n.t('crew.grade'))),
                      DataColumn(label: Text(l10n.t('crew.firstName'))),
                      DataColumn(label: Text(l10n.t('crew.lastName'))),
                      DataColumn(label: Text(l10n.t('crew.nsa'))),
                    ],
                    rows: [
                      for (final member in _filteredMembers)
                        DataRow(
                          onSelectChanged: (_) => widget.onSelect(member),
                          cells: [
                            DataCell(_textCell(member.grade)),
                            DataCell(_textCell(member.firstName)),
                            DataCell(_textCell(member.lastName)),
                            DataCell(_textCell(member.nsa)),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _textCell(String value) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );
  }
}

class _CourseDraft {
  const _CourseDraft({
    required this.name,
    required this.startDate,
    required this.endDate,
  });

  final String name;
  final DateTime startDate;
  final DateTime endDate;
}

Future<_CourseDraft?> _showCourseDialog(BuildContext context) {
  final nameController = TextEditingController();
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now().add(const Duration(days: 90));

  return showDialog<_CourseDraft>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Nuevo Curso'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del curso',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              _DateField(
                label: 'Inicio',
                value: startDate,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: startDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) setState(() => startDate = picked);
                },
              ),
              const SizedBox(height: 12),
              _DateField(
                label: 'Fin',
                value: endDate,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: endDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) setState(() => endDate = picked);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.of(dialogContext).pop(
                _CourseDraft(
                  name: name,
                  startDate: startDate,
                  endDate: endDate,
                ),
              );
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    ),
  ).whenComplete(nameController.dispose);
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        child: Text(_formatDate(value)),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _CrewEmptyState extends StatelessWidget {
  const _CrewEmptyState({required this.canManage, required this.onAdd});

  final bool canManage;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.groups_2_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.t('crew.empty'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (canManage) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: Text(l10n.t('crew.add')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
