import 'package:flutter/material.dart';

Future<bool?> showFlightStateConfirm({
  required BuildContext context,
  required String tailNumber,
  required String currentState,
  required String nextState,
}) {
  final stateLabels = {
    'motor_start': 'Arranque de Motor',
    'taxi_start': 'Taxeo',
    'takeoff': 'Despegue',
    'landing': 'Aterrizaje',
    'engine_shutdown': 'Apagado de Motor',
  };

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Row(children: [
        Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 24),
        SizedBox(width: 10),
        Expanded(child: Text('Confirmar Avance de Estado', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('¿Confirmaste que la aeronave', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Center(
          child: Text('«$tailNumber»', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ),
        const SizedBox(height: 8),
        Text('está en ${stateLabels[nextState]?.toUpperCase() ?? nextState}?', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        Row(children: [
          _badge(context, 'Actual: ${stateLabels[currentState] ?? currentState}', Colors.orange),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward, size: 16),
          const SizedBox(width: 8),
          _badge(context, 'Nuevo: ${stateLabels[nextState] ?? nextState}', Colors.green),
        ]),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton.icon(
          onPressed: () => Navigator.pop(ctx, true),
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Confirmar'),
        ),
      ],
    ),
  );
}

Widget _badge(BuildContext context, String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withValues(alpha: 0.4))),
    child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
  );
}
