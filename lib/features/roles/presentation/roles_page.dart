import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RolesPage extends StatelessWidget {
  const RolesPage({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go('/users');
    });
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
