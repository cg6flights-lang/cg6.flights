import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/features/aircraft/domain/aircraft.dart';
import 'package:cg6_flights/features/units/domain/unit_option.dart';
import 'package:flutter/material.dart';

class AircraftFormResult {
  const AircraftFormResult({
    required this.unitId,
    required this.tailNumber,
    required this.model,
    required this.manufacturer,
    required this.status,
    this.serialNumber,
    this.year,
    this.inoperativeReason,
    this.obTailNumber,
    this.displayRegistration = 'FAP',
    this.squadronId,
    this.squadronIds = const [],
  });

  final String unitId;
  final String tailNumber;
  final String model;
  final String manufacturer;
  final String? serialNumber;
  final int? year;
  final String status;
  final String? inoperativeReason;
  final String? obTailNumber;
  final String displayRegistration;
  final String? squadronId;
  final List<String> squadronIds;
}

class AircraftFormDialog extends StatefulWidget {
  const AircraftFormDialog({
    super.key,
    this.aircraft,
    required this.units,
    this.defaultUnitId,
    this.squadrons = const [],
    this.manufacturers = const [],
    this.models = const [],
  });

  final Aircraft? aircraft;
  final List<UnitOption> units;
  final String? defaultUnitId;
  final List<dynamic> squadrons; // FlightSquadron list
  final List<String> manufacturers;
  final List<String> models;

  @override
  State<AircraftFormDialog> createState() => _AircraftFormDialogState();
}

class _AircraftFormDialogState extends State<AircraftFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _unitId;
  late final TextEditingController _tailController;
  late final TextEditingController _modelController;
  late final TextEditingController _manufacturerController;
  late final TextEditingController _serialController;
  late final TextEditingController _yearController;
  late final TextEditingController _inoperativeReasonController;
  late final TextEditingController _obController;
  late String _status;
  bool _hasOb = false;
  late String _displayReg; // 'FAP' or 'OB'
  String? _squadronId;
  final Set<String> _squadronIds = {};

  static const _edaciCode = 'EDACI';
  static const _gru51Id = '4317c6f3-e530-4b9c-a898-1f765ceaafb2';

  bool get _isEditing => widget.aircraft != null;
  bool get _isEdaci => _unitId.isNotEmpty
      ? widget.units.any((u) => u.id == _unitId && u.code == _edaciCode)
      : false;
  bool get _isGru51 => _unitId == _gru51Id;

  @override
  void initState() {
    super.initState();
    final a = widget.aircraft;
    _unitId =
        a?.unitId ??
        widget.defaultUnitId ??
        (widget.units.length == 1 ? widget.units.single.id : '');
    _tailController = TextEditingController(text: a?.tailNumber ?? '');
    _modelController = TextEditingController(text: a?.model ?? '');
    _manufacturerController = TextEditingController(
      text: a?.manufacturer ?? '',
    );
    _serialController = TextEditingController(text: a?.serialNumber ?? '');
    _yearController = TextEditingController(
      text: a != null && a.year != null ? a.year.toString() : '',
    );
    _inoperativeReasonController = TextEditingController(
      text: a?.inoperativeReason ?? '',
    );
    _obController = TextEditingController(text: a?.obTailNumber ?? '');
    _hasOb = a?.obTailNumber != null && a!.obTailNumber!.isNotEmpty;
    _displayReg = a?.displayRegistration == 'OB' ? 'OB' : 'FAP';
    _squadronId = a?.squadronId;
    if (a?.squadronIds.isNotEmpty == true) _squadronIds.addAll(a!.squadronIds);
    _status = a?.status ?? 'operational';
  }

  @override
  void dispose() {
    _tailController.dispose();
    _modelController.dispose();
    _manufacturerController.dispose();
    _serialController.dispose();
    _yearController.dispose();
    _inoperativeReasonController.dispose();
    _obController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isGlobal = widget.units.length > 1;
    final viewport = MediaQuery.sizeOf(context);
    final dialogWidth = (viewport.width - 80).clamp(240.0, 440.0).toDouble();
    final dialogMaxHeight = (viewport.height * 0.76)
        .clamp(320.0, 680.0)
        .toDouble();

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(
        _isEditing ? l10n.t('aircraft.edit') : l10n.t('aircraft.add'),
      ),
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
                  if (_isGru51 && widget.squadrons.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        l10n.t('aircraft.squadron'),
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final s in widget.squadrons)
                          FilterChip(
                            label: Text(
                              s.name,
                              style: const TextStyle(fontSize: 11),
                            ),
                            selected: _squadronIds.contains(s.id),
                            selectedColor: Theme.of(
                              context,
                            ).colorScheme.tertiary.withValues(alpha: 0.18),
                            checkmarkColor: Theme.of(
                              context,
                            ).colorScheme.tertiary,
                            side: BorderSide.none,
                            onSelected: (v) => setState(() {
                              if (v) {
                                _squadronIds.add(s.id);
                              } else {
                                _squadronIds.remove(s.id);
                              }
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _tailController,
                    decoration: InputDecoration(
                      labelText: l10n.t('aircraft.tailNumber'),
                      border: const OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.t('validation.required')
                        : null,
                  ),
                  // ── OB Registration section (only for EDACI) ──
                  if (_isEdaci) ...[
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: Text(l10n.t('aircraft.hasObRegistration')),
                      value: _hasOb,
                      onChanged: (v) => setState(() {
                        _hasOb = v;
                        if (!v) {
                          _obController.clear();
                          _displayReg = 'FAP';
                        }
                      }),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_hasOb) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _obController,
                        decoration: InputDecoration(
                          labelText: l10n.t('aircraft.obTailNumber'),
                          border: const OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? l10n.t('validation.required')
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.t('aircraft.displayRegistration'),
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      RadioGroup<String>(
                        groupValue: _displayReg,
                        onChanged: (v) =>
                            setState(() => _displayReg = v ?? 'FAP'),
                        child: Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                title: Text(l10n.t('aircraft.registrationFAP')),
                                value: 'FAP',
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                title: Text(l10n.t('aircraft.registrationOB')),
                                value: 'OB',
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ],
                  const SizedBox(height: 16),
                  Autocomplete<String>(
                    initialValue: _manufacturerController.text.isNotEmpty
                        ? TextEditingValue(text: _manufacturerController.text)
                        : null,
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return widget.manufacturers;
                      }
                      return widget.manufacturers.where(
                        (m) => m.toLowerCase().contains(
                          textEditingValue.text.toLowerCase(),
                        ),
                      );
                    },
                    onSelected: (v) => _manufacturerController.text = v,
                    fieldViewBuilder:
                        (context, controller, focusNode, onSubmit) =>
                            TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: l10n.t('aircraft.manufacturer'),
                                border: const OutlineInputBorder(),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? l10n.t('validation.required')
                                  : null,
                            ),
                  ),
                  const SizedBox(height: 16),
                  Autocomplete<String>(
                    initialValue: _modelController.text.isNotEmpty
                        ? TextEditingValue(text: _modelController.text)
                        : null,
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) return widget.models;
                      return widget.models.where(
                        (m) => m.toLowerCase().contains(
                          textEditingValue.text.toLowerCase(),
                        ),
                      );
                    },
                    onSelected: (v) => _modelController.text = v,
                    fieldViewBuilder:
                        (context, controller, focusNode, onSubmit) =>
                            TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: l10n.t('aircraft.model'),
                                border: const OutlineInputBorder(),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? l10n.t('validation.required')
                                  : null,
                            ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _serialController,
                          decoration: InputDecoration(
                            labelText: l10n.t('aircraft.serialNumber'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 120,
                        child: TextFormField(
                          controller: _yearController,
                          decoration: InputDecoration(
                            labelText: l10n.t('aircraft.year'),
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty) return null;
                            final year = int.tryParse(value);
                            if (year == null || year < 1900 || year > 2100) {
                              return l10n.t('validation.invalidYear');
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: InputDecoration(
                      labelText: l10n.t('aircraft.status'),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'operational',
                        child: Text(l10n.t('aircraft.operational')),
                      ),
                      DropdownMenuItem(
                        value: 'inoperative',
                        child: Text(l10n.t('aircraft.inoperative')),
                      ),
                      DropdownMenuItem(
                        value: 'maintenance',
                        child: Text(l10n.t('aircraft.maintenance')),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _status = v ?? 'operational'),
                  ),
                  if (_status == 'inoperative') ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _inoperativeReasonController,
                      decoration: InputDecoration(
                        labelText: l10n.t('aircraft.inoperativeReason'),
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? l10n.t('validation.required')
                          : null,
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
          child: Text(
            _isEditing ? l10n.t('common.save') : l10n.t('aircraft.add'),
          ),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      AircraftFormResult(
        unitId: _unitId,
        tailNumber: _tailController.text.trim().toUpperCase(),
        model: _modelController.text.trim(),
        manufacturer: _manufacturerController.text.trim(),
        serialNumber: _serialController.text.trim().isEmpty
            ? null
            : _serialController.text.trim(),
        year: int.tryParse(_yearController.text.trim()),
        status: _status,
        inoperativeReason: _inoperativeReasonController.text.trim().isEmpty
            ? null
            : _inoperativeReasonController.text.trim(),
        obTailNumber: _hasOb && _isEdaci
            ? _obController.text.trim().toUpperCase()
            : null,
        displayRegistration: _isEdaci ? _displayReg : 'FAP',
        squadronId: _isGru51 ? _squadronId : null,
        squadronIds: _isGru51 ? _squadronIds.toList() : [],
      ),
    );
  }
}
