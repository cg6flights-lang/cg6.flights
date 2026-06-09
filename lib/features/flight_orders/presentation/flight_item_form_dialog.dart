import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/flight_orders/data/flight_orders_repository.dart';
import 'package:cg6_flights/features/flight_orders/domain/flight_order.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _fuelFactors = {
  'Jet A1': 6.7,
  '100LL': 6.0,
  'JP-8': 6.7,
  'JP-5': 6.8,
  'MOGAS': 6.0,
};

class _RouteSegmentData {
  _RouteSegmentData({int order = 1})
    : segmentOrder = order,
      segmentType = 'outbound',
      originIsAirport = true,
      destIsAirport = true,
      originRouteIdCtrl = TextEditingController(),
      originLabelCtrl = TextEditingController(),
      originLatCtrl = TextEditingController(),
      originLngCtrl = TextEditingController(),
      destRouteIdCtrl = TextEditingController(),
      destLabelCtrl = TextEditingController(),
      destLatCtrl = TextEditingController(),
      destLngCtrl = TextEditingController();

  int segmentOrder;
  String segmentType;
  bool originIsAirport;
  bool destIsAirport;
  bool _isLocal = false;
  String originAltType = 'zone';
  String destAltType = 'zone';
  final TextEditingController originRouteIdCtrl;
  final TextEditingController originLabelCtrl;
  final TextEditingController originLatCtrl;
  final TextEditingController originLngCtrl;
  final TextEditingController destRouteIdCtrl;
  final TextEditingController destLabelCtrl;
  final TextEditingController destLatCtrl;
  final TextEditingController destLngCtrl;

  factory _RouteSegmentData.local() {
    final data = _RouteSegmentData(order: 1);
    data.segmentType = 'local';
    data._isLocal = true;
    return data;
  }

  Map<String, dynamic> toPayload() {
    final m = <String, dynamic>{
      'segment_order': segmentOrder,
      'segment_type': _isLocal ? 'local' : segmentType,
    };

    if (_isLocal) {
      m['origin_type'] = 'airport';
      m['destination_type'] = 'airport';
      if (originRouteIdCtrl.text.isNotEmpty) {
        m['origin_route_id'] = originRouteIdCtrl.text;
        m['destination_route_id'] = originRouteIdCtrl.text;
      }
      if (originLabelCtrl.text.isNotEmpty) {
        m['origin_label'] = originLabelCtrl.text;
      }
      return m;
    }

    if (originIsAirport) {
      m['origin_type'] = 'airport';
      if (originRouteIdCtrl.text.isNotEmpty) {
        m['origin_route_id'] = originRouteIdCtrl.text;
      }
    } else {
      m['origin_type'] = originAltType;
      m['origin_label'] = originLabelCtrl.text;
      if (originAltType == 'waypoint') {
        m['origin_lat'] = double.tryParse(originLatCtrl.text);
        m['origin_lng'] = double.tryParse(originLngCtrl.text);
      }
    }

    if (destIsAirport) {
      m['destination_type'] = 'airport';
      if (destRouteIdCtrl.text.isNotEmpty) {
        m['destination_route_id'] = destRouteIdCtrl.text;
      }
    } else {
      m['destination_type'] = destAltType;
      m['destination_label'] = destLabelCtrl.text;
      if (destAltType == 'waypoint') {
        m['destination_lat'] = double.tryParse(destLatCtrl.text);
        m['destination_lng'] = double.tryParse(destLngCtrl.text);
      }
    }

    return m;
  }

  void dispose() {
    originRouteIdCtrl.dispose();
    originLabelCtrl.dispose();
    originLatCtrl.dispose();
    originLngCtrl.dispose();
    destRouteIdCtrl.dispose();
    destLabelCtrl.dispose();
    destLatCtrl.dispose();
    destLngCtrl.dispose();
  }
}

class FlightItemFormDialog extends ConsumerStatefulWidget {
  const FlightItemFormDialog({
    super.key,
    required this.flightOrderId,
    required this.unitId,
    required this.operationDate,
    this.existingItem,
    this.itemId,
  });

  final String flightOrderId;
  final String unitId;
  final DateTime operationDate;
  final FlightOrderItem? existingItem;
  final String? itemId;

  bool get isEditing => existingItem != null;

  @override
  ConsumerState<FlightItemFormDialog> createState() =>
      _FlightItemFormDialogState();
}

class _FlightItemFormDialogState extends ConsumerState<FlightItemFormDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  int _currentStep = 0;

  static const _stepLabels = ['Vuelo', 'Combustible y Ruta'];

  String? _aircraftId;
  String? _aircraftError;
  final _missionCtrl = TextEditingController();
  TimeOfDay? _departureTime;

  final _flMinCtrl = TextEditingController();
  final _flMaxCtrl = TextEditingController();

  String? _shift;
  int _eteMinutes = 0;

  String _fuelType = 'Jet A1';
  final _fuelLbsCtrl = TextEditingController();
  final _fuelGalCtrl = TextEditingController();
  bool _fuelLastEditedLbs = true;

  final _segments = <_RouteSegmentData>[_RouteSegmentData(order: 1)];
  bool _isLocal = false;

  String? _pcId;
  String? _cpId;
  String? _maId;
  bool _hasMechanic = false;

  List<String> _missionOptions = [];
  bool _missionsLoaded = false;

  List<dynamic> _aircraftList = [];
  bool _aircraftLoaded = false;
  List<dynamic> _crewMembers = [];
  bool _crewLoaded = false;
  List<dynamic> _routesList = [];
  bool _routesLoaded = false;
  static const _functionCodes = [
    {'code': 'PS', 'label': 'PS - Piloto de Seguridad'},
    {'code': 'IP', 'label': 'IP - Piloto Instructor'},
    {'code': 'PM', 'label': 'PM - Piloto al Mando'},
    {'code': 'CP', 'label': 'CP - Copiloto'},
    {'code': 'CO', 'label': 'CO - Comprobación Operativa'},
    {'code': 'PI', 'label': 'PI - Piloto de Ida'},
    {'code': 'PR', 'label': 'PR - Piloto de Retorno'},
  ];

  String? _pcFunctionCode;
  String? _cpFunctionCode;

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;
    if (item != null) {
      _aircraftId = item.aircraftId;
      _missionCtrl.text = item.mission ?? '';
      if (item.scheduledDeparture != null) {
        _departureTime = TimeOfDay(
          hour: item.scheduledDeparture!.hour,
          minute: item.scheduledDeparture!.minute,
        );
      }
      _flMinCtrl.text = item.flightLevelMin?.toString() ?? '';
      _flMaxCtrl.text = item.flightLevelMax?.toString() ?? '';
      _shift = item.shift;
      _eteMinutes = item.eteMinutes ?? 0;
      _fuelType = item.fuelType ?? 'Jet A1';
      _fuelLbsCtrl.text = item.fuelAmount?.toString() ?? '';
      _recalcFuel(fromLbs: true);
      // Pre-fill segments from routes
      if (item.routes.isNotEmpty) {
        _segments.clear();
        // Detect if this is a local flight
        final isLocal = item.routes.any((r) => r.segmentType == 'local');
        if (isLocal) _isLocal = true;
        for (final r in item.routes) {
          final seg = isLocal
              ? _RouteSegmentData.local()
              : _RouteSegmentData(order: r.segmentOrder);
          if (!isLocal) seg.segmentType = r.segmentType;
          if (r.originType == 'airport') {
            seg.originIsAirport = true;
            seg.originRouteIdCtrl.text = r.originRouteId ?? '';
          } else {
            seg.originIsAirport = false;
            seg.originAltType = r.originType;
            seg.originLabelCtrl.text = r.originLabel ?? '';
            if (r.originLat != null) {
              seg.originLatCtrl.text = r.originLat.toString();
            }
            if (r.originLng != null) {
              seg.originLngCtrl.text = r.originLng.toString();
            }
          }
          if (r.destinationType == 'airport') {
            seg.destIsAirport = true;
            seg.destRouteIdCtrl.text = r.destinationRouteId ?? '';
          } else {
            seg.destIsAirport = false;
            seg.destAltType = r.destinationType;
            seg.destLabelCtrl.text = r.destinationLabel ?? '';
            if (r.destinationLat != null) {
              seg.destLatCtrl.text = r.destinationLat.toString();
            }
            if (r.destinationLng != null) {
              seg.destLngCtrl.text = r.destinationLng.toString();
            }
          }
          _segments.add(seg);
        }
      }
      // Pre-fill crew
      for (final c in item.crew) {
        if (c.roleCode == 'PC') {
          _pcId = c.crewMemberId;
          _pcFunctionCode = c.functionCode;
        } else if (c.roleCode == 'CP') {
          _cpId = c.crewMemberId;
          _cpFunctionCode = c.functionCode;
        } else if (c.roleCode == 'MA') {
          _maId = c.crewMemberId;
          _hasMechanic = true;
        }
      }
    }
    _loadMissionOptions();
    _loadAircraft();
    _loadCrewMembers();
    _loadRoutes();
  }

  @override
  void dispose() {
    _missionCtrl.dispose();
    _flMinCtrl.dispose();
    _flMaxCtrl.dispose();
    _fuelLbsCtrl.dispose();
    _fuelGalCtrl.dispose();
    for (final s in _segments) {
      s.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMissionOptions() async {
    try {
      final rows = await Supabase.instance.client
          .from('flight_order_items')
          .select('mission, flight_order:flight_order_id!inner(unit_id)')
          .eq('flight_order.unit_id', widget.unitId)
          .not('mission', 'is', null)
          .neq('mission', '')
          .order('created_at', ascending: false)
          .limit(30);
      final seen = <String>{};
      final missions = <String>[];
      for (final r in (rows as List<dynamic>)) {
        final m = r['mission']?.toString().trim();
        if (m != null && m.isNotEmpty && seen.add(m.toLowerCase())) {
          missions.add(m);
        }
      }
      if (mounted) {
        setState(() {
          _missionOptions = missions;
          _missionsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _missionsLoaded = true);
    }
  }

  Future<void> _loadAircraft() async {
    try {
      final rows = await Supabase.instance.client
          .from('aircraft')
          .select('id,tail_number,model')
          .eq('unit_id', widget.unitId)
          .eq('active', true)
          .order('tail_number');
      if (mounted) {
        setState(() {
          _aircraftList = rows as List<dynamic>;
          _aircraftLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _aircraftLoaded = true);
    }
  }

  Future<void> _loadCrewMembers() async {
    try {
      final rows = await Supabase.instance.client
          .from('crew_members')
          .select('id,grade,first_name,last_name,callsign,crew_category')
          .eq('unit_id', widget.unitId)
          .eq('active', true)
          .order('last_name');
      if (mounted) {
        setState(() {
          _crewMembers = rows as List<dynamic>;
          _crewLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _crewLoaded = true);
    }
  }

  Future<void> _loadRoutes() async {
    try {
      final rows = await Supabase.instance.client
          .from('routes')
          .select('id,airport_name,icao_code')
          .order('airport_name');
      if (mounted) {
        setState(() {
          _routesList = rows as List<dynamic>;
          _routesLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _routesLoaded = true);
    }
  }

  bool _canAdvance() {
    switch (_currentStep) {
      case 0:
        return _aircraftId != null &&
            _departureTime != null &&
            _flMinCtrl.text.trim().isNotEmpty;
      case 1:
        return _fuelLbsCtrl.text.trim().isNotEmpty;
      case 2:
        return true;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final viewport = MediaQuery.sizeOf(context);
    final dialogWidth = (viewport.width - 80).clamp(240.0, 680.0).toDouble();
    final dialogMaxHeight = (viewport.height * 0.78)
        .clamp(360.0, 760.0)
        .toDouble();

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(
        widget.isEditing
            ? l10n.t('flightOrders.editItem')
            : l10n.t('flightOrders.addItem'),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 680, maxHeight: dialogMaxHeight),
        child: SizedBox(
          width: dialogWidth,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStepHeader(),
                const SizedBox(height: 20),
                Flexible(
                  child: SingleChildScrollView(child: _buildStepContent(l10n)),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (_currentStep > 0)
          TextButton(
            onPressed: () => setState(() => _currentStep--),
            child: Text(l10n.t('common.back')),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.t('common.cancel')),
        ),
        if (_currentStep < 1)
          FilledButton(
            onPressed: _canAdvance()
                ? () => setState(() => _currentStep++)
                : null,
            child: Text(l10n.t('common.next')),
          )
        else
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.t('flightOrders.addItem')),
          ),
      ],
    );
  }

  Widget _buildStepHeader() {
    return Row(
      children: [
        for (int i = 0; i < 3; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: i <= _currentStep
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade300,
              ),
            ),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < _currentStep
                  ? Theme.of(context).colorScheme.primary
                  : i == _currentStep
                  ? Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.15)
                  : Colors.grey.shade100,
              border: Border.all(
                color: i <= _currentStep
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade300,
                width: i == _currentStep ? 2 : 1,
              ),
            ),
            child: Center(
              child: i < _currentStep
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: i == _currentStep
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _stepLabels[i],
            style: TextStyle(
              fontSize: 12,
              fontWeight: i == _currentStep
                  ? FontWeight.w600
                  : FontWeight.normal,
              color: i <= _currentStep
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _buildStepContent(AppLocalizations l10n) {
    switch (_currentStep) {
      case 0:
        return _buildStep1(l10n);
      case 1:
        return _buildStep2(l10n);
      case 2:
        return _buildStep2(l10n);
      default:
        return const SizedBox.shrink();
    }
  }

  // Step 1: Aircraft + Mission + Departure + Flight Level + ETE
  Widget _buildStep1(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAircraftSection(l10n),
        const SizedBox(height: 12),
        _buildShiftDropdown(l10n),
        const SizedBox(height: 16),
        _buildMissionSection(l10n),
        const SizedBox(height: 16),
        _buildDepartureSection(l10n),
        const SizedBox(height: 16),
        _buildFlightDataSection(l10n),
      ],
    );
  }

  // Step 2: Fuel + Routes + Crew
  Widget _buildStep2(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFuelSection(l10n),
        const SizedBox(height: 20),
        _buildRoutesSection(l10n),
        const SizedBox(height: 20),
        _buildCrewSection(l10n),
      ],
    );
  }

  // Step 3: Crew + Profiles
  Widget _buildShiftDropdown(AppLocalizations l10n) {
    return DropdownButtonFormField<String>(
      initialValue: _shift,
      decoration: const InputDecoration(labelText: 'Turno', border: OutlineInputBorder()),
      isExpanded: true,
      items: const [
        DropdownMenuItem(value: null, child: Text('Sin turno')),
        DropdownMenuItem(value: 'I', child: Text('TURNO I')),
        DropdownMenuItem(value: 'II', child: Text('TURNO II')),
        DropdownMenuItem(value: 'III', child: Text('TURNO III')),
        DropdownMenuItem(value: 'IV', child: Text('TURNO IV')),
      ],
      onChanged: (v) => setState(() => _shift = v),
    );
  }

  Widget _buildAircraftSection(AppLocalizations l10n) {
    if (!_aircraftLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    return InputDecorator(
      decoration: InputDecoration(
        labelText: l10n.t('flightOrders.aircraft'),
        border: const OutlineInputBorder(),
        errorText: _aircraftError,
      ),
      child: DropdownButton<String>(
        value: _aircraftId,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        hint: Text(l10n.t('flightOrders.selectAircraft')),
        items: [
          for (final a in _aircraftList)
            DropdownMenuItem(
              value: a['id'].toString(),
              child: Text(
                '${a['tail_number']}${a['model'] != null ? ' — ${a['model']}' : ''}',
              ),
            ),
        ],
        onChanged: (v) => setState(() {
          _aircraftId = v;
          _aircraftError = null;
        }),
      ),
    );
  }

  Widget _buildMissionSection(AppLocalizations l10n) {
    return _missionsLoaded && _missionOptions.isNotEmpty
        ? Autocomplete<String>(
            optionsBuilder: (value) {
              if (value.text.isEmpty) return _missionOptions;
              final lower = value.text.toLowerCase();
              return _missionOptions.where(
                (m) => m.toLowerCase().contains(lower),
              );
            },
            onSelected: (v) => _missionCtrl.text = v,
            fieldViewBuilder: (context, ctrl, node, onSubmit) {
              return TextFormField(
                controller: ctrl,
                focusNode: node,
                decoration: InputDecoration(
                  labelText: l10n.t('flightOrders.mission'),
                  border: const OutlineInputBorder(),
                ),
              );
            },
          )
        : TextFormField(
            controller: _missionCtrl,
            decoration: InputDecoration(
              labelText: l10n.t('flightOrders.mission'),
              border: const OutlineInputBorder(),
            ),
          );
  }

  Widget _buildDepartureSection(AppLocalizations l10n) {
    return OutlinedButton.icon(
      onPressed: _pickTime,
      icon: const Icon(Icons.schedule, size: 16),
      label: Text(
        _departureTime != null
            ? '${l10n.t('flightOrders.departure')}: ${_formatTime(_departureTime!)}'
            : l10n.t('flightOrders.departure'),
      ),
    );
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _departureTime ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (time != null) setState(() => _departureTime = time);
  }

  String _formatTime(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildFlightDataSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.t('flightOrders.flightLevel'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _flMinCtrl,
                decoration: const InputDecoration(
                  labelText: 'Min. (fts) *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.t('validation.required')
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _flMaxCtrl,
                decoration: const InputDecoration(
                  labelText: 'Max. (fts)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildEteSection(l10n),
      ],
    );
  }

  Widget _buildEteSection(AppLocalizations l10n) {
    final h = _eteMinutes ~/ 60;
    final m = _eteMinutes % 60;
    return Row(
      children: [
        Text(
          '${l10n.t('flightOrders.ete')}:',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 28),
          visualDensity: VisualDensity.compact,
          onPressed: _eteMinutes > 0
              ? () => setState(() {
                  _eteMinutes = (_eteMinutes - 5).clamp(0, 99999);
                })
              : null,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 28),
          visualDensity: VisualDensity.compact,
          onPressed: () => setState(() => _eteMinutes += 5),
        ),
      ],
    );
  }

  Widget _buildFuelSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.t('flightOrders.fuel'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _fuelType,
          decoration: const InputDecoration(
            labelText: 'Tipo de combustible',
            border: OutlineInputBorder(),
          ),
          items: _fuelFactors.keys.map((t) {
            return DropdownMenuItem(value: t, child: Text(t));
          }).toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() => _fuelType = v);
            _recalcFuel(fromLbs: _fuelLastEditedLbs);
          },
          validator: (v) =>
              (v == null || v.isEmpty) ? l10n.t('validation.required') : null,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _fuelLbsCtrl,
                decoration: const InputDecoration(
                  labelText: 'lbs',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                onChanged: (_) {
                  _fuelLastEditedLbs = true;
                  _recalcFuel(fromLbs: true);
                },
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.t('validation.required')
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _fuelGalCtrl,
                decoration: const InputDecoration(
                  labelText: 'gal',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                onChanged: (_) {
                  _fuelLastEditedLbs = false;
                  _recalcFuel(fromLbs: false);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _recalcFuel({required bool fromLbs}) {
    final factor = _fuelFactors[_fuelType] ?? 6.7;
    if (fromLbs) {
      final lbs = double.tryParse(_fuelLbsCtrl.text);
      if (lbs != null && lbs > 0) {
        final gal = (lbs / factor).toStringAsFixed(1);
        if (_fuelGalCtrl.text != gal) {
          _fuelGalCtrl.text = gal;
        }
      }
    } else {
      final gal = double.tryParse(_fuelGalCtrl.text);
      if (gal != null && gal > 0) {
        final lbs = (gal * factor).toStringAsFixed(1);
        if (_fuelLbsCtrl.text != lbs) {
          _fuelLbsCtrl.text = lbs;
        }
      }
    }
  }

  Widget _buildRoutesSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.t('flightOrders.routes'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        CheckboxListTile(
          title: const Text('Vuelo Local'),
          subtitle: const Text('Despegue y aterrizaje en el mismo aeropuerto'),
          value: _isLocal,
          dense: true,
          contentPadding: EdgeInsets.zero,
          onChanged: (v) => setState(() {
            _isLocal = v ?? false;
            _segments.clear();
            if (_isLocal) {
              _segments.add(_RouteSegmentData.local());
            } else {
              _segments.add(_RouteSegmentData(order: 1));
            }
          }),
        ),
        if (_isLocal) ...[
          const SizedBox(height: 4),
          _buildLocalSegment(l10n),
        ] else ...[
          const SizedBox(height: 8),
          for (var i = 0; i < _segments.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _buildSegmentCard(l10n, i),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() {
              _segments.add(_RouteSegmentData(order: _segments.length + 1));
            }),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.t('flightOrders.addRoute')),
          ),
        ],
      ],
    );
  }

  Widget _buildLocalSegment(AppLocalizations l10n) {
    final seg = _segments.first;
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Airport selector (required)
            Text(
              l10n.t('flightOrders.airport'),
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: 4),
            _routesLoaded
                ? InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Aeropuerto',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: seg.originRouteIdCtrl.text.isEmpty
                            ? null
                            : seg.originRouteIdCtrl.text,
                        isExpanded: true,
                        isDense: true,
                        hint: const Text(
                          'Seleccionar aeropuerto',
                          style: TextStyle(fontSize: 13),
                        ),
                        items: [
                          for (final r in _routesList)
                            DropdownMenuItem<String>(
                              value: r['id'].toString(),
                              child: Text(
                                '${r['icao_code'] != null ? '${r['icao_code']} - ' : ''}${r['airport_name']}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                        ],
                        onChanged: (v) {
                          setState(() => seg.originRouteIdCtrl.text = v ?? '');
                        },
                      ),
                    ),
                  )
                : const SizedBox(
                    height: 48,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
            const SizedBox(height: 12),
            // Zone selector (optional)
            Text(
              'Zona de trabajo (opcional)',
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: 4),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Zona de trabajo (opcional)',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: seg.originLabelCtrl.text.isEmpty
                      ? null
                      : seg.originLabelCtrl.text,
                  isExpanded: true,
                  isDense: true,
                  hint: const Text(
                    'Ninguna (solo aeropuerto)',
                    style: TextStyle(fontSize: 13),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Ninguna', style: TextStyle(fontSize: 13)),
                    ),
                    const DropdownMenuItem<String>(
                      value: 'Zona 1',
                      child: Text('Zona 1', style: TextStyle(fontSize: 13)),
                    ),
                    const DropdownMenuItem<String>(
                      value: 'Zona 2',
                      child: Text('Zona 2', style: TextStyle(fontSize: 13)),
                    ),
                    const DropdownMenuItem<String>(
                      value: 'Zona 3',
                      child: Text('Zona 3', style: TextStyle(fontSize: 13)),
                    ),
                    const DropdownMenuItem<String>(
                      value: 'Zona 4',
                      child: Text('Zona 4', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => seg.originLabelCtrl.text = v ?? '');
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentCard(AppLocalizations l10n, int index) {
    final seg = _segments[index];
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Segmento ${index + 1}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const Spacer(),
                if (_segments.length > 1)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() {
                        seg.dispose();
                        _segments.removeAt(index);
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: seg.segmentType,
              decoration: InputDecoration(
                labelText: l10n.t('flightOrders.segmentType'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                DropdownMenuItem(
                  value: 'outbound',
                  child: Text(l10n.t('flightOrders.outbound')),
                ),
                DropdownMenuItem(
                  value: 'return',
                  child: Text(l10n.t('flightOrders.return')),
                ),
              ],
              onChanged: (v) =>
                  setState(() => seg.segmentType = v ?? 'outbound'),
            ),
            const SizedBox(height: 12),
            _buildAirportRow(l10n, seg, isOrigin: true),
            const SizedBox(height: 12),
            _buildAirportRow(l10n, seg, isOrigin: false),
          ],
        ),
      ),
    );
  }

  Widget _buildAirportRow(
    AppLocalizations l10n,
    _RouteSegmentData seg, {
    required bool isOrigin,
  }) {
    final useAirport = isOrigin ? seg.originIsAirport : seg.destIsAirport;
    final routeIdCtrl = isOrigin ? seg.originRouteIdCtrl : seg.destRouteIdCtrl;
    final labelCtrl = isOrigin ? seg.originLabelCtrl : seg.destLabelCtrl;
    final latCtrl = isOrigin ? seg.originLatCtrl : seg.destLatCtrl;
    final lngCtrl = isOrigin ? seg.originLngCtrl : seg.destLngCtrl;
    final altType = isOrigin ? seg.originAltType : seg.destAltType;
    final label = isOrigin
        ? '${l10n.t('flightOrders.origin')} 🛫'
        : '${l10n.t('flightOrders.destination')} 🛬';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (useAirport)
          _routesLoaded
              ? DropdownButtonFormField<String>(
                  initialValue: routeIdCtrl.text.isNotEmpty
                      ? routeIdCtrl.text
                      : null,
                  decoration: InputDecoration(
                    labelText: label,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final r in _routesList)
                      DropdownMenuItem(
                        value: r['id'].toString(),
                        child: Text(
                          '${r['airport_name']}${r['icao_code'] != null ? ' (${r['icao_code']})' : ''}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    routeIdCtrl.text = v ?? '';
                    setState(() {});
                  },
                  validator: (v) => (v == null || v.isEmpty)
                      ? l10n.t('validation.required')
                      : null,
                )
              : const Center(child: CircularProgressIndicator())
        else
          _buildAltPointWidget(labelCtrl, latCtrl, lngCtrl, altType, label, (
            type,
          ) {
            if (isOrigin) {
              seg.originAltType = type;
            } else {
              seg.destAltType = type;
            }
            labelCtrl.clear();
            latCtrl.clear();
            lngCtrl.clear();
            setState(() {});
          }),
        const SizedBox(height: 4),
        Row(
          children: [
            TextButton(
              onPressed: useAirport
                  ? null
                  : () {
                      if (isOrigin) {
                        seg.originIsAirport = true;
                      } else {
                        seg.destIsAirport = true;
                      }
                      setState(() {});
                    },
              style: TextButton.styleFrom(
                backgroundColor: useAirport
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                foregroundColor: useAirport
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Aeropuerto', style: TextStyle(fontSize: 11)),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: !useAirport
                  ? null
                  : () {
                      if (isOrigin) {
                        seg.originIsAirport = false;
                        seg.originAltType = 'zone';
                      } else {
                        seg.destIsAirport = false;
                        seg.destAltType = 'zone';
                      }
                      routeIdCtrl.clear();
                      setState(() {});
                    },
              style: TextButton.styleFrom(
                backgroundColor: !useAirport
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                foregroundColor: !useAirport
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Zona / Waypoint',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAltPointWidget(
    TextEditingController labelCtrl,
    TextEditingController latCtrl,
    TextEditingController lngCtrl,
    String altType,
    String label,
    void Function(String) onTypeChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: altType,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          items: const [
            DropdownMenuItem(
              value: 'zone',
              child: Text('Zona', style: TextStyle(fontSize: 13)),
            ),
            DropdownMenuItem(
              value: 'waypoint',
              child: Text('Waypoint', style: TextStyle(fontSize: 13)),
            ),
          ],
          onChanged: (v) {
            if (v != null) onTypeChanged(v);
          },
        ),
        const SizedBox(height: 4),
        if (altType == 'zone')
          DropdownButtonFormField<String>(
            initialValue: labelCtrl.text.isNotEmpty ? labelCtrl.text : null,
            decoration: const InputDecoration(
              labelText: 'Zona de trabajo',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(
                value: 'Zona 1',
                child: Text('Zona 1', style: TextStyle(fontSize: 13)),
              ),
              DropdownMenuItem(
                value: 'Zona 2',
                child: Text('Zona 2', style: TextStyle(fontSize: 13)),
              ),
              DropdownMenuItem(
                value: 'Zona 3',
                child: Text('Zona 3', style: TextStyle(fontSize: 13)),
              ),
              DropdownMenuItem(
                value: 'Zona 4',
                child: Text('Zona 4', style: TextStyle(fontSize: 13)),
              ),
            ],
            onChanged: (v) {
              labelCtrl.text = v ?? '';
              setState(() {});
            },
          ),
        if (altType == 'waypoint')
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Waypoint',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: latCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Lat',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: lngCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Lng',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildCrewSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.t('flightOrders.crew'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        _crewDropdown(
          label: l10n.t('flightOrders.rolePC'),
          category: 'pilot',
          selectedId: _pcId,
          onChanged: (v) => setState(() => _pcId = v),
        ),
        const SizedBox(height: 8),
        _functionDropdown(
          selectedCode: _pcFunctionCode,
          onChanged: (v) => setState(() => _pcFunctionCode = v),
          l10n: l10n,
        ),
        const SizedBox(height: 12),
        _crewDropdown(
          label: l10n.t('flightOrders.roleCP'),
          category: 'pilot',
          selectedId: _cpId,
          onChanged: (v) => setState(() => _cpId = v),
        ),
        const SizedBox(height: 8),
        _functionDropdown(
          selectedCode: _cpFunctionCode,
          onChanged: (v) => setState(() => _cpFunctionCode = v),
          l10n: l10n,
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          title: Text(l10n.t('flightOrders.hasMechanic')),
          value: _hasMechanic,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          onChanged: (v) => setState(() {
            _hasMechanic = v ?? false;
            if (!_hasMechanic) _maId = null;
          }),
        ),
        if (_hasMechanic)
          _crewDropdown(
            label: l10n.t('flightOrders.roleMA'),
            category: 'mechanic',
            selectedId: _maId,
            onChanged: (v) => setState(() => _maId = v),
          ),
      ],
    );
  }

  Widget _functionDropdown({
    required String? selectedCode,
    required void Function(String?) onChanged,
    required AppLocalizations l10n,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: selectedCode,
      decoration: InputDecoration(
        labelText: l10n.t('flightOrders.function'),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        DropdownMenuItem(
          value: null,
          child: Text(
            l10n.t('flightOrders.functionNone'),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        for (final f in _functionCodes)
          DropdownMenuItem(
            value: f['code'],
            child: Text(f['label']!, style: const TextStyle(fontSize: 13)),
          ),
      ],
      onChanged: (v) => onChanged(v),
    );
  }

  Widget _crewDropdown({
    required String label,
    required String category,
    required String? selectedId,
    required void Function(String?) onChanged,
  }) {
    if (!_crewLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    final members = _crewMembers
        .where((m) => m['crew_category']?.toString() == category)
        .toList();
    return DropdownButtonFormField<String>(
      initialValue: selectedId,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final m in members)
          DropdownMenuItem(
            value: m['id'].toString(),
            child: Text(
              '${m['grade']} ${m['first_name']} ${m['last_name']}${m['callsign'] != null ? ' (${m['callsign']})' : ''}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
      ],
      onChanged: (v) => onChanged(v),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    if (_aircraftId == null) {
      setState(
        () => _aircraftError = AppLocalizations.of(
          context,
        ).t('validation.required'),
      );
      return;
    }
    if (_departureTime == null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('La salida programada es obligatoria.')),
        );
      return;
    }

    final opDate = widget.operationDate;
    final departure = DateTime(
      opDate.year,
      opDate.month,
      opDate.day,
      _departureTime!.hour,
      _departureTime!.minute,
    );

    setState(() => _saving = true);

    final item = <String, dynamic>{
      'aircraft_id': _aircraftId,
      'mission': _missionCtrl.text.trim().isEmpty
          ? null
          : _missionCtrl.text.trim(),
      'flight_level_min': int.tryParse(_flMinCtrl.text.trim()),
      'flight_level_max': _flMaxCtrl.text.trim().isNotEmpty
          ? int.tryParse(_flMaxCtrl.text.trim())
          : null,
      'shift': _shift,
      'ete_minutes': _eteMinutes > 0 ? _eteMinutes : null,
      'fuel_type': _fuelType,
      'fuel_amount': double.tryParse(_fuelLbsCtrl.text.trim()),
      'scheduled_departure': departure.toIso8601String(),
      'routes': _segments.map((s) => s.toPayload()).toList(),
      'crew': [
        if (_pcId != null)
          {
            'crew_member_id': _pcId,
            'role_code': 'PC',
            if (_pcFunctionCode != null) 'function_code': _pcFunctionCode,
          },
        if (_cpId != null)
          {
            'crew_member_id': _cpId,
            'role_code': 'CP',
            if (_cpFunctionCode != null) 'function_code': _cpFunctionCode,
          },
        if (_maId != null) {'crew_member_id': _maId, 'role_code': 'MA'},
      ],
    };

    final repo = ref.read(flightOrdersRepositoryProvider);
    final result = widget.isEditing
        ? await repo.updateItem(
            flightOrderId: widget.flightOrderId,
            itemId: widget.itemId!,
            item: item,
          )
        : await repo.addItem(flightOrderId: widget.flightOrderId, item: item);

    if (!mounted) return;
    setState(() => _saving = false);

    switch (result) {
      case AppSuccess<FlightOrderItem>():
        Navigator.of(context).pop(true);
      case AppFailure<FlightOrderItem>(error: final error):
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}
