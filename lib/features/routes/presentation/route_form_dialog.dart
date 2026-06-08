import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/features/routes/data/airports_dataset.dart';
import 'package:cg6_flights/features/routes/data/cities_dataset.dart';
import 'package:cg6_flights/features/routes/data/countries_dataset.dart';
import 'package:cg6_flights/features/routes/domain/route.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RouteFormResult {
  const RouteFormResult({
    required this.airportName,
    required this.category,
    required this.country,
    required this.city,
    this.icaoCode,
    this.iataCode,
    this.latitude,
    this.longitude,
  });

  final String airportName;
  final String category;
  final String? icaoCode;
  final String? iataCode;
  final String country;
  final String city;
  final double? latitude;
  final double? longitude;
}

class RouteFormDialog extends StatefulWidget {
  const RouteFormDialog({super.key, this.route});

  final domain.Route? route;

  @override
  State<RouteFormDialog> createState() => _RouteFormDialogState();
}

class _RouteFormDialogState extends State<RouteFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _icaoController;
  late final TextEditingController _iataController;
  late final TextEditingController _countryController;
  late final TextEditingController _cityController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final FocusNode _nameFocus;
  late final FocusNode _countryFocus;
  late final FocusNode _cityFocus;
  late final FocusNode _icaoFocus;
  late final MapController _mapController;
  late String _category;
  bool _showMap = true;

  bool get _isEditing => widget.route != null;

  final _nameOptions = kAirports.map((a) => a.displayName).toList();

  @override
  void initState() {
    super.initState();
    final r = widget.route;
    _nameController = TextEditingController(text: r?.airportName ?? '');
    _icaoController = TextEditingController(text: r?.icaoCode ?? '');
    _iataController = TextEditingController(text: r?.iataCode ?? '');
    _countryController = TextEditingController(text: r?.country ?? '');
    _cityController = TextEditingController(text: r?.city ?? '');
    _latController = TextEditingController(
      text: r != null && r.latitude != null ? r.latitude.toString() : '',
    );
    _lngController = TextEditingController(
      text: r != null && r.longitude != null ? r.longitude.toString() : '',
    );
    _nameFocus = FocusNode();
    _countryFocus = FocusNode();
    _cityFocus = FocusNode();
    _icaoFocus = FocusNode();
    _mapController = MapController();
    _category = r?.category ?? 'internacional';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _icaoController.dispose();
    _iataController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _nameFocus.dispose();
    _countryFocus.dispose();
    _cityFocus.dispose();
    _icaoFocus.dispose();
    _mapController.dispose();
    super.dispose();
  }

  LatLng? get _currentLatLng {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return LatLng(lat, lng);
  }

  void _setCoordinates(LatLng point) {
    _latController.text = point.latitude.toStringAsFixed(4);
    _lngController.text = point.longitude.toStringAsFixed(4);
  }

  void _selectAirport(String displayName) {
    final airport = kAirports.firstWhere((a) => a.displayName == displayName);
    _nameController.text = airport.name;
    _icaoController.text = airport.icao;
    _iataController.text = airport.iata;
    _countryController.text = airport.country;
    _cityController.text = airport.city;
    _latController.text = airport.lat.toStringAsFixed(4);
    _lngController.text = airport.lng.toStringAsFixed(4);
    if (mounted) {
      _mapController.move(LatLng(airport.lat, airport.lng), 12);
      setState(() {});
    }
  }

  Widget _autocompleteField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required Iterable<String> options,
    required String? Function(String?) validator,
    void Function(String)? onSelected,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int? maxLength,
    TextInputType? keyboardType,
  }) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return const [];
        final query = textEditingValue.text.toLowerCase();
        return options.where((o) => o.toLowerCase().contains(query));
      },
      onSelected: onSelected ?? (_) {},
      fieldViewBuilder: (context, ctrl, focus, onSubmit) {
        return TextFormField(
          controller: ctrl,
          focusNode: focus,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          textCapitalization: textCapitalization,
          maxLength: maxLength,
          keyboardType: keyboardType,
          validator: validator,
          onFieldSubmitted: (_) => onSubmit(),
        );
      },
      optionsViewBuilder: (context, onSelected, opts) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: opts.length,
                itemBuilder: (context, i) {
                  final option = opts.elementAt(i);
                  return ListTile(
                    dense: true,
                    title: Text(option, style: const TextStyle(fontSize: 13)),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final viewport = MediaQuery.sizeOf(context);
    final dialogWidth = (viewport.width - 80).clamp(240.0, 520.0).toDouble();
    final dialogMaxHeight = (viewport.height * 0.76)
        .clamp(320.0, 700.0)
        .toDouble();

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(_isEditing ? l10n.t('routes.edit') : l10n.t('routes.add')),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520, maxHeight: dialogMaxHeight),
        child: SizedBox(
          width: dialogWidth,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _autocompleteField(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    label: l10n.t('routes.airportName'),
                    options: _nameOptions,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.t('validation.required')
                        : null,
                    onSelected: _selectAirport,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _autocompleteField(
                          controller: _countryController,
                          focusNode: _countryFocus,
                          label: l10n.t('routes.country'),
                          options: kCountries,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? l10n.t('validation.required')
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _autocompleteField(
                          controller: _cityController,
                          focusNode: _cityFocus,
                          label: l10n.t('routes.city'),
                          options: kCities,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? l10n.t('validation.required')
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _autocompleteField(
                          controller: _icaoController,
                          focusNode: _icaoFocus,
                          label: l10n.t('routes.icao'),
                          options: kAirports
                              .where((a) => a.icao.isNotEmpty)
                              .map((a) => a.icao),
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 4,
                          validator: (v) {
                            if (v == null || v.isEmpty) return null;
                            if (!RegExp(
                              r'^[A-Z]{4}$',
                            ).hasMatch(v.toUpperCase())) {
                              return 'Debe tener 4 letras';
                            }
                            return null;
                          },
                          onSelected: (icao) {
                            final airport = kAirports.firstWhere(
                              (a) => a.icao == icao,
                            );
                            _nameController.text = airport.name;
                            _iataController.text = airport.iata;
                            _countryController.text = airport.country;
                            _cityController.text = airport.city;
                            _latController.text = airport.lat.toStringAsFixed(
                              4,
                            );
                            _lngController.text = airport.lng.toStringAsFixed(
                              4,
                            );
                            if (mounted) {
                              _mapController.move(
                                LatLng(airport.lat, airport.lng),
                                12,
                              );
                              setState(() {});
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _iataController,
                          decoration: InputDecoration(
                            labelText: l10n.t('routes.iata'),
                            border: const OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 3,
                          validator: (v) {
                            if (v == null || v.isEmpty) return null;
                            if (!RegExp(
                              r'^[A-Z]{3}$',
                            ).hasMatch(v.toUpperCase())) {
                              return 'Debe tener 3 letras';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: InputDecoration(
                      labelText: l10n.t('routes.category'),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'internacional',
                        child: Text(l10n.t('routes.international')),
                      ),
                      DropdownMenuItem(
                        value: 'nacional',
                        child: Text(l10n.t('routes.national')),
                      ),
                      DropdownMenuItem(
                        value: 'aerodromo',
                        child: Text(l10n.t('routes.aerodrome')),
                      ),
                      DropdownMenuItem(
                        value: 'helipuerto',
                        child: Text(l10n.t('routes.heliport')),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _category = v ?? 'internacional'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _latController,
                          decoration: InputDecoration(
                            labelText: l10n.t('routes.latitude'),
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _lngController,
                          decoration: InputDecoration(
                            labelText: l10n.t('routes.longitude'),
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => setState(() => _showMap = !_showMap),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showMap ? Icons.map_outlined : Icons.map_outlined,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n.t('routes.selectOnMap'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showMap) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 250,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          children: [
                            FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter:
                                    _currentLatLng ??
                                    const LatLng(-12.0, -77.0),
                                initialZoom: _currentLatLng != null ? 12 : 5,
                                onTap: (tapPosition, point) {
                                  _setCoordinates(point);
                                  setState(() {});
                                },
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                ),
                                if (_currentLatLng != null)
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: _currentLatLng!,
                                        width: 40,
                                        height: 40,
                                        child: const Icon(
                                          Icons.location_on,
                                          color: Colors.red,
                                          size: 32,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Material(
                                    elevation: 2,
                                    borderRadius: BorderRadius.circular(4),
                                    child: InkWell(
                                      onTap: () {
                                        final center =
                                            _mapController.camera.center;
                                        final zoom =
                                            _mapController.camera.zoom + 1;
                                        _mapController.move(center, zoom);
                                      },
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(4),
                                              ),
                                        ),
                                        child: const Icon(
                                          Icons.add,
                                          size: 18,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 32,
                                    height: 1,
                                    child: ColoredBox(color: Color(0xFFDDDDDD)),
                                  ),
                                  Material(
                                    elevation: 2,
                                    borderRadius: BorderRadius.circular(4),
                                    child: InkWell(
                                      onTap: () {
                                        final center =
                                            _mapController.camera.center;
                                        final zoom =
                                            _mapController.camera.zoom - 1;
                                        _mapController.move(center, zoom);
                                      },
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                bottom: Radius.circular(4),
                                              ),
                                        ),
                                        child: const Icon(
                                          Icons.remove,
                                          size: 18,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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
            _isEditing ? l10n.t('common.save') : l10n.t('routes.add'),
          ),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      RouteFormResult(
        airportName: _nameController.text.trim(),
        category: _category,
        icaoCode: _icaoController.text.trim().isEmpty
            ? null
            : _icaoController.text.trim().toUpperCase(),
        iataCode: _iataController.text.trim().isEmpty
            ? null
            : _iataController.text.trim().toUpperCase(),
        country: _countryController.text.trim(),
        city: _cityController.text.trim(),
        latitude: double.tryParse(_latController.text.trim()),
        longitude: double.tryParse(_lngController.text.trim()),
      ),
    );
  }
}
