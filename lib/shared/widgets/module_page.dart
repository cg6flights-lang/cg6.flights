import 'package:cg6_flights/shared/widgets/data_state_view.dart';
import 'package:flutter/material.dart';

class ModulePage extends StatelessWidget {
  const ModulePage({
    super.key,
    required this.title,
    required this.icon,
    required this.summary,
    required this.actions,
    this.stateKind = DataStateKind.empty,
  });

  final String title;
  final IconData icon;
  final String summary;
  final List<String> actions;
  final DataStateKind stateKind;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Icon(icon, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(summary, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 24),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final action in actions)
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.lock_clock),
                label: Text(action),
              ),
          ],
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 320,
          child: DataStateView(
            kind: stateKind,
            title: 'Modulo listo para conectar datos',
            message:
                'La estructura respeta SDD; las operaciones criticas quedan detras de permisos, repositories, RLS y auditoria.',
          ),
        ),
      ],
    );
  }
}
