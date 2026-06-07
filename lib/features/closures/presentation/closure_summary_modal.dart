import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/closures/data/closures_repository.dart';
import 'package:cg6_flights/features/flight_orders/domain/flight_order.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<bool?> showClosureSummary(BuildContext context, FlightOrder order, WidgetRef ref) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ClosureSummaryModal(order: order, ref: ref),
  );
}

class _ClosureSummaryModal extends ConsumerStatefulWidget {
  const _ClosureSummaryModal({required this.order, required this.ref});
  final FlightOrder order;
  final WidgetRef ref;

  @override
  ConsumerState<_ClosureSummaryModal> createState() => _ClosureSummaryModalState();
}

class _ClosureSummaryModalState extends ConsumerState<_ClosureSummaryModal> {
  Map<String, dynamic>? _summary;
  bool _loadingSummary = true;
  String? _summaryError;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final result = await widget.ref.read(closuresRepositoryProvider).getClosureSummary(widget.order.id);
    if (!mounted) return;
    setState(() {
      _loadingSummary = false;
      switch (result) {
        case AppSuccess(data: final s): _summary = s;
        case AppFailure(error: final e): _summaryError = e.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = '${widget.order.operationDate.day.toString().padLeft(2, '0')}/${widget.order.operationDate.month.toString().padLeft(2, '0')}/${widget.order.operationDate.year}';

    return AlertDialog(
      title: Text('Resumen de Cierre — OV $dateStr', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 600,
        child: _loadingSummary
            ? const Center(child: CircularProgressIndicator())
            : _summaryError != null
                ? Text(_summaryError!, style: TextStyle(color: theme.colorScheme.error))
                : _summary == null
                    ? const Text('Sin datos')
                    : _buildSummary(theme),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.check_circle, size: 18),
          label: const Text('Confirmar Cierre'),
        ),
      ],
    );
  }

  Widget _buildSummary(ThemeData theme) {
    final s = _summary!;
    final hours = ((s['totalMinutes'] as int) / 60).toStringAsFixed(1);
    final aircraft = s['aircraft'] as Map<String, dynamic>;
    final crew = s['crew'] as Map<String, dynamic>;
    final models = s['models'] as Map<String, dynamic>;
    final details = s['details'] as List;

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        // Totals
        _section(theme, 'Totales Generales', [
          '${s['totalFlights']} vuelos · $hours horas totales',
        ]),
        // By aircraft
        _section(theme, 'Por Aeronave', aircraft.entries.map((e) => '${e.key}: ${e.value['flights']} vuelos · ${(e.value['minutes'] / 60).toStringAsFixed(1)}h (${e.value['model']})').toList()),
        // By model
        _section(theme, 'Por Modelo', models.entries.map((e) => '${e.key}: ${e.value['flights']} vuelos · ${(e.value['minutes'] / 60).toStringAsFixed(1)}h').toList()),
        // By crew
        _section(theme, 'Por Tripulación', crew.entries.map((e) => '${e.key}: ${e.value['flights']} vuelos · ${(e.value['minutes'] / 60).toStringAsFixed(1)}h (${e.value['role']})').toList()),
        // Detail
        if (details.isNotEmpty) ...[
          const Divider(),
          Text('Detalle por Vuelo', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          for (final d in details)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${d['tailNumber']} (${d['model']}): ${d['origin']}→${d['dest']} · ${(d['minutes'] / 60).toStringAsFixed(1)}h · ${(d['crew'] as List).join(', ')}',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
            ),
        ],
      ]),
    );
  }

  Widget _section(ThemeData theme, String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
        const SizedBox(height: 4),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text('• $item', style: TextStyle(fontSize: 13)),
          ),
      ]),
    );
  }
}
