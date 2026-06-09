import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/features/crew/domain/crew_member.dart';
import 'package:cg6_flights/features/crew/domain/grade_option.dart';
import 'package:cg6_flights/features/crew/domain/squadron.dart';
import 'package:cg6_flights/features/units/domain/unit_option.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CrewFormResult {
  CrewFormResult({
    required this.unitId,
    required this.grade,
    required this.firstName,
    required this.lastName,
    required this.nsa,
    required this.crewCategory,
    required this.appointmentDate,
    required this.assignmentType,
    this.callsign,
    this.qualifications = const [],
    this.squadronId,
    this.trainingStart,
    this.trainingEnd,
    this.courseGroup,
  });

  final String unitId;
  final String grade;
  final String firstName;
  final String lastName;
  final String nsa;
  final String crewCategory;
  final DateTime appointmentDate;
  final String assignmentType;
  final String? callsign;
  final List<String> qualifications;
  final String? squadronId;
  final DateTime? trainingStart;
  final DateTime? trainingEnd;
  final String? courseGroup;
}

class CrewFormDialog extends StatefulWidget {
  const CrewFormDialog({
    super.key,
    this.member,
    required this.units,
    required this.grades,
    this.defaultUnitId,
    this.squadrons = const [],
    this.userRole,
    this.userSquadronId,
  });

  final CrewMember? member;
  final List<UnitOption> units;
  final List<GradeOption> grades;
  final String? defaultUnitId;
  final List<FlightSquadron> squadrons;
  final String? userRole;
  final String? userSquadronId;

  @override
  State<CrewFormDialog> createState() => _CrewFormDialogState();
}

class _CrewFormDialogState extends State<CrewFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _unitId;
  late String _crewCategory;
  late String _grade;
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _nsaController;
  late final TextEditingController _callsignController;
  late DateTime _appointmentDate;
  late String _assignmentType;
  late List<String> _qualifications;
  String? _squadronId;
  DateTime? _trainingStart;
  DateTime? _trainingEnd;
  final _courseGroupCtrl = TextEditingController();

  bool get _isEdaci => _unitId == 'c95a95da-81a9-420e-b574-db15f56c5d9f';

  List<GradeOption> get _filteredGrades =>
      widget.grades.where((g) => g.category == _crewCategory).toList();

  bool get _isGru51 => _unitId == '4317c6f3-e530-4b9c-a898-1f765ceaafb2';
  bool get _isSquadronChief => widget.userRole == 'squadron_chief';
  bool get _showSquadron => _isGru51 && widget.squadrons.isNotEmpty && !_isSquadronChief;

  bool get _isEditing => widget.member != null;

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    _unitId =
        m?.unitId ??
        widget.defaultUnitId ??
        (widget.units.length == 1 ? widget.units.single.id : '');
    _crewCategory = m?.crewCategory ?? 'pilot';
    _grade = m?.grade ?? '';
    _firstNameController = TextEditingController(text: m?.firstName ?? '');
    _lastNameController = TextEditingController(text: m?.lastName ?? '');
    _nsaController = TextEditingController(text: m?.nsa ?? '');
    _callsignController = TextEditingController(text: m?.callsign ?? '');
    _appointmentDate = m?.appointmentDate ?? DateTime.now();
    _assignmentType = m?.assignmentType ?? 'nato';
    _qualifications = List<String>.from(m?.qualifications ?? []);
    _squadronId = m?.squadronId ?? (_isSquadronChief ? widget.userSquadronId : null);
    _trainingStart = m?.trainingStart;
    _trainingEnd = m?.trainingEnd;
    _courseGroupCtrl.text = m?.courseGroup ?? '';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _nsaController.dispose();
    _callsignController.dispose();
    _courseGroupCtrl.dispose();
    super.dispose();
  }

  Widget _buildTrainingSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Text('Periodo de Instrucción (EDACI)', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _trainingStart ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                if (d != null) setState(() => _trainingStart = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Inicio', border: OutlineInputBorder(), isDense: true),
                child: Text(_trainingStart != null ? '${_trainingStart!.day}/${_trainingStart!.month}/${_trainingStart!.year}' : 'Seleccionar'),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _trainingEnd ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                if (d != null) setState(() => _trainingEnd = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Fin', border: OutlineInputBorder(), isDense: true),
                child: Text(_trainingEnd != null ? '${_trainingEnd!.day}/${_trainingEnd!.month}/${_trainingEnd!.year}' : 'Seleccionar'),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        TextFormField(
          controller: _courseGroupCtrl,
          decoration: const InputDecoration(labelText: 'Grupo / Curso', border: OutlineInputBorder(), hintText: 'Ej: CURSO BÁSICO 2026-I'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    final l10n = AppLocalizations.of(context);
    final isGlobal = widget.units.length > 1;
    final viewport = MediaQuery.sizeOf(context);
    final dialogWidth = (viewport.width - 80).clamp(240.0, 440.0).toDouble();
    final dialogMaxHeight = (viewport.height * 0.76)
        .clamp(320.0, 680.0)
        .toDouble();

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(_isEditing ? l10n.t('crew.edit') : l10n.t('crew.add')),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 440, maxHeight: dialogMaxHeight),
        child: SizedBox(
          width: dialogWidth,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isGlobal)
                    DropdownButtonFormField<String>(
                      initialValue: _unitId.isNotEmpty ? _unitId : null,
                      decoration: InputDecoration(
                        labelText: l10n.t('aircraft.unit'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        for (final u in widget.units)
                          DropdownMenuItem(
                            value: u.id,
                            child: Text('${u.code} — ${u.name}'),
                          ),
                      ],
                      onChanged: (v) => setState(() => _unitId = v ?? ''),
                      validator: (v) => (v == null || v.isEmpty)
                          ? l10n.t('validation.required')
                          : null,
                    ),
                  if (isGlobal) const SizedBox(height: 16),
                  if (_showSquadron) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _squadronId,
                      decoration: InputDecoration(
                        labelText: l10n.t('crew.squadron'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        for (final s in widget.squadrons)
                          DropdownMenuItem(value: s.id, child: Text(s.name)),
                      ],
                      onChanged: (v) => setState(() => _squadronId = v),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_isEdaci) ...[
                    _buildTrainingSection(l10n),
                    const SizedBox(height: 16),
                  ],
                  DropdownButtonFormField<String>(
                    initialValue: _crewCategory,
                    decoration: InputDecoration(
                      labelText: l10n.t('crew.type'),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'pilot',
                        child: Text(l10n.t('crew.pilot')),
                      ),
                      DropdownMenuItem(
                        value: 'mechanic',
                        child: Text(l10n.t('crew.mechanic')),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _crewCategory = v ?? 'pilot';
                        _grade = '';
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _assignmentType,
                    decoration: InputDecoration(
                      labelText: l10n.t('crew.assignmentType'),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'nato',
                        child: Text(l10n.t('crew.nato')),
                      ),
                      DropdownMenuItem(
                        value: 'foraneo',
                        child: Text(l10n.t('crew.foraneo')),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _assignmentType = v ?? 'nato'),
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey('grade_$_crewCategory'),
                    initialValue: _filteredGrades.any((g) => g.code == _grade)
                        ? _grade
                        : null,
                    decoration: InputDecoration(
                      labelText: l10n.t('crew.grade'),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final g in _filteredGrades)
                        DropdownMenuItem(value: g.code, child: Text(g.code)),
                    ],
                    onChanged: (v) => setState(() => _grade = v ?? ''),
                    validator: (v) => (v == null || v.isEmpty)
                        ? l10n.t('validation.required')
                        : null,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _firstNameController,
                    decoration: InputDecoration(
                      labelText: l10n.t('crew.firstName'),
                      border: const OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.t('validation.required')
                        : null,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _lastNameController,
                    decoration: InputDecoration(
                      labelText: l10n.t('crew.lastName'),
                      border: const OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.t('validation.required')
                        : null,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _nsaController,
                    decoration: InputDecoration(
                      labelText: l10n.t('crew.nsa'),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return l10n.t('validation.required');
                      if (value.length < 3) return l10n.t('crew.nsaMinLength');
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _callsignController,
                    decoration: InputDecoration(
                      labelText: t('crew.indicative'),
                      hintText: t('crew.optional'),
                      border: const OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 20,
                  ),
                  SizedBox(height: 16),
                  InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: l10n.t('crew.appointmentDate'),
                        border: const OutlineInputBorder(),
                        suffixIcon: const Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(
                        '${_appointmentDate.day.toString().padLeft(2, '0')}/${_appointmentDate.month.toString().padLeft(2, '0')}/${_appointmentDate.year}',
                      ),
                    ),
                  ),
                  if (_crewCategory == 'pilot') ...[
                    SizedBox(height: 20),
                    Text(
                      l10n.t('crew.qualifications'),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final q in CrewMember.validQualifications)
                          FilterChip(
                            label: Text(q),
                            selected: _qualifications.contains(q),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _qualifications = [..._qualifications, q];
                                } else {
                                  _qualifications = _qualifications
                                      .where((e) => e != q)
                                      .toList();
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.t('common.cancel')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEditing ? l10n.t('common.save') : l10n.t('crew.add')),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _appointmentDate,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _appointmentDate = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      CrewFormResult(
        unitId: _unitId,
        grade: _grade,
        firstName: _firstNameController.text.trim().toUpperCase(),
        lastName: _lastNameController.text.trim().toUpperCase(),
        nsa: _nsaController.text.trim(),
        callsign: _callsignController.text.trim().toUpperCase().isEmpty
            ? null
            : _callsignController.text.trim().toUpperCase(),
        crewCategory: _crewCategory,
        appointmentDate: _appointmentDate,
        assignmentType: _assignmentType,
        qualifications: _qualifications,
        squadronId: _showSquadron ? _squadronId : null,
        trainingStart: _isEdaci ? _trainingStart : null,
        trainingEnd: _isEdaci ? _trainingEnd : null,
        courseGroup: _isEdaci ? _courseGroupCtrl.text.trim() : null,
      ),
    );
  }
}
