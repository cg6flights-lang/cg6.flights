import 'package:flutter/material.dart';

enum StatusChipSize { small, medium }

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.size = StatusChipSize.small,
    this.icon,
  });

  final String label;
  final Color color;
  final StatusChipSize size;
  final IconData? icon;

  static const _statusColors = <String, Color>{
    'draft': Colors.grey,
    'submitted': Colors.blue,
    'observed': Colors.orange,
    'approved': Colors.green,
    'closed': Colors.red,
    'reopened': Colors.purple,
    'waiting': Colors.grey,
    'taxi': Colors.blue,
    'takeoff': Colors.orange,
    'landing': Colors.teal,
    'engine_off': Colors.green,
    'cancelled': Colors.red,
    'operational': Colors.green,
    'inoperative': Colors.red,
    'maintenance': Colors.orange,
  };

  factory StatusChip.fromStatus(String status, {StatusChipSize size = StatusChipSize.small}) {
    final color = _statusColors[status] ?? Colors.grey;
    return StatusChip(label: _labelFor(status), color: color, size: size);
  }

  static String _labelFor(String status) {
    return switch (status) {
      'draft' => 'Borrador',
      'submitted' => 'Enviado',
      'observed' => 'Observado',
      'approved' => 'Aprobado',
      'closed' => 'Cerrado',
      'reopened' => 'Reabierto',
      'waiting' => 'Espera',
      'taxi' => 'Taxeo',
      'takeoff' => 'Despegue',
      'landing' => 'Aterrizaje',
      'engine_off' => 'Motor Apagado',
      'cancelled' => 'Cancelado',
      _ => status,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isSmall = size == StatusChipSize.small;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 8 : 12,
        vertical: isSmall ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(isSmall ? 12 : 16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: isSmall ? 12 : 16, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: isSmall ? 12 : 13,
              color: color,
              fontWeight: isSmall ? FontWeight.normal : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
