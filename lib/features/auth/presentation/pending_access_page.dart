import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/features/auth/application/session_controller.dart';
import 'package:cg6_flights/shared/widgets/data_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PendingAccessPage extends ConsumerWidget {
  const PendingAccessPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context).t;
    final session = ref.watch(sessionControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('CG6 Flights')),
      body: Column(
        children: [
          Expanded(
            child: DataStateView(
              kind: DataStateKind.permissionDenied,
              title: t('auth.pending'),
              message: session.error?.message ?? t('auth.pending.body'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: session.isLoading
                      ? null
                      : () => ref
                            .read(sessionControllerProvider.notifier)
                            .claimFirstLeader(),
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: const Text('Activar primer Lider'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(sessionControllerProvider.notifier).signOut(),
                  icon: const Icon(Icons.logout),
                  label: Text(t('auth.logout')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
