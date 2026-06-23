import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/app/theme/status_colors.dart';
import 'package:cg6_flights/features/aircraft/domain/aircraft.dart';
import 'package:flutter/material.dart';

/// Small reusable aircraft-page widgets with no dependencies on other
/// aircraft widgets (base layer of the aircraft feature UI).

class AircraftEmptyState extends StatelessWidget {
  const AircraftEmptyState({
    super.key,
    required this.canManage,
    required this.onAdd,
  });

  final bool canManage;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.flight_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.t('aircraft.empty'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (canManage) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: Text(l10n.t('aircraft.add')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class InoperativeAircraftRow extends StatelessWidget {
  const InoperativeAircraftRow({
    super.key,
    required this.aircraft,
    required this.noReasonLabel,
  });

  final Aircraft aircraft;
  final String noReasonLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reason = aircraft.inoperativeReason?.trim();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: StatusColors.aircraft['inoperative']!.withValues(alpha: 0.25),
        ),
        color: StatusColors.aircraft['inoperative']!.withValues(alpha: 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  aircraft.displayTailNumber,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                aircraft.model,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            reason == null || reason.isEmpty ? noReasonLabel : reason,
            style: theme.textTheme.bodySmall?.copyWith(
              color: StatusColors.aircraft['inoperative'],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class ModelCardGroup extends StatelessWidget {
  const ModelCardGroup({
    super.key,
    required this.model,
    required this.aircraft,
    required this.canManage,
    this.onTap,
    this.onEdit,
  });
  final String model;
  final List<Aircraft> aircraft;
  final bool canManage;
  final void Function(Aircraft)? onTap;
  final void Function(Aircraft)? onEdit;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ops = aircraft.where((a) => a.status == 'operational').length;
    final inop = aircraft.length - ops;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.flight,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    model,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.green.withValues(alpha: 0.1),
                    ),
                    child: Text(
                      '$ops ops',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  if (inop > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: Colors.red.withValues(alpha: 0.1),
                      ),
                      child: Text(
                        '$inop inop',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in aircraft)
                    InkWell(
                      onTap: onTap != null ? () => onTap!(a) : null,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 96,
                        constraints: const BoxConstraints(minHeight: 44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                (a.status == 'operational'
                                        ? Colors.green
                                        : Colors.red)
                                    .withValues(alpha: 0.4),
                          ),
                          color:
                              (a.status == 'operational'
                                      ? Colors.green
                                      : Colors.red)
                                  .withValues(alpha: 0.05),
                        ),
                        child: Center(
                          child: Text(
                            a.displayTailNumber,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SmallMetaChip extends StatelessWidget {
  const SmallMetaChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
