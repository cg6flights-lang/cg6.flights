import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/errors/app_error.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/core/security/app_permission.dart';
import 'package:cg6_flights/features/auth/application/session_controller.dart';
import 'package:cg6_flights/features/routes/data/routes_repository.dart';
import 'package:cg6_flights/features/routes/domain/route.dart' as domain;
import 'package:cg6_flights/features/routes/presentation/route_form_dialog.dart';
import 'package:cg6_flights/shared/widgets/data_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

final _routesListProvider = FutureProvider<AppResult<List<domain.Route>>>((
  ref,
) async {
  final repo = ref.read(routesRepositoryProvider);
  return repo.listRoutes();
});

class _SavedRoutePair {
  final String originId;
  final String originName;
  final String destId;
  final String destName;
  final double distanceNm;
  final double cruiseSpeed;

  const _SavedRoutePair({
    required this.originId,
    required this.originName,
    required this.destId,
    required this.destName,
    required this.distanceNm,
    required this.cruiseSpeed,
  });

}

class RoutesPage extends ConsumerStatefulWidget {
  const RoutesPage({super.key});

  @override
  ConsumerState<RoutesPage> createState() => _RoutesPageState();
}

class _RoutesPageState extends ConsumerState<RoutesPage> {
  final _mapController = MapController();
  final _distanceCalculator = const Distance();
  double _cruiseSpeed = 450;
  domain.Route? _originRoute;
  domain.Route? _destinationRoute;
  List<_SavedRoutePair> _savedRoutes = [];
  final Map<String, int> _calculationCount = {};

  bool get _canCalculate =>
      _originRoute?.hasCoordinates == true &&
      _destinationRoute?.hasCoordinates == true;

  double get _distanceKm {
    if (!_canCalculate) return 0;
    return _distanceCalculator.as(
      LengthUnit.Kilometer,
      LatLng(_originRoute!.latitude!, _originRoute!.longitude!),
      LatLng(_destinationRoute!.latitude!, _destinationRoute!.longitude!),
    );
  }

  double get _distanceNm => _distanceKm / 1.852;

  double get _bearing {
    if (!_canCalculate) return 0;
    var b = _distanceCalculator.bearing(
      LatLng(_originRoute!.latitude!, _originRoute!.longitude!),
      LatLng(_destinationRoute!.latitude!, _destinationRoute!.longitude!),
    );
    return (b + 360) % 360;
  }

  String get _eteFormatted {
    if (!_canCalculate || _cruiseSpeed <= 0) return '--';
    final hours = _distanceNm / _cruiseSpeed;
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  String _pairKey(domain.Route a, domain.Route b) =>
      '${a.id}->${b.id}';

  @override
  void initState() {
    super.initState();
    _loadSavedRoutes();
  }

  void _loadSavedRoutes() {}

  void _persistSavedRoutes() {}

  void _saveCurrentRoute() {
    if (!_canCalculate || _originRoute == null || _destinationRoute == null) {
      return;
    }
    final pair = _SavedRoutePair(
      originId: _originRoute!.id,
      originName: _originRoute!.airportName,
      destId: _destinationRoute!.id,
      destName: _destinationRoute!.airportName,
      distanceNm: _distanceNm,
      cruiseSpeed: _cruiseSpeed,
    );
    final exists = _savedRoutes.indexWhere(
      (r) => r.originId == pair.originId && r.destId == pair.destId,
    );
    if (exists != -1) {
      _savedRoutes[exists] = pair;
    } else {
      _savedRoutes.insert(0, pair);
      if (_savedRoutes.length > 20) {
        _savedRoutes = _savedRoutes.sublist(0, 20);
      }
    }
    _persistSavedRoutes();
    setState(() {});
  }

  void _removeSavedRoute(int index) {
    _savedRoutes.removeAt(index);
    _persistSavedRoutes();
    setState(() {});
  }

  void _recordCalculation() {
    if (_originRoute == null || _destinationRoute == null) return;
    final key = _pairKey(_originRoute!, _destinationRoute!);
    _calculationCount[key] = (_calculationCount[key] ?? 0) + 1;
  }

  List<MapEntry<String, int>> get _topFrequent {
    final sorted = _calculationCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).toList();
  }

  String _routeLabel(domain.Route r) {
    final icao = r.icaoCode ?? '';
    final city = r.city;
    return '${r.airportName}${icao.isNotEmpty ? ' ($icao)' : ''} — $city';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionControllerProvider);
    final routesAsync = ref.watch(_routesListProvider);
    final canManage = session.can(AppPermission.routesManage);

    return routesAsync.when(
      loading: () =>
          const DataStateView(kind: DataStateKind.loading, title: ''),
      error: (_, _) => DataStateView(
        kind: DataStateKind.systemError,
        title: l10n.t('routes.loadFailed'),
        message: l10n.t('common.retry'),
        onRetry: () => ref.invalidate(_routesListProvider),
      ),
      data: (result) {
        final routes = switch (result) {
          AppSuccess<List<domain.Route>>(data: final list) => list,
          AppFailure<List<domain.Route>>() => null,
        };

        if (routes == null) {
          final error = (result as AppFailure<List<domain.Route>>).error;
          return DataStateView(
            kind: _stateKindForError(error.category),
            title: l10n.t('routes.loadFailed'),
            message: error.message,
            onRetry: () => ref.invalidate(_routesListProvider),
          );
        }

        if (routes.isEmpty) {
          return _RoutesEmptyState(
            canManage: canManage,
            onAdd: () => _openForm(context, ref),
          );
        }

        final routesWithCoords = routes
            .where((r) => r.hasCoordinates)
            .toList();
        final avgLat = routesWithCoords.isNotEmpty
            ? routesWithCoords
                    .map((r) => r.latitude!)
                    .reduce((a, b) => a + b) /
                routesWithCoords.length
            : -12.0;
        final avgLng = routesWithCoords.isNotEmpty
            ? routesWithCoords
                    .map((r) => r.longitude!)
                    .reduce((a, b) => a + b) /
                routesWithCoords.length
            : -77.0;

        final polylinePoints = <Polyline>[];
        if (_canCalculate) {
          polylinePoints.add(Polyline(
            points: [
              LatLng(_originRoute!.latitude!, _originRoute!.longitude!),
              LatLng(_destinationRoute!.latitude!, _destinationRoute!.longitude!),
            ],
            color: Colors.blue.shade700,
            strokeWidth: 3,
          ));
        }

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.t('nav.routes'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (canManage)
                  FilledButton.icon(
                    onPressed: () => _openForm(context, ref),
                    icon: const Icon(Icons.add, size: 20),
                    label: Text(l10n.t('routes.add')),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 1100) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: 550,
                          child: Card(
                            elevation: 1,
                            margin: EdgeInsets.zero,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(12),
                              child: _buildRouteTable(context, ref, routes,
                                  canManage, l10n),
                            ),
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 32, thickness: 1),
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 350,
                              child: _buildMap(
                                context,
                                routesWithCoords,
                                avgLat,
                                avgLng,
                                l10n,
                                polylinePoints,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildRoutePlanner(
                                context, l10n, routesWithCoords),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    SizedBox(
                      height: 300,
                      child: SingleChildScrollView(
                        child: _buildRouteTable(
                            context, ref, routes, canManage, l10n),
                      ),
                    ),
                    const Divider(height: 32, thickness: 1),
                    SizedBox(
                      height: 350,
                      child: _buildMap(
                        context,
                        routesWithCoords,
                        avgLat,
                        avgLng,
                        l10n,
                        polylinePoints,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildRoutePlanner(context, l10n, routesWithCoords),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildRouteTable(
    BuildContext context,
    WidgetRef ref,
    List<domain.Route> routes,
    bool canManage,
    AppLocalizations l10n,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 650),
        child: DataTable(
          headingTextStyle: Theme.of(context).textTheme.titleSmall,
          dataRowMinHeight: 48,
          dataRowMaxHeight: 56,
          columns: [
            DataColumn(label: Text(l10n.t('routes.airportName'))),
            DataColumn(label: Text(l10n.t('routes.category'))),
            DataColumn(label: Text(l10n.t('routes.icao'))),
            DataColumn(label: Text(l10n.t('routes.city'))),
            DataColumn(label: Text(l10n.t('routes.country'))),
            if (canManage) const DataColumn(label: Text('')),
          ],
          rows: [
            for (final r in routes)
              DataRow(
                cells: [
                  DataCell(Text(r.airportName,
                      style: const TextStyle(fontSize: 13))),
                  _categoryChip(r.category, l10n),
                  DataCell(Text(r.icaoCode ?? '-',
                      style: const TextStyle(fontSize: 13))),
                  DataCell(Text(r.city,
                      style: const TextStyle(fontSize: 13))),
                  DataCell(Text(r.country,
                      style: const TextStyle(fontSize: 13))),
                  if (canManage)
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: l10n.t('routes.edit'),
                            visualDensity: VisualDensity.compact,
                            onPressed: () =>
                                _openForm(context, ref, route: r),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            tooltip: l10n.t('routes.deactivate'),
                            visualDensity: VisualDensity.compact,
                            onPressed: () =>
                                _confirmDeactivate(context, ref, r),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  DataCell _categoryChip(String category, AppLocalizations l10n) {
    final (Color color, String label) = switch (category) {
      'internacional' => (Colors.blue, l10n.t('routes.international')),
      'nacional' => (Colors.green, l10n.t('routes.national')),
      'aerodromo' => (Colors.orange, l10n.t('routes.aerodrome')),
      'helipuerto' => (Colors.purple, l10n.t('routes.heliport')),
      _ => (Colors.grey, category),
    };

    return DataCell(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, color: color)),
      ),
    );
  }

  Widget _buildMap(
    BuildContext context,
    List<domain.Route> routes,
    double centerLat,
    double centerLng,
    AppLocalizations l10n,
    List<Polyline> polylines,
  ) {
    if (routes.isEmpty) {
      return Card(
        elevation: 1,
        margin: EdgeInsets.zero,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.map_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.t('routes.noCoordinates'),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: LatLng(centerLat, centerLng),
          initialZoom: 5,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          ),
          if (polylines.isNotEmpty)
            PolylineLayer(polylines: polylines),
          MarkerLayer(
            markers: routes
                .map(
                  (r) => Marker(
                    point: LatLng(r.latitude!, r.longitude!),
                    width: 140,
                    height: 60,
                    child: GestureDetector(
                      onTap: () => _showRoutePopup(context, r, l10n),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on,
                              color: Colors.red, size: 28),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            child: Text(
                              r.airportName,
                              style: const TextStyle(fontSize: 10),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutePlanner(
    BuildContext context,
    AppLocalizations l10n,
    List<domain.Route> routes,
  ) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🧭 Planificador de Rutas',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    initialValue: _cruiseSpeed.toStringAsFixed(0),
                    decoration: const InputDecoration(
                      labelText: 'kts',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final s = double.tryParse(v);
                      if (s != null && s > 0) {
                        setState(() => _cruiseSpeed = s);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Velocidad crucero',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Origen',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _originRoute?.id,
                  isExpanded: true,
                  isDense: true,
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('— Seleccionar —', style: TextStyle(fontSize: 13)),
                    ),
                    for (final r in routes)
                      DropdownMenuItem<String>(
                        value: r.id,
                        child: Text(_routeLabel(r),
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _originRoute = v != null
                          ? routes.firstWhere((r) => r.id == v)
                          : null;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Destino',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _destinationRoute?.id,
                  isExpanded: true,
                  isDense: true,
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('— Seleccionar —', style: TextStyle(fontSize: 13)),
                    ),
                    for (final r in routes)
                      DropdownMenuItem<String>(
                        value: r.id,
                        child: Text(_routeLabel(r),
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _destinationRoute = v != null
                          ? routes.firstWhere((r) => r.id == v)
                          : null;
                      if (_canCalculate) _recordCalculation();
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _originRoute != null && _destinationRoute != null
                      ? () {
                          setState(() {
                            final tmp = _originRoute;
                            _originRoute = _destinationRoute;
                            _destinationRoute = tmp;
                          });
                        }
                      : null,
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  label: const Text('Intercambiar', style: TextStyle(fontSize: 12)),
                ),
                const Spacer(),
                if (_canCalculate)
                  OutlinedButton.icon(
                    onPressed: _saveCurrentRoute,
                    icon: const Icon(Icons.star_border, size: 16),
                    label: const Text('Guardar', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            if (_canCalculate) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _resultChip(context, 'Distancia',
                        '${_distanceNm.toStringAsFixed(0)} NM'),
                    _resultChip(context, '',
                        '${_distanceKm.toStringAsFixed(0)} KM'),
                    _resultChip(context, 'Rumbo',
                        '${_bearing.toStringAsFixed(0)}°'),
                    _resultChip(context, 'ETE', _eteFormatted),
                  ],
                ),
              ),
            ],
            if (_savedRoutes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('📋 Mis rutas guardadas',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ..._savedRoutes.asMap().entries.map((entry) {
                final i = entry.key;
                final sr = entry.value;
                final ete = sr.cruiseSpeed > 0
                    ? _formatEte(sr.distanceNm / sr.cruiseSpeed)
                    : '--';
                return InkWell(
                  onTap: () {
                    setState(() {
                      _originRoute = routes
                          .firstWhere((r) => r.id == sr.originId);
                      _destinationRoute = routes
                          .firstWhere((r) => r.id == sr.destId);
                      _cruiseSpeed = sr.cruiseSpeed;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${sr.originName} → ${sr.destName}',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${sr.distanceNm.toStringAsFixed(0)} NM  $ete',
                          style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => _removeSavedRoute(i),
                          child: Icon(Icons.close, size: 14,
                              color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
            if (_calculationCount.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('📊 Rutas más frecuentes',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ..._topFrequent.map((entry) {
                final parts = entry.key.split('->');
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '${entry.value}x  $parts',
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _resultChip(
      BuildContext context, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty)
          Text(label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }

  String _formatEte(double hours) {
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  void _showRoutePopup(
    BuildContext context,
    domain.Route r,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(r.airportName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow(context, l10n.t('routes.category'),
                _categoryLabel(r.category, l10n)),
            if (r.icaoCode != null)
              _infoRow(context, l10n.t('routes.icao'), r.icaoCode!),
            if (r.iataCode != null)
              _infoRow(context, l10n.t('routes.iata'), r.iataCode!),
            _infoRow(context, l10n.t('routes.city'), r.city),
            _infoRow(context, l10n.t('routes.country'), r.country),
            if (r.latitude != null)
              _infoRow(context, l10n.t('routes.latitude'),
                  r.latitude!.toStringAsFixed(4)),
            if (r.longitude != null)
              _infoRow(context, l10n.t('routes.longitude'),
                  r.longitude!.toStringAsFixed(4)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.t('common.cancel')),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(String category, AppLocalizations l10n) {
    return switch (category) {
      'internacional' => l10n.t('routes.international'),
      'nacional' => l10n.t('routes.national'),
      'aerodromo' => l10n.t('routes.aerodrome'),
      'helipuerto' => l10n.t('routes.heliport'),
      _ => category,
    };
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    domain.Route? route,
  }) async {
    final saved = await showDialog<RouteFormResult>(
      context: context,
      builder: (_) => RouteFormDialog(route: route),
    );

    if (saved != null && context.mounted) {
      final repo = ref.read(routesRepositoryProvider);
      final result = await repo.saveRoute(
        routeId: route?.id,
        airportName: saved.airportName,
        category: saved.category,
        icaoCode: saved.icaoCode,
        iataCode: saved.iataCode,
        country: saved.country,
        city: saved.city,
        latitude: saved.latitude,
        longitude: saved.longitude,
      );
      if (!context.mounted) return;

      switch (result) {
        case AppSuccess<void>():
          ref.invalidate(_routesListProvider);
        case AppFailure<void>(error: final error):
          _showError(context, error.message);
      }
    }
  }

  Future<void> _confirmDeactivate(
    BuildContext context,
    WidgetRef ref,
    domain.Route route,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.t('routes.deactivate')),
        content: Text(
          '${l10n.t('routes.deactivateConfirm')} ${route.airportName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.t('routes.deactivate')),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final result =
          await ref.read(routesRepositoryProvider).deactivateRoute(route.id);
      if (!context.mounted) return;

      switch (result) {
        case AppSuccess<void>():
          ref.invalidate(_routesListProvider);
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

class _RoutesEmptyState extends StatelessWidget {
  const _RoutesEmptyState({required this.canManage, required this.onAdd});

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
              Icons.route_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.t('routes.empty'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (canManage) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: Text(l10n.t('routes.add')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
