import 'dart:async';

import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/features/flights/application/metar_provider.dart';
import 'package:cg6_flights/features/flights/domain/metar_data.dart';
import 'package:cg6_flights/features/routes/data/airports_dataset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

class MetarWidget extends ConsumerStatefulWidget {
  const MetarWidget({super.key, required this.icaoCodes});

  final List<String> icaoCodes;

  @override
  ConsumerState<MetarWidget> createState() => _MetarWidgetState();
}

class _MetarWidgetState extends ConsumerState<MetarWidget> {
  String? _selectedIcao = 'SPJC';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(hours: 1), (_) {
      if (mounted && _selectedIcao != null) {
        ref.invalidate(metarByIcaoProvider(_selectedIcao!));
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MetarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selectedIcao ??= 'SPJC';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surfaceContainerLow,
            theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _icaoSelector(theme),
          const SizedBox(width: 6),
          _weatherMapButton(theme),
          const SizedBox(width: 10),
          if (_selectedIcao != null)
            Expanded(child: _metarData(_selectedIcao!, theme)),
        ],
      ),
    );
  }

  Widget _weatherMapButton(ThemeData theme) {
    return IconButton(
      onPressed: () => _openWeatherMap(context),
      icon: const Icon(Icons.map_outlined, size: 17),
      tooltip: 'Mapa weather',
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        foregroundColor: theme.colorScheme.primary,
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.08),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.22),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  void _openWeatherMap(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => const _WeatherMapDialog(),
    );
  }

  Widget _icaoSelector(ThemeData theme) {
    return SizedBox(
      width: 92,
      child: Autocomplete<String>(
        initialValue: TextEditingValue(text: _selectedIcao ?? 'SPJC'),
        optionsBuilder: (value) {
          final query = value.text.trim().toUpperCase();
          final suggestions = _suggestionIcaos();
          if (query.isEmpty) return suggestions.take(8);
          return suggestions.where((icao) => icao.startsWith(query)).take(8);
        },
        onSelected: _commitIcao,
        fieldViewBuilder:
            (context, textController, focusNode, onFieldSubmitted) {
              return TextField(
                controller: textController,
                focusNode: focusNode,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
                  LengthLimitingTextInputFormatter(4),
                ],
                onChanged: (value) {
                  final normalized = value.toUpperCase();
                  if (value != normalized) {
                    textController.value = TextEditingValue(
                      text: normalized,
                      selection: TextSelection.collapsed(
                        offset: normalized.length,
                      ),
                    );
                  }
                  if (_isValidIcao(normalized)) _commitIcao(normalized);
                },
                onSubmitted: (value) {
                  final normalized = value.trim().toUpperCase();
                  if (_isValidIcao(normalized)) _commitIcao(normalized);
                },
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  color: theme.colorScheme.primary,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'ICAO',
                  prefixIcon: Icon(
                    Icons.search,
                    size: 15,
                    color: theme.colorScheme.primary,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.primary.withValues(alpha: 0.08),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.28),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: theme.colorScheme.primary),
                  ),
                ),
              );
            },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 180,
                  maxHeight: 220,
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final icao = options.elementAt(index);
                    final airport = _airportByIcao(icao);
                    return ListTile(
                      dense: true,
                      minLeadingWidth: 0,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 0,
                      ),
                      title: Text(
                        icao,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: airport != null
                          ? Text(
                              airport.city,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10),
                            )
                          : null,
                      onTap: () => onSelected(icao),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<String> _suggestionIcaos() {
    final values = <String>{'SPJC'};
    values.addAll(
      widget.icaoCodes
          .map((icao) => icao.trim().toUpperCase())
          .where(_isValidIcao),
    );
    values.addAll(kAirports.map((airport) => airport.icao.toUpperCase()));
    return values.toList()..sort();
  }

  AirportData? _airportByIcao(String icao) {
    for (final airport in kAirports) {
      if (airport.icao.toUpperCase() == icao.toUpperCase()) return airport;
    }
    return null;
  }

  bool _isValidIcao(String value) {
    return RegExp(r'^[A-Z]{4}$').hasMatch(value);
  }

  void _commitIcao(String icao) {
    final normalized = icao.trim().toUpperCase();
    if (!_isValidIcao(normalized) || _selectedIcao == normalized) return;
    setState(() => _selectedIcao = normalized);
  }

  Widget _metarData(String icao, ThemeData theme) {
    final metarAsync = ref.watch(metarByIcaoProvider(icao));

    final child = metarAsync.when(
      loading: () => const _MetarLoadingDots(key: ValueKey('metar-loading')),
      error: (error, stackTrace) =>
          _NoMetarData(key: ValueKey('metar-error-$icao')),
      data: (metar) => metar == null
          ? _NoMetarData(key: ValueKey('metar-empty-$icao'))
          : _MetarSummary(
              key: ValueKey('metar-${metar.icao}-${metar.raw}'),
              metar: metar,
              onTap: () => _openDetailModal(context, metar),
            ),
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0.03, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: child,
    );
  }

  void _openDetailModal(BuildContext context, MetarData metar) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            _MetarCategoryPulse(category: metar.flightCategory, size: 12),
            const SizedBox(width: 10),
            Text(
              metar.icao,
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            _MetarCategoryBadge(category: metar.flightCategory),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _RawReportBlock(label: 'METAR', value: metar.raw),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _WeatherChip(
                      icon: Icons.thermostat,
                      label: l10n.t('flights.metar.temp'),
                      value: metar.tempDisplay,
                    ),
                    _WeatherChip(
                      icon: Icons.water_drop_outlined,
                      label: l10n.t('flights.metar.dewpoint'),
                      value: metar.dewpoint != null
                          ? '${metar.dewpoint!.toStringAsFixed(0)}°C'
                          : '--',
                    ),
                    _WeatherChip(
                      icon: Icons.air,
                      label: l10n.t('flights.metar.wind'),
                      value: metar.windDisplay,
                    ),
                    _WeatherChip(
                      icon: Icons.visibility_outlined,
                      label: l10n.t('flights.metar.visibility'),
                      value: metar.visDisplay,
                    ),
                    _WeatherChip(
                      icon: Icons.speed,
                      label: 'QNH',
                      value: metar.qnhDisplay,
                    ),
                    if (metar.observationTime != null)
                      _WeatherChip(
                        icon: Icons.schedule,
                        label: l10n.t('flights.metar.observedAt'),
                        value:
                            '${metar.observationTime!.hour.toString().padLeft(2, "0")}:${metar.observationTime!.minute.toString().padLeft(2, "0")}Z',
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Consumer(
                  builder: (context, ref, _) {
                    final tafAsync = ref.watch(tafByIcaoProvider(metar.icao));
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: tafAsync.when(
                        loading: () => const Padding(
                          key: ValueKey('taf-loading'),
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(child: _MetarLoadingDots()),
                        ),
                        error: (error, stackTrace) => const SizedBox.shrink(),
                        data: (tafs) {
                          if (tafs.isEmpty) return const SizedBox.shrink();
                          return Column(
                            key: const ValueKey('taf-data'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final taf in tafs)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _RawReportBlock(
                                    label: 'TAF',
                                    value: taf.raw,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.t('common.close')),
          ),
        ],
      ),
    );
  }
}

class _MetarSummary extends StatelessWidget {
  const _MetarSummary({super.key, required this.metar, required this.onTap});

  final MetarData metar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _MetarCategoryPulse(category: metar.flightCategory),
              const SizedBox(width: 8),
              _WeatherChip(
                icon: Icons.thermostat,
                label: '',
                value: metar.tempDisplay,
                dense: true,
              ),
              const SizedBox(width: 6),
              _WeatherChip(
                icon: Icons.air,
                label: '',
                value: metar.windDisplay,
                dense: true,
              ),
              const SizedBox(width: 6),
              _WeatherChip(
                icon: Icons.visibility_outlined,
                label: '',
                value: metar.visDisplay,
                dense: true,
              ),
              const SizedBox(width: 6),
              _WeatherChip(
                icon: Icons.speed,
                label: '',
                value: metar.qnhDisplay,
                dense: true,
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.open_in_new,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.55,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeatherMapDialog extends ConsumerStatefulWidget {
  const _WeatherMapDialog();

  @override
  ConsumerState<_WeatherMapDialog> createState() => _WeatherMapDialogState();
}

class _WeatherMapDialogState extends ConsumerState<_WeatherMapDialog> {
  AirportData? _selectedAirport;

  List<AirportData> get _peruvianAirports =>
      kAirports
          .where(
            (airport) =>
                kPeruWeatherStationIcaos.contains(airport.icao) &&
                RegExp(r'^[A-Z]{4}$').hasMatch(airport.icao),
          )
          .toList()
        ..sort((a, b) => a.icao.compareTo(b.icao));

  @override
  void initState() {
    super.initState();
    _selectedAirport = _peruvianAirports.firstWhere(
      (airport) => airport.icao == 'SPJC',
      orElse: () => _peruvianAirports.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final airports = _peruvianAirports;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.map_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Weather Perú',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 920,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final map = _PeruWeatherMap(
              airports: airports,
              selectedIcao: _selectedAirport?.icao,
              onSelect: (airport) => setState(() => _selectedAirport = airport),
            );
            final detail = _WeatherAirportDetail(airport: _selectedAirport);

            if (compact) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 360, child: map),
                  const SizedBox(height: 12),
                  detail,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: SizedBox(height: 430, child: map)),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: detail),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.t('common.close')),
        ),
      ],
    );
  }
}

class _PeruWeatherMap extends ConsumerWidget {
  const _PeruWeatherMap({
    required this.airports,
    required this.selectedIcao,
    required this.onSelect,
  });

  final List<AirportData> airports;
  final String? selectedIcao;
  final void Function(AirportData airport) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(-9.2, -75.2),
          initialZoom: 5.1,
          interactionOptions: InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'cg6_flights',
          ),
          MarkerLayer(
            markers: [
              for (final airport in airports)
                Marker(
                  point: LatLng(airport.lat, airport.lng),
                  width: 52,
                  height: 52,
                  child: _WeatherAirportMarker(
                    airport: airport,
                    selected: selectedIcao == airport.icao,
                    onTap: () => onSelect(airport),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeatherAirportMarker extends ConsumerWidget {
  const _WeatherAirportMarker({
    required this.airport,
    required this.selected,
    required this.onTap,
  });

  final AirportData airport;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final metarAsync = ref.watch(metarByIcaoProvider(airport.icao));
    final tooltip = metarAsync.when(
      loading: () => '${airport.icao} · cargando METAR',
      error: (_, _) => '${airport.icao} · sin datos',
      data: (metar) => metar == null
          ? '${airport.icao} · sin datos'
          : '${airport.icao} · ${airport.city}\n${metar.raw}',
    );
    final color = selected ? theme.colorScheme.primary : Colors.blue.shade700;

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 250),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: selected ? 24 : 20,
              height: selected ? 24 : 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.18),
                border: Border.all(color: color, width: selected ? 2 : 1.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: selected ? 0.35 : 0.18),
                    blurRadius: selected ? 10 : 6,
                  ),
                ],
              ),
              child: Icon(
                airport.icao == 'SPJC' ? Icons.home_filled : Icons.circle,
                size: selected ? 12 : 9,
                color: color,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                airport.icao,
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherAirportDetail extends ConsumerWidget {
  const _WeatherAirportDetail({required this.airport});

  final AirportData? airport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final selected = airport;

    if (selected == null) {
      return _WeatherMapPanel(
        child: Text(
          l10n.t('flights.metar.noData'),
          style: theme.textTheme.bodySmall,
        ),
      );
    }

    final metarAsync = ref.watch(metarByIcaoProvider(selected.icao));
    final tafAsync = ref.watch(tafByIcaoProvider(selected.icao));

    return _WeatherMapPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${selected.icao} · ${selected.city}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            selected.name,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          metarAsync.when(
            loading: () => const Center(child: _MetarLoadingDots()),
            error: (_, _) => _WeatherNoData(l10n: l10n),
            data: (metar) {
              if (metar == null) return _WeatherNoData(l10n: l10n);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _MetarCategoryPulse(
                        category: metar.flightCategory,
                        size: 7,
                      ),
                      const SizedBox(width: 6),
                      _MetarCategoryBadge(category: metar.flightCategory),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _WeatherChip(
                        icon: Icons.thermostat,
                        label: '',
                        value: metar.tempDisplay,
                        dense: true,
                      ),
                      _WeatherChip(
                        icon: Icons.air,
                        label: '',
                        value: metar.windDisplay,
                        dense: true,
                      ),
                      _WeatherChip(
                        icon: Icons.visibility_outlined,
                        label: '',
                        value: metar.visDisplay,
                        dense: true,
                      ),
                      _WeatherChip(
                        icon: Icons.speed,
                        label: '',
                        value: metar.qnhDisplay,
                        dense: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _RawReportBlock(label: 'METAR', value: metar.raw),
                  _PhenomenaChips(raw: metar.raw),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          tafAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (tafs) {
              if (tafs.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final taf in tafs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _RawReportBlock(label: 'TAF', value: taf.raw),
                          _PhenomenaChips(raw: taf.raw),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WeatherMapPanel extends StatelessWidget {
  const _WeatherMapPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(maxHeight: 430),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        color: theme.colorScheme.surfaceContainerLow,
      ),
      child: SingleChildScrollView(child: child),
    );
  }
}

class _WeatherNoData extends StatelessWidget {
  const _WeatherNoData({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Text(
      l10n.t('flights.metar.noData'),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _PhenomenaChips extends StatelessWidget {
  const _PhenomenaChips({required this.raw});

  final String raw;

  static const _tokens = ['SPECI', 'BECMG', 'BECOMING', 'TEMPO', 'PROB30'];

  @override
  Widget build(BuildContext context) {
    final found = _tokens.where((token) => raw.contains(token)).toList();
    if (found.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final token in found)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: theme.colorScheme.tertiaryContainer.withValues(
                  alpha: 0.5,
                ),
              ),
              child: Text(
                token,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NoMetarData extends StatelessWidget {
  const _NoMetarData({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Icon(
          Icons.cloud_off_outlined,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 6),
        Text(
          l10n.t('flights.metar.noData'),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _MetarLoadingDots extends StatefulWidget {
  const _MetarLoadingDots({super.key});

  @override
  State<_MetarLoadingDots> createState() => _MetarLoadingDotsState();
}

class _MetarLoadingDotsState extends State<_MetarLoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            _AnimatedDot(controller: _controller, index: i),
        ],
      ),
    );
  }
}

class _AnimatedDot extends StatelessWidget {
  const _AnimatedDot({required this.controller, required this.index});

  final AnimationController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    const size = 7.0;
    final delay = index * 0.25;
    final alpha = Tween<double>(begin: 0.28, end: 1).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(delay, delay + 0.4, curve: Curves.easeInOut),
      ),
    );
    final scale = Tween<double>(begin: 0.68, end: 1.16).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(delay, delay + 0.4, curve: Curves.easeInOut),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) => Transform.scale(
          scale: scale.value,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: alpha.value),
            ),
            child: const SizedBox(width: size, height: size),
          ),
        ),
      ),
    );
  }
}

class _MetarCategoryPulse extends StatefulWidget {
  const _MetarCategoryPulse({required this.category, this.size = 8});

  final String? category;
  final double size;

  @override
  State<_MetarCategoryPulse> createState() => _MetarCategoryPulseState();
}

class _MetarCategoryPulseState extends State<_MetarCategoryPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(widget.category);
    return SizedBox(
      width: widget.size * 2.5,
      height: widget.size * 2.5,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final pulse = Curves.easeOut.transform(_controller.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.size + (widget.size * 1.4 * pulse),
                height: widget.size + (widget.size * 1.4 * pulse),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.22 * (1 - pulse)),
                ),
              ),
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MetarCategoryBadge extends StatelessWidget {
  const _MetarCategoryBadge({required this.category});

  final String? category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _categoryColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        category ?? '--',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _WeatherChip extends StatelessWidget {
  const _WeatherChip({
    required this.icon,
    required this.label,
    required this.value,
    this.dense = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 8,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: dense ? 13 : 15, color: foreground),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ],
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: dense ? 11 : 12,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _RawReportBlock extends StatelessWidget {
  const _RawReportBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.14),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              fontFamily: 'monospace',
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

Color _categoryColor(String? category) {
  return switch (category) {
    'VFR' => Colors.green,
    'MVFR' => Colors.blue,
    'IFR' => Colors.red,
    'LIFR' => Colors.purple,
    _ => Colors.grey,
  };
}
