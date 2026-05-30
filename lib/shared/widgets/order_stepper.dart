import 'package:cg6_flights/app/theme/status_colors.dart';
import 'package:flutter/material.dart';

class StepInfo {
  const StepInfo({required this.key, required this.label});
  final String key;
  final String label;
}

class OrderStepper extends StatelessWidget {
  const OrderStepper({
    super.key,
    required this.steps,
    required this.current,
    required this.colorForStatus,
    this.hasObservations = false,
  });

  final List<StepInfo> steps;
  final String current;
  final Color Function(String status) colorForStatus;
  final bool hasObservations;

  static const _orderSteps = [
    StepInfo(key: 'draft', label: 'Borrador'),
    StepInfo(key: 'submitted', label: 'Enviado'),
    StepInfo(key: 'approved', label: 'Aprobado'),
    StepInfo(key: 'closed', label: 'Cerrado'),
  ];

  factory OrderStepper.flightOrder({
    required String currentStatus,
    bool hasObservations = false,
  }) {
    return OrderStepper(
      steps: _orderSteps,
      current: currentStatus,
      colorForStatus: (s) => StatusColors.of(s),
      hasObservations: hasObservations,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isReopened = current == 'reopened';
    final lookup = isReopened ? 'closed' : current;
    final currentIdx = steps.indexWhere((s) => s.key == lookup);
    final effectiveIdx = currentIdx >= 0 ? currentIdx : 0;

    return SizedBox(
      height: 48,
      child: Row(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            if (i > 0) _connector(i <= effectiveIdx),
            _stepDot(steps[i], i, effectiveIdx),
          ],
        ],
      ),
    );
  }

  Widget _connector(bool active) {
    final connectorColor = colorForStatus(steps[0].key);
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: active
            ? connectorColor.withValues(alpha: 0.4)
            : Colors.grey.withValues(alpha: 0.2),
      ),
    );
  }

  Widget _stepDot(StepInfo step, int index, int currentIdx) {
    final completed = index < currentIdx;
    final active = index == currentIdx;
    final isDraftAlert = hasObservations && active && step.key == 'draft';
    final effectiveStatus = isDraftAlert ? 'observed' : step.key;
    final color = active || completed
        ? colorForStatus(effectiveStatus)
        : Colors.grey;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: active ? 28 : 24,
          height: active ? 28 : 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? color.withValues(alpha: 0.15)
                : completed
                    ? color.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.08),
            border: Border.all(
              color: active || completed ? color : Colors.grey.withValues(alpha: 0.3),
              width: active ? 2 : 1.5,
            ),
          ),
          child: Center(
            child: completed
                ? Icon(Icons.check, size: 14, color: color)
                : active && isDraftAlert
                    ? Icon(Icons.warning_amber_rounded, size: 16, color: color)
                    : active
                        ? Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                            ),
                          )
                        : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          step.label,
          style: TextStyle(
            fontSize: 11,
            color: active || completed
                ? color
                : Colors.grey,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
