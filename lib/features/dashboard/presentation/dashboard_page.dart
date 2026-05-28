import 'package:cg6_flights/features/auth/application/session_controller.dart';
import 'package:cg6_flights/shared/widgets/app_badges.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionControllerProvider).user;
    final cards = [
      ('Ordenes del dia', '0', Icons.assignment_outlined),
      ('Vuelos activos', '0', Icons.flight_takeoff),
      ('Cierres pendientes', '0', Icons.task_alt),
      ('Alertas operativas', '0', Icons.notification_important_outlined),
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Dashboard operacional',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            RoleBadge(role: user?.role),
            UnitBadge(unitName: user?.unitName),
            const StatusBadge(text: 'Auditoria activa', icon: Icons.verified),
          ],
        ),
        const SizedBox(height: 24),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 260,
            mainAxisExtent: 132,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) {
            final card = cards[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(card.$3, size: 28),
                    const Spacer(),
                    Text(
                      card.$2,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(card.$1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estado de integracion',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                const ListTile(
                  leading: Icon(Icons.security),
                  title: Text('RBAC y guards activos'),
                  subtitle: Text('Permisos por accion y alcance operacional.'),
                ),
                const ListTile(
                  leading: Icon(Icons.storage),
                  title: Text('Supabase preparado'),
                  subtitle: Text(
                    'Migraciones, RLS y Edge Functions en estructura.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
