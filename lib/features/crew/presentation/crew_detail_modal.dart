import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/crew/data/crew_repository.dart';
import 'package:cg6_flights/features/crew/data/grades_repository.dart';
import 'package:cg6_flights/features/crew/data/squadron_repository.dart';
import 'package:cg6_flights/features/crew/domain/crew_member.dart';
import 'package:cg6_flights/features/crew/domain/grade_option.dart';
import 'package:cg6_flights/features/crew/domain/squadron.dart';
import 'package:cg6_flights/features/units/data/units_repository.dart';
import 'package:cg6_flights/features/units/domain/unit_option.dart';
import 'package:cg6_flights/shared/widgets/profile_avatar_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<bool?> showCrewDetailModal(
  BuildContext context,
  CrewMember member,
  WidgetRef ref,
) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CrewDetailModal(member: member),
  );
}

class _CrewDetailModal extends ConsumerStatefulWidget {
  const _CrewDetailModal({required this.member});

  final CrewMember member;

  @override
  ConsumerState<_CrewDetailModal> createState() => _CrewDetailModalState();
}

class _CrewDetailModalState extends ConsumerState<_CrewDetailModal> {
  final _formKey = GlobalKey<FormState>();
  late CrewMember _member;
  late String _unitId;
  String? _squadronId;
  late String _grade;
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _nsaController;
  late Future<AppResult<List<CrewFlightLog>>> _logsFuture;

  List<UnitOption> _units = const [];
  List<GradeOption> _grades = const [];
  List<FlightSquadron> _squadrons = const [];
  bool _loadingRefs = true;
  bool _savingProfile = false;
  bool _uploadingPhoto = false;
  bool _savingQualifications = false;
  bool _changed = false;
  String? _error;

  static const _gru51Id = '4317c6f3-e530-4b9c-a898-1f765ceaafb2';

  bool get _isGru51 => _unitId == _gru51Id;

  @override
  void initState() {
    super.initState();
    _member = widget.member;
    _unitId = _member.unitId;
    _squadronId = _member.squadronId;
    _grade = _member.grade;
    _firstNameController = TextEditingController(text: _member.firstName);
    _lastNameController = TextEditingController(text: _member.lastName);
    _nsaController = TextEditingController(text: _member.nsa);
    _logsFuture = ref
        .read(crewRepositoryProvider)
        .listCrewFlightLogs(_member.id);
    _loadReferences();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _nsaController.dispose();
    super.dispose();
  }

  Future<void> _loadReferences() async {
    final results = await Future.wait([
      ref.read(unitsRepositoryProvider).listUnits(),
      ref.read(gradesRepositoryProvider).listGrades(),
      ref.read(squadronRepositoryProvider).listSquadrons(),
    ]);

    if (!mounted) return;

    final unitsResult = results[0] as AppResult<List<UnitOption>>;
    final gradesResult = results[1] as AppResult<List<GradeOption>>;
    final squadronsResult = results[2] as AppResult<List<FlightSquadron>>;

    setState(() {
      _units = switch (unitsResult) {
        AppSuccess<List<UnitOption>>(data: final list) =>
          list.where((u) => u.active).toList(),
        _ => const <UnitOption>[],
      };
      _grades = switch (gradesResult) {
        AppSuccess<List<GradeOption>>(data: final list) => list,
        _ => const <GradeOption>[],
      };
      _squadrons = switch (squadronsResult) {
        AppSuccess<List<FlightSquadron>>(data: final list) => list,
        _ => const <FlightSquadron>[],
      };
      _loadingRefs = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final width = (size.width * 0.9).clamp(320.0, 1180.0).toDouble();
    final height = (size.height * 0.85).clamp(420.0, 820.0).toDouble();

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      title: Row(
        children: [
          Expanded(
            child: Text(
              '${l10n.t('crew.detail.lifeSheet')} · ${_member.fullName}',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: l10n.t('common.close'),
            onPressed: () => Navigator.of(context).pop(_changed),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: width,
        height: height,
        child: DefaultTabController(
          length: 4,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(text: l10n.t('crew.detail.profile')),
                    Tab(text: l10n.t('crew.detail.hours')),
                    Tab(text: l10n.t('crew.detail.aircraft')),
                    Tab(text: l10n.t('crew.qualifications')),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                _InlineError(message: _error!),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    _profileTab(l10n),
                    _hoursTab(l10n),
                    _aircraftTab(l10n),
                    _qualificationsTab(l10n),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileTab(AppLocalizations l10n) {
    if (_loadingRefs) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredGrades = _grades
        .where((g) => g.category == _member.crewCategory)
        .toList();
    final validGrade = filteredGrades.any((g) => g.code == _grade);
    final validUnit = _units.any((u) => u.id == _unitId);
    final validSquadron = _squadrons.any((s) => s.id == _squadronId);

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 720;
            final photo = _photoBlock(l10n);
            final form = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: validGrade ? _grade : null,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.t('crew.grade'),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final grade in filteredGrades)
                      DropdownMenuItem(
                        value: grade.code,
                        child: Text(grade.code),
                      ),
                  ],
                  onChanged: (value) => setState(() => _grade = value ?? ''),
                  validator: (value) => value == null || value.isEmpty
                      ? l10n.t('validation.required')
                      : null,
                ),
                const SizedBox(height: 12),
                _responsivePair(
                  first: TextFormField(
                    controller: _firstNameController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: l10n.t('crew.firstName'),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? l10n.t('validation.required')
                        : null,
                  ),
                  second: TextFormField(
                    controller: _lastNameController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: l10n.t('crew.lastName'),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? l10n.t('validation.required')
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nsaController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: l10n.t('crew.nsa'),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final nsa = value?.trim() ?? '';
                    if (nsa.isEmpty) return l10n.t('validation.required');
                    if (nsa.length < 3) return l10n.t('crew.nsaMinLength');
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: validUnit ? _unitId : null,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.t('aircraft.unit'),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final unit in _units)
                      DropdownMenuItem(
                        value: unit.id,
                        child: Text('${unit.code} · ${unit.name}'),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _unitId = value ?? _unitId;
                      if (!_isGru51) _squadronId = null;
                    });
                  },
                  validator: (value) => value == null || value.isEmpty
                      ? l10n.t('validation.required')
                      : null,
                ),
                if (_isGru51) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: validSquadron ? _squadronId : null,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.t('crew.squadron'),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(l10n.t('crew.detail.noSquadron')),
                      ),
                      for (final squadron in _squadrons)
                        DropdownMenuItem<String?>(
                          value: squadron.id,
                          child: Text(squadron.name),
                        ),
                    ],
                    onChanged: (value) => setState(() => _squadronId = value),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _savingProfile ? null : _confirmDelete,
                      icon: const Icon(Icons.delete_outline),
                      label: Text(l10n.t('crew.deactivate')),
                    ),
                    FilledButton.icon(
                      onPressed: _savingProfile ? null : _saveProfile,
                      icon: _savingProfile
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(l10n.t('crew.detail.saveChanges')),
                    ),
                  ],
                ),
              ],
            );

            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [photo, const SizedBox(height: 18), form],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 210, child: photo),
                const SizedBox(width: 24),
                Expanded(child: form),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _photoBlock(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final photoUrl = _member.photoPath;
    final validUrl = _isValidHttpUrl(photoUrl);
    return Column(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: theme.colorScheme.primaryContainer,
          backgroundImage: validUrl ? NetworkImage(photoUrl!) : null,
          child: validUrl
              ? null
              : Text(
                  _initials(_member),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _uploadingPhoto ? null : _pickAndUploadPhoto,
          icon: _uploadingPhoto
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.photo_camera_outlined),
          label: Text(l10n.t('crew.detail.uploadPhoto')),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.t('crew.detail.photoHint'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _hoursTab(AppLocalizations l10n) {
    return FutureBuilder<AppResult<List<CrewFlightLog>>>(
      future: _logsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final result = snapshot.data!;
        final logs = switch (result) {
          AppSuccess<List<CrewFlightLog>>(data: final list) => list,
          AppFailure<List<CrewFlightLog>>() => null,
        };
        if (logs == null) {
          return _InlineError(message: (result as AppFailure).error.message);
        }
        final now = DateTime.now();
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final monthStart = DateTime(now.year, now.month);
        final yearStart = DateTime(now.year);
        final week = _sumHours(logs, weekStart);
        final month = _sumHours(logs, monthStart);
        final year = _sumHours(logs, yearStart);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 620;
                  final cards = [
                    _HourKpi(label: l10n.t('crew.detail.week'), value: week),
                    _HourKpi(label: l10n.t('crew.detail.month'), value: month),
                    _HourKpi(label: l10n.t('crew.detail.year'), value: year),
                  ];
                  if (narrow) {
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final card in cards)
                          SizedBox(width: 150, child: card),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      for (int i = 0; i < cards.length; i++) ...[
                        Expanded(child: cards[i]),
                        if (i != cards.length - 1) const SizedBox(width: 10),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              Text(
                l10n.t('crew.detail.lastFlights'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (logs.isEmpty)
                _EmptyPanel(message: l10n.t('crew.detail.noFlights'))
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      DataColumn(
                        label: Text(l10n.t('flightOrders.operationDate')),
                      ),
                      DataColumn(label: Text(l10n.t('nav.aircraft'))),
                      DataColumn(label: Text(l10n.t('flightOrders.mission'))),
                      DataColumn(label: Text(l10n.t('flightOrders.ete'))),
                      DataColumn(label: Text(l10n.t('crew.detail.rating'))),
                      DataColumn(label: Text(l10n.t('crew.turn'))),
                      DataColumn(label: Text(l10n.t('crew.checkRide'))),
                    ],
                    rows: [
                      for (final log in logs.take(20))
                        DataRow(
                          cells: [
                            DataCell(Text(_date(log.operationDate))),
                            DataCell(Text(log.aircraftRegistration ?? '--')),
                            DataCell(Text(log.mission ?? '--')),
                            DataCell(Text(_minutes(log.eteMinutes))),
                            DataCell(Text(_rating(log.rating))),
                            DataCell(Text(log.cadetTurn?.toString() ?? '--')),
                            DataCell(Text(log.checkRide ?? '--')),
                          ],
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

  Widget _aircraftTab(AppLocalizations l10n) {
    return FutureBuilder<AppResult<List<CrewFlightLog>>>(
      future: _logsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final result = snapshot.data!;
        final logs = switch (result) {
          AppSuccess<List<CrewFlightLog>>(data: final list) => list,
          _ => const <CrewFlightLog>[],
        };
        final models =
            logs
                .map((log) => log.aircraftModel)
                .whereType<String>()
                .where((model) => model.trim().isNotEmpty)
                .toSet()
                .toList()
              ..sort();

        if (models.isEmpty) {
          return _EmptyPanel(message: l10n.t('crew.detail.noAircraft'));
        }

        return Align(
          alignment: Alignment.topLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final model in models)
                Chip(
                  avatar: const Icon(Icons.check_circle, size: 18),
                  label: Text('$model · ${l10n.t('crew.detail.enabled')}'),
                  side: BorderSide.none,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.55),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _qualificationsTab(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final canEdit = _member.isPilot;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!canEdit)
            _EmptyPanel(message: l10n.t('crew.detail.mechanicNoQualifications'))
          else ...[
            Text(
              l10n.t('crew.detail.qualificationsHint'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final qualification in CrewMember.validQualifications)
                  FilterChip(
                    label: Text(qualification),
                    selected: _member.qualifications.contains(qualification),
                    onSelected: _savingQualifications
                        ? null
                        : (selected) =>
                              _toggleQualification(qualification, selected),
                  ),
              ],
            ),
            if (_savingQualifications) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _savingProfile = true;
      _error = null;
    });

    final result = await ref
        .read(crewRepositoryProvider)
        .saveCrewMember(
          crewMemberId: _member.id,
          unitId: _unitId,
          grade: _grade,
          firstName: _firstNameController.text.trim().toUpperCase(),
          lastName: _lastNameController.text.trim().toUpperCase(),
          nsa: _nsaController.text.trim(),
          crewCategory: _member.crewCategory,
          appointmentDate: _member.appointmentDate,
          assignmentType: _member.assignmentType,
          qualifications: _member.qualifications,
          squadronId: _isGru51 ? _squadronId : null,
          trainingStart: _member.trainingStart,
          trainingEnd: _member.trainingEnd,
          courseGroup: _member.courseGroup,
        );

    if (!mounted) return;
    switch (result) {
      case AppSuccess<void>():
        setState(() {
          _member = _memberWith(
            grade: _grade,
            firstName: _firstNameController.text.trim().toUpperCase(),
            lastName: _lastNameController.text.trim().toUpperCase(),
            nsa: _nsaController.text.trim(),
            unitId: _unitId,
            squadronId: _isGru51 ? _squadronId : null,
            replaceSquadron: true,
          );
          _savingProfile = false;
          _changed = true;
        });
      case AppFailure<void>(error: final error):
        setState(() {
          _savingProfile = false;
          _error = error.message;
        });
    }
  }

  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('crew.deactivate')),
        content: Text(
          '${l10n.t('crew.deactivateConfirm')} ${_member.fullName}?',
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
    if (confirm != true || !mounted) return;

    setState(() {
      _savingProfile = true;
      _error = null;
    });
    final result = await ref
        .read(crewRepositoryProvider)
        .deactivateCrewMember(_member.id);
    if (!mounted) return;

    switch (result) {
      case AppSuccess<void>():
        Navigator.of(context).pop(true);
      case AppFailure<void>(error: final error):
        setState(() {
          _savingProfile = false;
          _error = error.message;
        });
    }
  }

  Future<void> _toggleQualification(String qualification, bool selected) async {
    final previous = List<String>.from(_member.qualifications);
    final next = selected
        ? {..._member.qualifications, qualification}.toList()
        : _member.qualifications.where((q) => q != qualification).toList();

    setState(() {
      _savingQualifications = true;
      _error = null;
      _member = _memberWith(qualifications: next);
    });

    final result = await ref
        .read(crewRepositoryProvider)
        .saveCrewMember(
          crewMemberId: _member.id,
          unitId: _member.unitId,
          grade: _member.grade,
          firstName: _member.firstName,
          lastName: _member.lastName,
          nsa: _member.nsa,
          crewCategory: _member.crewCategory,
          appointmentDate: _member.appointmentDate,
          assignmentType: _member.assignmentType,
          qualifications: next,
          squadronId: _member.squadronId,
          trainingStart: _member.trainingStart,
          trainingEnd: _member.trainingEnd,
          courseGroup: _member.courseGroup,
        );

    if (!mounted) return;
    switch (result) {
      case AppSuccess<void>():
        setState(() {
          _savingQualifications = false;
          _changed = true;
        });
      case AppFailure<void>(error: final error):
        setState(() {
          _savingQualifications = false;
          _member = _memberWith(qualifications: previous);
          _error = error.message;
        });
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _error = null);

    final selected = await pickProfileImageData();
    if (selected == null || !mounted) return;

    if (!{
      'image/jpeg',
      'image/png',
      'image/webp',
    }.contains(selected.mimeType)) {
      setState(() => _error = l10n.t('crew.detail.invalidPhoto'));
      return;
    }

    final cropped = await showDialog<_CrewPhotoCropResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CrewPhotoCropDialog(bytes: selected.bytes),
    );
    if (cropped == null || !mounted) return;

    setState(() => _uploadingPhoto = true);

    final result = await ref
        .read(crewRepositoryProvider)
        .uploadCrewPhoto(
          crewMemberId: _member.id,
          bytes: cropped.bytes,
          fileName: 'crew_${DateTime.now().millisecondsSinceEpoch}.jpg',
          contentType: cropped.contentType,
        );

    if (!mounted) return;
    switch (result) {
      case AppSuccess<String>(data: final url):
        setState(() {
          _member = _memberWith(photoPath: url);
          _uploadingPhoto = false;
          _changed = true;
        });
      case AppFailure<String>(error: final error):
        setState(() {
          _uploadingPhoto = false;
          _error = error.message;
        });
    }
  }

  CrewMember _memberWith({
    String? unitId,
    String? grade,
    String? firstName,
    String? lastName,
    String? nsa,
    String? squadronId,
    bool replaceSquadron = false,
    List<String>? qualifications,
    String? photoPath,
  }) {
    return CrewMember(
      id: _member.id,
      unitId: unitId ?? _member.unitId,
      grade: grade ?? _member.grade,
      firstName: firstName ?? _member.firstName,
      lastName: lastName ?? _member.lastName,
      nsa: nsa ?? _member.nsa,
      crewCategory: _member.crewCategory,
      appointmentDate: _member.appointmentDate,
      active: _member.active,
      assignmentType: _member.assignmentType,
      callsign: _member.callsign,
      qualifications: qualifications ?? _member.qualifications,
      squadronId: replaceSquadron ? squadronId : _member.squadronId,
      squadronName: _member.squadronName,
      trainingStart: _member.trainingStart,
      trainingEnd: _member.trainingEnd,
      courseGroup: _member.courseGroup,
      cadetCourseId: _member.cadetCourseId,
      cadetCourseName: _member.cadetCourseName,
      photoPath: photoPath ?? _member.photoPath,
    );
  }

  Widget _responsivePair({required Widget first, required Widget second}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: 12), second],
          );
        }
        return Row(
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  double _sumHours(List<CrewFlightLog> logs, DateTime from) {
    return logs
        .where((log) => !log.operationDate.isBefore(from))
        .fold<double>(
          0,
          (sum, log) =>
              sum +
              (log.actualMinutes != null ? log.actualHours : log.plannedHours),
        );
  }

  bool _isValidHttpUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  String _initials(CrewMember member) {
    final first = member.firstName.isNotEmpty ? member.firstName[0] : '';
    final last = member.lastName.isNotEmpty ? member.lastName[0] : '';
    return '$first$last'.toUpperCase();
  }

  String _date(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _minutes(int? minutes) {
    if (minutes == null) return '--';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  String _rating(String? rating) {
    return switch (rating) {
      'good' => 'Apto',
      'bad' => 'Observado',
      null || '' => '--',
      _ => rating,
    };
  }
}

class _HourKpi extends StatelessWidget {
  const _HourKpi({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            '${value.toStringAsFixed(1)} h',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: theme.colorScheme.errorContainer,
      ),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onErrorContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _CrewPhotoCropResult {
  const _CrewPhotoCropResult({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}

class _CrewPhotoCropDialog extends StatefulWidget {
  const _CrewPhotoCropDialog({required this.bytes});

  final Uint8List bytes;

  @override
  State<_CrewPhotoCropDialog> createState() => _CrewPhotoCropDialogState();
}

class _CrewPhotoCropDialogState extends State<_CrewPhotoCropDialog> {
  final _transformController = TransformationController();
  bool _processing = false;
  String? _error;

  static const _outputSize = 512;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final previewSize = (MediaQuery.sizeOf(context).width - 96)
        .clamp(200.0, 360.0)
        .toDouble();

    return AlertDialog(
      title: Text(l10n.t('profile.adjustPhoto')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: previewSize,
            height: previewSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipOval(
                  child: InteractiveViewer(
                    transformationController: _transformController,
                    minScale: 0.7,
                    maxScale: 4,
                    boundaryMargin: EdgeInsets.all(previewSize / 3),
                    child: SizedBox(
                      width: previewSize,
                      height: previewSize,
                      child: Center(
                        child: Image.memory(widget.bytes, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Container(
                    width: previewSize,
                    height: previewSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.t('crew.detail.photoHint'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _processing ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.t('common.cancel')),
        ),
        TextButton(
          onPressed: _processing
              ? null
              : () => _transformController.value = Matrix4.identity(),
          child: Text(l10n.t('common.reset')),
        ),
        FilledButton(
          onPressed: _processing ? null : _confirm,
          child: _processing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.t('profile.useThisPhoto')),
        ),
      ],
    );
  }

  Future<void> _confirm() async {
    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      final previewSize = (MediaQuery.sizeOf(context).width - 96)
          .clamp(200.0, 360.0)
          .toDouble();
      final bytes = await cropAvatarJpeg(
        bytes: widget.bytes,
        transformStorage: _transformController.value.storage,
        previewSize: previewSize,
        outputSize: _outputSize,
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(_CrewPhotoCropResult(bytes: bytes, contentType: 'image/jpeg'));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = AppLocalizations.of(context).t('crew.detail.photoFailed');
      });
    }
  }
}
