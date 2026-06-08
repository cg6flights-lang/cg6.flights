import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/trash/data/trash_repository.dart';
import 'package:cg6_flights/features/trash/domain/trash_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TrashPage extends ConsumerStatefulWidget {
  const TrashPage({super.key});

  @override
  ConsumerState<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends ConsumerState<TrashPage> {
  List<TrashItem> _items = [];
  bool _loading = true;
  String? _error;
  String? _selectedSection;

  String _t(String key) => AppLocalizations.of(context).t(key);

  static const _sectionIcons = {
    'aircraft': Icons.flight,
    'crew': Icons.groups_2_outlined,
    'routes': Icons.route_outlined,
    'units': Icons.flag_outlined,
    'users': Icons.person_outline,
    'flight_orders': Icons.assignment_outlined,
    'flights': Icons.flight_takeoff,
    'calendar_events': Icons.calendar_month,
    'messages': Icons.mark_unread_chat_alt_outlined,
    'flight_order_profiles': Icons.badge_outlined,
  };

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref
        .read(trashRepositoryProvider)
        .listTrashItems(section: _selectedSection);
    if (!mounted) return;
    switch (result) {
      case AppSuccess(data: final items):
        setState(() {
          _items = items;
          _loading = false;
        });
      case AppFailure(error: final e):
        setState(() {
          _error = e.message;
          _loading = false;
        });
    }
  }

  Future<void> _restoreItem(TrashItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('trash.restore')),
        content: Text(_t('trash.restoreConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t('trash.restore')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await ref.read(trashRepositoryProvider).restoreItem(
      section: item.section,
      id: item.id,
    );
    if (!mounted) return;
    switch (result) {
      case AppSuccess():
        setState(() => _items.remove(item));
      case AppFailure(error: final e):
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _permanentDelete(TrashItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('trash.permanentDelete')),
        content: Text(_t('trash.permanentDeleteConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(_t('trash.permanentDelete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await ref.read(trashRepositoryProvider).permanentlyDeleteItem(
      section: item.section,
      id: item.id,
    );
    if (!mounted) return;
    switch (result) {
      case AppSuccess():
        setState(() => _items.remove(item));
      case AppFailure(error: final e):
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.delete_outline,
                  size: 28, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _t('trash.title'),
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              // Section filter
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  initialValue: null,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: _t('trash.filterAll'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text(_t('trash.filterAll'),
                          style: const TextStyle(fontSize: 13)),
                    ),
                    for (final entry in _sectionIcons.entries)
                      DropdownMenuItem<String>(
                        value: entry.key,
                        child: Row(
                          children: [
                            Icon(entry.value, size: 16),
                            const SizedBox(width: 8),
                            Text(_t('trash.section.${entry.key}'),
                                style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedSection = v);
                    _load();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Content
          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!,
                        style: TextStyle(color: theme.colorScheme.error)),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _load,
                      child: Text(_t('common.retry')),
                    ),
                  ],
                ),
              ),
            )
          else if (_items.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    Text(_t('trash.empty'),
                        style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Card(
                elevation: 1,
                margin: EdgeInsets.zero,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${_items.length} ${_t('trash.title').toLowerCase()}',
                        style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      ..._items.map((item) => _TrashItemTile(
                            item: item,
                            l10n: AppLocalizations.of(context),
                            onRestore: () => _restoreItem(item),
                            onPermanentDelete: () => _permanentDelete(item),
                          )),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrashItemTile extends StatelessWidget {
  const _TrashItemTile({
    required this.item,
    required this.l10n,
    required this.onRestore,
    required this.onPermanentDelete,
  });

  final TrashItem item;
  final AppLocalizations l10n;
  final VoidCallback onRestore;
  final VoidCallback onPermanentDelete;

  static const _sectionIcons = {
    'aircraft': Icons.flight,
    'crew': Icons.groups_2_outlined,
    'routes': Icons.route_outlined,
    'units': Icons.flag_outlined,
    'users': Icons.person_outline,
    'flight_orders': Icons.assignment_outlined,
    'flights': Icons.flight_takeoff,
    'calendar_events': Icons.calendar_month,
    'messages': Icons.mark_unread_chat_alt_outlined,
    'flight_order_profiles': Icons.badge_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = _sectionIcons[item.section] ?? Icons.delete_outline;
    final dateStr =
        '${item.deletedAt.day.toString().padLeft(2, '0')}/${item.deletedAt.month.toString().padLeft(2, '0')}/${item.deletedAt.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Section icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
              ),
              child:
                  Icon(icon, size: 20, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(item.identifier,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: theme.colorScheme.tertiary
                              .withValues(alpha: 0.12),
                        ),
                        child: Text(
                          l10n.t(item.sectionKey),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.tertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(item.secondaryInfo,
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(
                    '${l10n.t('trash.deletedBy')}: $dateStr',
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: onRestore,
                  icon: const Icon(Icons.replay, size: 16),
                  label: Text(l10n.t('trash.restore'),
                      style: const TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onPermanentDelete,
                  icon: const Icon(Icons.delete_forever, size: 18),
                  tooltip: l10n.t('trash.permanentDelete'),
                  visualDensity: VisualDensity.compact,
                  color: Colors.red.withValues(alpha: 0.6),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
