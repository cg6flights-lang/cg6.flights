import 'package:cg6_flights/shared/widgets/data_state_view.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PermissionDeniedPage extends StatelessWidget {
  const PermissionDeniedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DataStateView(
        kind: DataStateKind.permissionDenied,
        title: 'Permiso denegado',
        message: 'La ruta solicitada requiere un permiso que tu rol no tiene.',
        onRetry: () => context.go('/dashboard'),
      ),
    );
  }
}
