import 'package:cg6_flights/core/security/app_role.dart';
import 'package:flutter/material.dart';

class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role});

  final AppRole? role;

  @override
  Widget build(BuildContext context) {
    return _Badge(
      icon: Icons.admin_panel_settings_outlined,
      text: role?.labelEs ?? 'Sin rol',
    );
  }
}

class UnitBadge extends StatelessWidget {
  const UnitBadge({super.key, required this.unitName});

  final String? unitName;

  @override
  Widget build(BuildContext context) {
    return _Badge(icon: Icons.flag_outlined, text: unitName ?? 'Sin unidad');
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.text, this.icon = Icons.circle});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => _Badge(icon: icon, text: text);
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Flexible(child: Text(text, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
