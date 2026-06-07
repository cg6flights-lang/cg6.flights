import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/audit/data/audit_repository.dart';
import 'package:cg6_flights/features/audit/domain/audit_log.dart';
import 'package:cg6_flights/features/audit/presentation/audit_performance_page.dart';
import 'package:cg6_flights/features/auth/application/session_controller.dart';
import 'package:cg6_flights/shared/widgets/data_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Query & provider ──────────────────────────────────────────────

class _AuditQuery {
  final DateTime? fromDate;
  final DateTime? toDate;
  final String? resourceType;
  final String? result;

  const _AuditQuery({
    this.fromDate,
    this.toDate,
    this.resourceType,
    this.result,
  });

  _AuditQuery copyWith({
    DateTime? fromDate,
    DateTime? toDate,
    String? resourceType,
    String? result,
    bool clearDates = false,
  }) {
    return _AuditQuery(
      fromDate: clearDates ? null : (fromDate ?? this.fromDate),
      toDate: clearDates ? null : (toDate ?? this.toDate),
      resourceType: resourceType ?? this.resourceType,
      result: result ?? this.result,
    );
  }

  bool get hasActiveFilters =>
      fromDate != null ||
      toDate != null ||
      resourceType != null ||
      result != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AuditQuery &&
          fromDate == other.fromDate &&
          toDate == other.toDate &&
          resourceType == other.resourceType &&
          result == other.result;

  @override
  int get hashCode => Object.hash(fromDate, toDate, resourceType, result);
}

final _auditLogsProvider =
    FutureProvider.family<AppResult<List<AuditLog>>, _AuditQuery>(
        (ref, query) {
  final repo = ref.read(auditRepositoryProvider);
  final session = ref.read(sessionControllerProvider);
  final unitId =
      session.user?.role?.isGlobal == true ? null : session.user?.unitId;
  return repo.listAuditLogs(
    unitId: unitId,
    fromDate: query.fromDate,
    toDate: query.toDate,
    resourceType: query.resourceType,
    result: query.result,
  );
});

// ── Block definitions ─────────────────────────────────────────────

enum _AuditBlock { operations, flightManagement, personnel, system }

const _blockMeta = <_AuditBlock, ({String labelEs, String labelEn, IconData icon, Color color, Set<String> types})>{
  _AuditBlock.operations: (
    labelEs: 'Operaciones',
    labelEn: 'Operations',
    icon: Icons.flight,
    color: Color(0xFF1976D2),
    types: {'crew', 'aircraft', 'route'},
  ),
  _AuditBlock.flightManagement: (
    labelEs: 'Gestion de Vuelo',
    labelEn: 'Flight Management',
    icon: Icons.assignment,
    color: Color(0xFF2E7D32),
    types: {'flight_order', 'flights', 'closure'},
  ),
  _AuditBlock.personnel: (
    labelEs: 'Personal',
    labelEn: 'Personnel',
    icon: Icons.people,
    color: Color(0xFFF57F17),
    types: {'user', 'role', 'permission', 'access', 'profile'},
  ),
  _AuditBlock.system: (
    labelEs: 'Sistema',
    labelEn: 'System',
    icon: Icons.settings,
    color: Color(0xFF7B1FA2),
    types: {'auth', 'settings', 'report', 'notification', 'message'},
  ),
};

_AuditBlock _blockForType(String resourceType) {
  for (final entry in _blockMeta.entries) {
    if (entry.value.types.contains(resourceType)) return entry.key;
  }
  return _AuditBlock.system; // fallback
}

String _blockLabel(_AuditBlock block, AppLocalizations l10n) {
  final meta = _blockMeta[block]!;
  return l10n.locale.languageCode == 'es' ? meta.labelEs : meta.labelEn;
}

// ── Helpers ───────────────────────────────────────────────────────

String _resourceTypeLabel(String type) {
  return switch (type) {
    'crew' => 'Tripulacion',
    'aircraft' => 'Aeronaves',
    'unit' => 'Unidades',
    'route' => 'Rutas',
    'flight_order' => 'Ordenes de Vuelo',
    'flights' => 'Vuelos',
    'access' => 'Accesos',
    'auth' => 'Autenticacion',
    'settings' => 'Configuracion',
    'report' => 'Reportes',
    'notification' => 'Notificaciones',
    'message' => 'Mensajes',
    'profile' => 'Perfil',
    'permission' => 'Permisos',
    'role' => 'Roles',
    'user' => 'Usuarios',
    'closure' => 'Cierres',
    _ => type,
  };
}

String _resultLabel(String result, AppLocalizations l10n) {
  return switch (result) {
    'success' => l10n.t('audit.resultSuccess'),
    'denied' => l10n.t('audit.resultDenied'),
    'failed' => l10n.t('audit.resultFailed'),
    _ => result,
  };
}

String _fmtDate(DateTime d) {
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

String _fmtDateTime(DateTime d) {
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String _shortId(String id) => id.length > 8 ? id.substring(0, 8) : id;

IconData _iconForType(String resourceType) {
  return switch (resourceType) {
    'crew' => Icons.people_outline,
    'aircraft' => Icons.flight_outlined,
    'unit' => Icons.business_outlined,
    'route' => Icons.alt_route_outlined,
    'flight_order' => Icons.assignment_outlined,
    'flights' => Icons.airplanemode_active_outlined,
    'access' => Icons.vpn_key_outlined,
    'auth' => Icons.login_outlined,
    'settings' => Icons.settings_outlined,
    'report' => Icons.picture_as_pdf_outlined,
    'notification' => Icons.notifications_outlined,
    'message' => Icons.message_outlined,
    'profile' => Icons.person_outline,
    'permission' => Icons.admin_panel_settings_outlined,
    'role' => Icons.shield_outlined,
    'user' => Icons.people_alt_outlined,
    'closure' => Icons.lock_outline,
    _ => Icons.event_note_outlined,
  };
}

// ── Page ──────────────────────────────────────────────────────────

class AuditPage extends ConsumerStatefulWidget {
  AuditPage({super.key});

  @override
  ConsumerState<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends ConsumerState<AuditPage>
    with TickerProviderStateMixin {
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _resourceType;
  String? _result;
  final Set<String> _expandedTypes = {};
  late final TabController _tabController;

  _AuditQuery get _query => _AuditQuery(
        fromDate: _fromDate,
        toDate: _toDate,
        resourceType: _resourceType,
        result: _result,
      );

  bool get _hasActiveFilters => _query.hasActiveFilters;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _fromDate = null;
      _toDate = null;
      _resourceType = null;
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final auditAsync = ref.watch(_auditLogsProvider(_query));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.fact_check_outlined,
                  color: theme.colorScheme.primary, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(l10n.t('audit.title'),
                    style: theme.textTheme.headlineSmall),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: t('common.refresh'),
                onPressed: () =>
                    ref.invalidate(_auditLogsProvider(_query)),
              ),
            ],
          ),
          SizedBox(height: 12),
          // Tab bar
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: l10n.t('audit.tabEvents')),
              Tab(text: l10n.t('audit.tabPerformance')),
            ],
          ),
          const SizedBox(height: 12),
          // Filter bar (only on events tab)
          _buildFilterBar(l10n),
          if (_hasActiveFilters) ...[
            const SizedBox(height: 8),
            _buildActiveChips(l10n),
          ],
          SizedBox(height: 12),
          // Content
          Expanded(
            child: auditAsync.when(
              loading: () => const DataStateView(
                  kind: DataStateKind.loading, title: ''),
              error: (_, _) => DataStateView(
                kind: DataStateKind.systemError,
                title: l10n.t('audit.loadFailed'),
                message: l10n.t('common.retry'),
                onRetry: () =>
                    ref.invalidate(_auditLogsProvider(_query)),
              ),
              data: (result) {
                final logs = switch (result) {
                  AppSuccess<List<AuditLog>>(data: final list) => list,
                  AppFailure<List<AuditLog>>() => null,
                };

                if (logs == null) {
                  final error =
                      (result as AppFailure<List<AuditLog>>).error;
                  return DataStateView(
                    kind: DataStateKind.systemError,
                    title: l10n.t('audit.loadFailed'),
                    message: error.message,
                    onRetry: () =>
                        ref.invalidate(_auditLogsProvider(_query)),
                  );
                }

                if (logs.isEmpty) {
                  return DataStateView(
                    kind: DataStateKind.empty,
                    title: _hasActiveFilters
                        ? l10n.t('audit.filteredEmpty')
                        : l10n.t('audit.empty'),
                  );
                }

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildEventsTab(logs, theme, l10n),
                    AuditPerformancePage(logs: logs),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter bar ──────────────────────────────────────────────────

  Widget _buildFilterBar(AppLocalizations l10n) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _FilterDropdown(
          label: l10n.t('audit.filterResource'),
          value: _resourceType,
          items: const [
            (null, 'Todos'),
            ('crew', 'Tripulacion'),
            ('aircraft', 'Aeronaves'),
            ('unit', 'Unidades'),
            ('route', 'Rutas'),
            ('flight_order', 'Ordenes de Vuelo'),
            ('flights', 'Vuelos'),
            ('access', 'Accesos'),
            ('auth', 'Autenticacion'),
            ('settings', 'Configuracion'),
            ('report', 'Reportes'),
            ('notification', 'Notificaciones'),
            ('message', 'Mensajes'),
            ('profile', 'Perfil'),
            ('permission', 'Permisos'),
            ('role', 'Roles'),
            ('user', 'Usuarios'),
            ('closure', 'Cierres'),
          ],
          onChanged: (v) => setState(() => _resourceType = v),
        ),
        _FilterDropdown(
          label: l10n.t('audit.filterResult'),
          value: _result,
          items: const [
            (null, 'Todos'),
            ('success', 'Exitoso'),
            ('denied', 'Denegado'),
            ('failed', 'Fallido'),
          ],
          onChanged: (v) => setState(() => _result = v),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDateRangePicker(
              context: context,
              initialDateRange: _fromDate != null && _toDate != null
                  ? DateTimeRange(start: _fromDate!, end: _toDate!)
                  : null,
              firstDate: DateTime(2024),
              lastDate: DateTime.now(),
              helpText: l10n.t('audit.filterDateRange'),
            );
            if (picked != null) {
              setState(() {
                _fromDate = picked.start;
                _toDate = picked.end;
              });
            }
          },
          icon: const Icon(Icons.date_range, size: 18),
          label: Text(_fromDate != null
              ? '${_fmtDate(_fromDate!)} - ${_fmtDate(_toDate!)}'
              : l10n.t('audit.filterDate')),
        ),
        if (_hasActiveFilters)
          TextButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.clear_all, size: 18),
            label: Text(l10n.t('common.cancel')),
          ),
      ],
    );
  }

  Widget _buildActiveChips(AppLocalizations l10n) {
    final chips = <Widget>[];
    if (_resourceType != null) {
      chips.add(Chip(
        label: Text(_resourceTypeLabel(_resourceType!)),
        onDeleted: () => setState(() => _resourceType = null),
      ));
    }
    if (_result != null) {
      chips.add(Chip(
        label: Text(_resultLabel(_result!, l10n)),
        onDeleted: () => setState(() => _result = null),
      ));
    }
    if (_fromDate != null && _toDate != null) {
      chips.add(Chip(
        label:
            Text('${_fmtDate(_fromDate!)} - ${_fmtDate(_toDate!)}'),
        onDeleted: () => setState(() {
          _fromDate = null;
          _toDate = null;
        }),
      ));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, children: chips);
  }

  // ── Events tab: 4 blocks in 2 columns ───────────────────────────

  Widget _buildEventsTab(
      List<AuditLog> logs, ThemeData theme, AppLocalizations l10n) {
    // Group logs by block
    final blockLogs = <_AuditBlock, List<AuditLog>>{};
    for (final log in logs) {
      final block = _blockForType(log.resourceType);
      blockLogs.putIfAbsent(block, () => []).add(log);
    }

    // Sort blocks consistently
    final blocks = _AuditBlock.values.where((b) => blockLogs.containsKey(b));

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        if (wide) {
          return GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 1.8,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: blocks.map((b) {
              return _AuditBlockCard(
                block: b,
                logs: blockLogs[b]!,
                expandedTypes: _expandedTypes,
                onToggleType: (type) {
                  setState(() {
                    if (_expandedTypes.contains(type)) {
                      _expandedTypes.remove(type);
                    } else {
                      _expandedTypes.add(type);
                    }
                  });
                },
                l10n: l10n,
              );
            }).toList(),
          );
        }
        return ListView(
          children: blocks.map((b) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AuditBlockCard(
                block: b,
                logs: blockLogs[b]!,
                expandedTypes: _expandedTypes,
                onToggleType: (type) {
                  setState(() {
                    if (_expandedTypes.contains(type)) {
                      _expandedTypes.remove(type);
                    } else {
                      _expandedTypes.add(type);
                    }
                  });
                },
                l10n: l10n,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ── Filter dropdown ───────────────────────────────────────────────

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<(String?, String)> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    return PopupMenuButton<String?>(
      offset: const Offset(0, 44),
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final item in items)
          PopupMenuItem<String?>(
            value: item.$1,
            child: Row(
              children: [
                if (item.$1 == value)
                  Icon(Icons.check, size: 18)
                else
                  SizedBox(width: 18),
                SizedBox(width: 8),
                Text(item.$2),
              ],
            ),
          ),
      ],
      child: OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.filter_list, size: 18),
        label: Text(value != null
            ? items
                .firstWhere((e) => e.$1 == value,
                    orElse: () => (null, label))
                .$2
            : label),
      ),
    );
  }
}

// ── Block card ────────────────────────────────────────────────────

class _AuditBlockCard extends StatelessWidget {
  const _AuditBlockCard({
    required this.block,
    required this.logs,
    required this.expandedTypes,
    required this.onToggleType,
    required this.l10n,
  });

  final _AuditBlock block;
  final List<AuditLog> logs;
  final Set<String> expandedTypes;
  final ValueChanged<String> onToggleType;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    final theme = Theme.of(context);
    final meta = _blockMeta[block]!;
    final totalCount = logs.length;

    // Sub-group by resource type
    final byType = <String, List<AuditLog>>{};
    for (final log in logs) {
      byType.putIfAbsent(log.resourceType, () => []).add(log);
    }

    return Card(
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Block header
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: meta.color.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(meta.icon, color: meta.color, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _blockLabel(block, l10n),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: meta.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    l10n
                        .t('audit.groupCount')
                        .replaceAll('{count}', totalCount.toString()),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: meta.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Sub-type cards
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(6),
              children: byType.entries.map((entry) {
                final isExpanded = expandedTypes.contains(entry.key);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _AuditTypeCard(
                    resourceType: entry.key,
                    label: _resourceTypeLabel(entry.key),
                    logs: entry.value,
                    isExpanded: isExpanded,
                    blockColor: meta.color,
                    onToggle: () => onToggleType(entry.key),
                    l10n: l10n,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Type card (inside a block) ────────────────────────────────────

class _AuditTypeCard extends StatelessWidget {
  const _AuditTypeCard({
    required this.resourceType,
    required this.label,
    required this.logs,
    required this.isExpanded,
    required this.blockColor,
    required this.onToggle,
    required this.l10n,
  });

  final String resourceType;
  final String label;
  final List<AuditLog> logs;
  final bool isExpanded;
  final Color blockColor;
  final VoidCallback onToggle;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    final theme = Theme.of(context);
    final count = logs.length;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Icon(_iconForType(resourceType),
                      size: 18, color: blockColor),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(label,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500)),
                  ),
                  Text(count.toString(),
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _buildTable(context, theme),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(BuildContext context, ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 700),
        child: DataTable(
          headingRowHeight: 30,
          dataRowMinHeight: 30,
          dataRowMaxHeight: 34,
          headingRowColor:
              WidgetStateProperty.all(blockColor.withValues(alpha: 0.06)),
          columnSpacing: 12,
          columns: [
            DataColumn(label: Text(l10n.t('audit.colAction'), style: _colStyle(theme))),
            DataColumn(label: Text(l10n.t('audit.colResult'), style: _colStyle(theme))),
            DataColumn(label: Text(l10n.t('audit.colDate'), style: _colStyle(theme))),
            DataColumn(label: Text(l10n.t('audit.colActor'), style: _colStyle(theme))),
            DataColumn(label: Text(l10n.t('audit.colIp'), style: _colStyle(theme))),
          ],
          rows: logs.map((log) {
            return DataRow(cells: [
              DataCell(Text(log.action,
                  style: theme.textTheme.bodySmall)),
              DataCell(_resultChip(log.result, theme)),
              DataCell(Text(_fmtDateTime(log.createdAt),
                  style: theme.textTheme.bodySmall)),
              DataCell(Text('${_shortId(log.actorId)} (${log.actorRole})',
                  style: theme.textTheme.bodySmall)),
              DataCell(Text(log.ipAddress ?? '--',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant))),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  TextStyle? _colStyle(ThemeData theme) =>
      theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600);

  Widget _resultChip(String result, ThemeData theme) {
    final color = switch (result) {
      'success' => Colors.green,
      'denied' => Colors.orange,
      'failed' => Colors.red,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _resultLabel(result, l10n),
        style: theme.textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600, fontSize: 10),
      ),
    );
  }
}
