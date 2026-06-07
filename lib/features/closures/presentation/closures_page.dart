import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/auth/application/session_controller.dart';
import 'package:cg6_flights/features/closures/data/closures_repository.dart';
import 'package:cg6_flights/features/closures/presentation/closure_summary_modal.dart';
import 'package:cg6_flights/features/flight_orders/domain/flight_order.dart';
import 'package:cg6_flights/shared/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ClosuresPage extends ConsumerStatefulWidget {
  const ClosuresPage({super.key});
  @override
  ConsumerState<ClosuresPage> createState() => _ClosuresPageState();
}

class _ClosuresPageState extends ConsumerState<ClosuresPage> {
  List<FlightOrder> _pending = [];
  List<FlightOrder> _closed = [];
  bool _loading = true;
  String? _error;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final repo = ref.read(closuresRepositoryProvider);
    final session = ref.read(sessionControllerProvider);
    final unitId = session.user?.role?.isGlobal == true ? null : session.user?.unitId;

    final pending = await repo.listPendingClosures(unitId: unitId);
    final closed = await repo.listClosedOrders(unitId: unitId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (pending case AppSuccess(data: final d)) { _pending = d; } else if (pending case AppFailure(error: final e)) { _error = e.message; }
      if (closed case AppSuccess(data: final d)) { _closed = d; }
    });
  }

  Future<void> _closeOrder(FlightOrder order) async {
    final confirmed = await showClosureSummary(context, order, ref);
    if (confirmed != true || !mounted) return;

    setState(() => _actionError = null);
    final result = await ref.read(closuresRepositoryProvider).closeOrder(order.id);
    if (!mounted) return;
    switch (result) {
      case AppSuccess(): _load();
      case AppFailure(error: final e): setState(() => _actionError = e.message);
    }
  }

  Future<void> _reopenOrder(FlightOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reabrir Orden de Vuelo'),
        content: Text('¿Reabrir la OV ${order.id.substring(0, 8)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reabrir')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await ref.read(closuresRepositoryProvider).reopenOrder(order.id);
    if (!mounted) return;
    switch (result) {
      case AppSuccess(): _load();
      case AppFailure(error: final e): setState(() => _actionError = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canReopen = ref.watch(sessionControllerProvider).user?.role?.isGlobal == true;

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
      const SizedBox(height: 12),
      FilledButton(onPressed: _load, child: const Text('Reintentar')),
    ]));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _buildColumn('Pendientes de Cierre', Icons.hourglass_bottom, _pending, true, canReopen, theme)),
        const SizedBox(width: 12),
        Expanded(child: _buildColumn('Histórico de Cerradas', Icons.archive_outlined, _closed, false, canReopen, theme)),
      ]),
    );
  }

  Widget _buildColumn(String title, IconData icon, List<FlightOrder> orders, bool isPending, bool canReopen, ThemeData theme) {
    return Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
            Text('${orders.length}', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w900)),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: orders.isEmpty
              ? Center(child: Text('Sin órdenes', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)))
              : ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (_, i) => _OrderTile(
                    order: orders[i],
                    isPending: isPending,
                    canReopen: canReopen,
                    onClose: () => _closeOrder(orders[i]),
                    onReopen: () => _reopenOrder(orders[i]),
                  ),
                ),
        ),
        if (_actionError != null) Padding(
          padding: const EdgeInsets.all(8),
          child: Text(_actionError!, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
        ),
      ]),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, required this.isPending, required this.canReopen, required this.onClose, required this.onReopen});
  final FlightOrder order;
  final bool isPending;
  final bool canReopen;
  final VoidCallback onClose;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = '${order.operationDate.day.toString().padLeft(2, '0')}/${order.operationDate.month.toString().padLeft(2, '0')}/${order.operationDate.year}';
    return ListTile(
      dense: true,
      title: Text('OV $dateStr', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(order.id.substring(0, 8), style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
      trailing: isPending
          ? ElevatedButton.icon(
              onPressed: onClose, icon: const Icon(Icons.check, size: 16), label: const Text('Cerrar'),
              style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact, textStyle: const TextStyle(fontSize: 11)),
            )
          : canReopen
              ? TextButton.icon(onPressed: onReopen, icon: const Icon(Icons.replay, size: 14), label: const Text('Reabrir'))
              : StatusChip.fromStatus('closed'),
    );
  }
}
