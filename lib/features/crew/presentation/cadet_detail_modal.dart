import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/crew/domain/crew_member.dart';
import 'package:cg6_flights/features/flight_orders/data/flight_orders_repository.dart';
import 'package:cg6_flights/features/flight_orders/domain/flight_order.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showCadetDetailModal(BuildContext context, WidgetRef ref, CrewMember cadet) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => _CadetDetailDialog(cadet: cadet),
  );
}

class _CadetDetailDialog extends ConsumerStatefulWidget {
  const _CadetDetailDialog({required this.cadet});
  final CrewMember cadet;

  @override
  ConsumerState<_CadetDetailDialog> createState() => _CadetDetailDialogState();
}

class _CadetDetailDialogState extends ConsumerState<_CadetDetailDialog> {
  List<FlightOrderItem> _flights = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadFlights);
  }

  Future<void> _loadFlights() async {
    setState(() => _loading = true);
    // Query flights where this cadet appears as crew
    final result = await ref.read(flightOrdersRepositoryProvider).listFlightsByDate(date: DateTime(2020));
    if (!mounted) return;
    // Filter flights where the cadet is in the crew list
    switch (result) {
      case AppSuccess(data: final allFlights):
        final cadetFlights = allFlights
            .where((f) => f.crew.any((c) => c.crewMemberName?.contains(widget.cadet.lastName) == true))
            .toList();
        setState(() { _flights = cadetFlights; _loading = false; });
      case AppFailure():
        setState(() => _loading = false);
    }
  }

  Map<String, int> _ratingSummary() {
    int good = 0, bad = 0, nc = 0;
    for (final f in _flights) {
      if (f.rating == 'good') {
        good++;
      } else if (f.rating == 'bad') {
        bad++;
      } else {
        nc++;
      }
    }
    return {'good': good, 'bad': bad, 'nc': nc};
  }

  @override
  Widget build(BuildContext context) {
    final cadet = widget.cadet;
    final theme = Theme.of(context);
    final ratings = _ratingSummary();

    return AlertDialog(
      insetPadding: const EdgeInsets.all(16),
      titlePadding: EdgeInsets.zero,
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.05)),
              child: Row(children: [
                CircleAvatar(backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12), child: Text(cadet.grade.isNotEmpty ? cadet.grade.substring(0, 2) : 'CD', style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.primary))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${cadet.grade} ${cadet.fullName}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  Text('NSA: ${cadet.nsa}  |  Turnos: ${cadet.cadetTurn ?? '-'}/12', style: theme.textTheme.bodySmall),
                ])),
                // Rating summary badges
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)), child: Text('🟢 ${ratings['good']}', style: const TextStyle(fontSize: 12))),
                const SizedBox(width: 6),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)), child: Text('🔴 ${ratings['bad']}', style: const TextStyle(fontSize: 12))),
                const SizedBox(width: 6),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)), child: Text('⚪ ${ratings['nc']}', style: const TextStyle(fontSize: 12))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ]),
            ),
            const Divider(height: 1),
            // Flight list
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _flights.isEmpty
                      ? const Center(child: Text('Sin vuelos registrados', style: TextStyle(color: Colors.grey)))
                      : ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            for (final f in _flights)
                              Card(
                                child: ListTile(
                                  leading: Icon(f.rating == 'good' ? Icons.check_circle : f.rating == 'bad' ? Icons.cancel : Icons.help_outline, color: f.rating == 'good' ? Colors.green : f.rating == 'bad' ? Colors.red : Colors.grey, size: 22),
                                  title: Text(f.aircraftRegistration ?? '--', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                  subtitle: Text('${f.mission ?? '--'}  |  Instr: ${f.instructorName ?? '--'}  |  ETE: ${f.eteMinutes ?? 0}min', style: const TextStyle(fontSize: 11)),
                                  trailing: f.rating != null
                                      ? Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: (f.rating == 'good' ? Colors.green : Colors.red).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)), child: Text(f.rating == 'good' ? 'Bueno' : 'Malo', style: TextStyle(fontSize: 11, color: f.rating == 'good' ? Colors.green : Colors.red, fontWeight: FontWeight.w600)))
                                      : null,
                                  dense: true,
                                ),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
