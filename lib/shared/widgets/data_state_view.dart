import 'package:flutter/material.dart';

enum DataStateKind {
  loading,
  success,
  empty,
  validationError,
  permissionDenied,
  businessError,
  networkError,
  systemError,
  syncPending,
  retryAvailable,
}

class DataStateView extends StatelessWidget {
  const DataStateView({
    super.key,
    required this.kind,
    required this.title,
    this.message,
    this.onRetry,
    this.child,
  });

  final DataStateKind kind;
  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (kind == DataStateKind.success && child != null) return child!;

    final icon = switch (kind) {
      DataStateKind.loading => Icons.radar,
      DataStateKind.empty => Icons.inbox_outlined,
      DataStateKind.permissionDenied => Icons.lock_outline,
      DataStateKind.validationError => Icons.rule,
      DataStateKind.businessError => Icons.report_problem_outlined,
      DataStateKind.networkError => Icons.wifi_off,
      DataStateKind.systemError => Icons.error_outline,
      DataStateKind.syncPending => Icons.sync,
      DataStateKind.retryAvailable => Icons.refresh,
      DataStateKind.success => Icons.check_circle_outline,
    };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (kind == DataStateKind.loading)
                const SizedBox.square(
                  dimension: 34,
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              else
                Icon(icon, size: 42),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
