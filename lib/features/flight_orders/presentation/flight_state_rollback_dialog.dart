import 'package:flutter/material.dart';

Future<Map<String, String>?> showFlightStateRollback({
  required BuildContext context,
  required String tailNumber,
  required String currentState,
  required String previousState,
}) {
  final stateLabels = {
    'motor_start': 'Arranque de Motor',
    'taxi_start': 'Taxeo',
    'takeoff': 'Despegue',
    'landing': 'Aterrizaje',
    'engine_shutdown': 'Apagado de Motor',
  };

  final reasonController = TextEditingController();

  return showDialog<Map<String, String>>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Row(children: [
        Icon(Icons.replay, color: Color(0xFFE65100), size: 24),
        SizedBox(width: 10),
        Expanded(child: Text('Retroceder Estado', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Aeronave: $tailNumber', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Row(children: [
          _badge(ctx, stateLabels[currentState] ?? currentState, Colors.red),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_back, size: 16),
          const SizedBox(width: 8),
          _badge(ctx, stateLabels[previousState] ?? previousState, Colors.orange),
        ]),
        const SizedBox(height: 16),
        TextFormField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Motivo del retroceso', border: OutlineInputBorder(), hintText: 'Describa el motivo...'),
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.withValues(alpha: 0.3))),
          child: const Row(children: [
            Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFE65100)),
            SizedBox(width: 8),
            Expanded(child: Text('Esta acción se registrará en auditoría y requiere autorización.', style: TextStyle(fontSize: 11, color: Color(0xFFBF360C)))),
          ]),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton.icon(
          onPressed: () {
            if (reasonController.text.trim().isEmpty) {
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('El motivo es obligatorio.')));
              return;
            }
            Navigator.pop(ctx, {'reason': reasonController.text.trim()});
          },
          icon: const Icon(Icons.replay, size: 18),
          label: const Text('Retroceder'),
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
