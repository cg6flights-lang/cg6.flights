import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/shared/widgets/data_state_view.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PermissionDeniedPage extends StatelessWidget {
  const PermissionDeniedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;

    return Scaffold(
      body: DataStateView(
        kind: DataStateKind.permissionDenied,
        title: t('auth.denied'),
        message: t('auth.deniedBody'),
        onRetry: () => context.go('/dashboard'),
      ),
    );
  }
}
