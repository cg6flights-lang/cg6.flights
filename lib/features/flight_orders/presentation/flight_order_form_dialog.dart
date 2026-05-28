import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/auth/application/session_controller.dart';
import 'package:cg6_flights/features/flight_orders/data/flight_orders_repository.dart';
import 'package:cg6_flights/features/flight_orders/domain/flight_order.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FlightOrderFormDialog extends ConsumerStatefulWidget {
  const FlightOrderFormDialog({super.key});

  @override
  ConsumerState<FlightOrderFormDialog> createState() =>
      _FlightOrderFormDialogState();
}

class _FlightOrderFormDialogState
    extends ConsumerState<FlightOrderFormDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedUnitId;
  DateTime _operationDate = DateTime.now();
  bool _saving = false;
  Set<DateTime> _existingDates = {};

  bool get _isGlobalUser {
    final session = ref.read(sessionControllerProvider);
    return session.user?.role?.isGlobal ?? false;
  }

  String? get _userUnitId {
    final session = ref.read(sessionControllerProvider);
    return session.user?.unitId;
  }

  String? get _userUnitName {
    final session = ref.read(sessionControllerProvider);
    return session.user?.unitName;
  }

  @override
  void initState() {
    super.initState();
    if (!_isGlobalUser && _userUnitId != null) {
      _selectedUnitId = _userUnitId;
    }
    _loadExistingDates();
  }

  Future<void> _loadExistingDates() async {
    final unitId = _selectedUnitId;
    if (unitId == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('flight_orders')
          .select('operation_date')
          .eq('unit_id', unitId);
      if (!mounted) return;
      setState(() {
        _existingDates = (rows as List<dynamic>)
            .map((r) => DateTime.tryParse(
                    (r as Map<String, dynamic>)['operation_date'].toString())
                .let((d) => d != null ? DateTime(d.year, d.month, d.day) : null))
            .whereType<DateTime>()
            .toSet();
      });
    } catch (_) {
      // Non-critical: just won't mark dates as taken
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.t('flightOrders.add')),
      content: SizedBox(
        width: 450,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildUnitDropdown(l10n),
                const SizedBox(height: 16),
                _buildDatePicker(l10n),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.t('common.cancel')),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.t('flightOrders.add')),
        ),
      ],
    );
  }

  Widget _buildUnitDropdown(AppLocalizations l10n) {
    final isUnitScoped = !_isGlobalUser && _userUnitId != null;

    if (isUnitScoped) {
      return TextFormField(
        initialValue: _userUnitName ?? '--',
        readOnly: true,
        decoration: InputDecoration(
          labelText: l10n.t('flightOrders.unit'),
          border: const OutlineInputBorder(),
          suffixIcon:
              const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
        ),
      );
    }

    return FutureBuilder<List<dynamic>>(
      future: Supabase.instance.client
          .from('units')
          .select('id,name')
          .eq('active', true)
          .order('name'),
      builder: (context, snapshot) {
        final units = snapshot.data ?? [];
        return DropdownButtonFormField<String>(
          initialValue: _selectedUnitId,
          decoration: InputDecoration(
            labelText: l10n.t('flightOrders.unit'),
            border: const OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('Seleccionar'),
            ),
            for (final u in units)
              DropdownMenuItem<String>(
                value: u['id'].toString(),
                child: Text(u['name']?.toString() ?? ''),
              ),
          ],
          onChanged: (v) {
            setState(() => _selectedUnitId = v);
            _loadExistingDates();
          },
          validator: (v) =>
              v == null || v.isEmpty ? l10n.t('validation.required') : null,
        );
      },
    );
  }

  Widget _buildDatePicker(AppLocalizations l10n) {
    final today = DateTime.now();

    return OutlinedButton.icon(
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _operationDate,
          firstDate: today.subtract(const Duration(days: 30)),
          lastDate: today.add(const Duration(days: 90)),
          selectableDayPredicate: (date) {
            return !_existingDates.contains(date);
          },
        );
        if (picked != null) setState(() => _operationDate = picked);
      },
      icon: const Icon(Icons.calendar_today, size: 16),
      label: Text(
        '${l10n.t('flightOrders.operationDate')}: ${_formatDate(_operationDate)}',
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
      'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUnitId == null) return;

    setState(() => _saving = true);

    final result = await ref
        .read(flightOrdersRepositoryProvider)
        .manageFlightOrder(
          action: 'create',
          unitId: _selectedUnitId!,
          operationDate: _operationDate.toIso8601String().split('T').first,
        );

    if (!mounted) return;
    setState(() => _saving = false);

    switch (result) {
      case AppSuccess<FlightOrder>(data: final order):
        Navigator.of(context).pop(order);
      case AppFailure<FlightOrder>(error: final error):
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T it) block) => block(this);
}
