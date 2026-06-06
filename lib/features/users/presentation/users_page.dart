import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/core/security/app_permission.dart' show rolePermissionMatrix;
import 'package:cg6_flights/core/security/app_role.dart';
import 'package:cg6_flights/features/auth/domain/app_user.dart';
import 'package:cg6_flights/features/units/domain/unit_option.dart';
import 'package:cg6_flights/features/users/data/users_repository.dart';
import 'package:cg6_flights/features/users/domain/managed_profile.dart';
import 'package:cg6_flights/features/users/domain/user_permissions.dart';
import 'package:cg6_flights/shared/widgets/app_badges.dart';
import 'package:cg6_flights/shared/widgets/data_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});
  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  List<ManagedProfile> _profiles = [];
  List<UnitOption> _units = [];
  bool _loading = true;
  String? _errorMsg;
  ManagedProfile? _selected;

  // Editable fields for selected user
  AppRole? _editRole;
  String? _editUnitId;
  ProfileStatus _editStatus = ProfileStatus.active;
  Set<String> _editPermissions = {};
  bool _saving = false;
  String? _saveError;

  bool _permissionsExpanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _errorMsg = null; });
    final repo = ref.read(usersRepositoryProvider);
    final profiles = await repo.listProfiles();
    final units = await repo.listUnits();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (profiles case AppSuccess(data: final p)) { _profiles = p; } else if (profiles case AppFailure(error: final e)) { _errorMsg = e.message; }
      if (units case AppSuccess(data: final u)) { _units = u; } else { _units = []; }
    });
  }

  void _selectProfile(ManagedProfile p) {
    setState(() {
      _selected = p;
      _editRole = p.role;
      _editUnitId = p.unitId;
      _editStatus = p.status;
      _editPermissions = p.role != null ? Set<String>.from(rolePermissionMatrix[p.role] ?? {}) : {};
      _saveError = null;
      _permissionsExpanded = false;
    });
  }

  Future<void> _save() async {
    if (_selected == null) return;
    if (_editRole?.requiresUnit == true && _editUnitId == null) {
      setState(() => _saveError = 'El rol seleccionado requiere una unidad.');
      return;
    }
    setState(() { _saving = true; _saveError = null; });
    final result = await ref.read(usersRepositoryProvider).assignAccess(
      userId: _selected!.id,
      role: _editRole,
      unitId: _editUnitId,
      status: _editStatus,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case AppSuccess(): _load();
      case AppFailure(error: final e): setState(() => _saveError = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = MediaQuery.of(context).size.width >= 1100;

    if (_loading) return const DataStateView(kind: DataStateKind.loading, title: '');
    if (_errorMsg != null) return DataStateView(kind: DataStateKind.systemError, title: _errorMsg!, onRetry: _load);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.08),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 320, child: _buildUserList(theme)),
                  Container(width: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
                  Expanded(child: _buildDetailPanel(theme)),
                ])
              : Column(children: [
                  SizedBox(height: 300, child: _buildUserList(theme)),
                  const Divider(height: 1),
                  _selected != null
                      ? Expanded(child: _buildDetailPanel(theme))
                      : const SizedBox(height: 120, child: Center(child: Text('Selecciona un usuario para ver sus permisos', style: TextStyle(color: Colors.grey)))),
                ]),
        ),
      ),
    );
  }

  Widget _buildUserList(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(children: [
            Text('Usuarios', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.refresh, size: 18, color: theme.colorScheme.primary),
              tooltip: 'Actualizar',
              onPressed: _load,
              style: IconButton.styleFrom(
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(36, 36),
              ),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: () {
            // Group by role
            final grouped = <String, List<ManagedProfile>>{};
            for (final p in _profiles) {
              final key = p.role?.labelEs ?? 'Sin rol';
              grouped.putIfAbsent(key, () => []).add(p);
            }
            final order = ['Líder', 'Administrador General', 'Comando de Unidad', 'Administrador de Unidad', 'TTAA', 'Sin rol'];
            final keys = grouped.keys.toList()..sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: keys.length,
              itemBuilder: (context, sectionIndex) {
                final key = keys[sectionIndex];
                final users = grouped[key]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text('$key · ${users.length}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: theme.colorScheme.primary, letterSpacing: 0.5)),
                    ),
                    for (final profile in users)
                      _UserListTile(
                        profile: profile,
                        selected: _selected?.id == profile.id,
                        onTap: () => _selectProfile(profile),
                        theme: theme,
                      ),
                  ],
                );
              },
            );
          }(),
        ),
      ],
    );
  }

  Widget _buildDetailPanel(ThemeData theme) {
    if (_selected == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.admin_panel_settings, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('Selecciona un usuario', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 16)),
            const SizedBox(height: 4),
            Text('para ver sus permisos y autorizaciones',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 13)),
          ],
        ),
      );
    }

    final p = _selected!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // User info header
          Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(
                  p.displayName[0].toUpperCase(),
                  style: TextStyle(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w800, fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.displayName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                Text(p.email, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
              ]),
            ),
            if (p.role != null) RoleBadge(role: p.role),
          ]),
          const SizedBox(height: 16),

          // Role dropdown
          _buildDropdown<AppRole?>(
            label: 'Rol',
            value: _editRole,
            items: [null, ...AppRole.values],
            itemLabel: (r) => r?.labelEs ?? 'Sin rol',
            onChanged: (v) {
              setState(() {
                _editRole = v;
                _editPermissions = v != null ? Set<String>.from(rolePermissionMatrix[v] ?? {}) : {};
              });
            },
          ),
          const SizedBox(height: 8),

          // Unit dropdown (conditional)
          if (_editRole?.requiresUnit == true) ...[
            _buildDropdown<String?>(
              label: 'Unidad',
              value: _editUnitId,
              items: [null, ..._units.map((u) => u.id)],
              itemLabel: (id) {
                if (id == null) return 'Sin unidad';
                final u = _units.firstWhere((x) => x.id == id, orElse: () => _units.first);
                return '${u.code} - ${u.name}';
              },
              onChanged: (v) => setState(() => _editUnitId = v),
            ),
            const SizedBox(height: 8),
          ],

          // Status dropdown
          _buildDropdown<ProfileStatus>(
            label: 'Estado',
            value: _editStatus,
            items: ProfileStatus.values,
            itemLabel: (s) => s?.name ?? '',
            onChanged: (v) => setState(() => _editStatus = v ?? ProfileStatus.active),
          ),
          const SizedBox(height: 12),

          // Save button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save, size: 18),
              label: Text(_saving ? 'Guardando...' : 'Guardar Cambios'),
            ),
          ),
          if (_saveError != null) ...[
            const SizedBox(height: 8),
            Text(_saveError!, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
          ],

          const SizedBox(height: 20),

          // Permissions section
          if (_editRole == AppRole.leader)
            _buildLeaderCard(theme)
          else
            _buildPermissionsSection(theme),
        ],
      ),
    );
  }

  Widget _buildLeaderCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
      ),
      child: Column(children: [
        Icon(Icons.shield, size: 36, color: theme.colorScheme.primary),
        const SizedBox(height: 8),
        Text('Acceso Total — Líder', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
        const SizedBox(height: 4),
        Text('El Líder tiene acceso completo al sistema (38 autorizaciones). No se requiere configuración de permisos.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
      ]),
    );
  }

  Widget _buildPermissionsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
            child: Text('Permisos y Autorizaciones', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
            ),
            child: Text('${_editPermissions.length}/38', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(_permissionsExpanded ? Icons.unfold_less : Icons.unfold_more, size: 18),
            onPressed: () => setState(() => _permissionsExpanded = !_permissionsExpanded),
            visualDensity: VisualDensity.compact,
            tooltip: _permissionsExpanded ? 'Colapsar todo' : 'Expandir todo',
          ),
        ]),
        const SizedBox(height: 12),
        for (final section in permissionSections)
          _PermissionSectionCard(
            section: section,
            granted: _editPermissions,
            expanded: _permissionsExpanded,
            onToggle: (key) => setState(() {
              if (_editPermissions.contains(key)) { _editPermissions.remove(key); } else { _editPermissions.add(key); }
            }),
            theme: theme,
          ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T?> items,
    required String Function(T?) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: items.contains(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: items.map((item) => DropdownMenuItem<T>(
        value: item,
        child: Text(itemLabel(item), style: const TextStyle(fontSize: 13)),
      )).toList(),
      onChanged: onChanged,
    );
  }
}

// ── User List Tile ─────────────────────────────────────────────────────

class _UserListTile extends StatelessWidget {
  const _UserListTile({
    required this.profile,
    required this.selected,
    required this.onTap,
    required this.theme,
  });

  final ManagedProfile profile;
  final bool selected;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Material(
        color: selected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.62)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              // Avatar
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    profile.displayName[0].toUpperCase(),
                    style: TextStyle(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Name and email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.displayName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(profile.email, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Permission Section Card ────────────────────────────────────────────

class _PermissionSectionCard extends StatefulWidget {
  const _PermissionSectionCard({
    required this.section,
    required this.granted,
    required this.expanded,
    required this.onToggle,
    required this.theme,
  });

  final PermissionSection section;
  final Set<String> granted;
  final bool expanded;
  final ValueChanged<String> onToggle;
  final ThemeData theme;

  @override
  State<_PermissionSectionCard> createState() => _PermissionSectionCardState();
}

class _PermissionSectionCardState extends State<_PermissionSectionCard> {
  bool _localExpanded = false;

  @override
  Widget build(BuildContext context) {
    final effectiveExpanded = widget.expanded || _localExpanded;
    final active = widget.section.activeCount(widget.granted);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: widget.theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(children: [
        // Header
        InkWell(
          onTap: () => setState(() => _localExpanded = !_localExpanded),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.section.title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(widget.section.description,
                    style: TextStyle(fontSize: 12, color: widget.theme.colorScheme.onSurfaceVariant)),
                ]),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: widget.theme.colorScheme.primary.withValues(alpha: 0.1),
                ),
                child: Text(
                  '$active/${widget.section.total}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: widget.theme.colorScheme.primary),
                ),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: effectiveExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.expand_more, size: 20),
              ),
            ]),
          ),
        ),
        // Content
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _buildPermissionList(),
          crossFadeState: effectiveExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ]),
    );
  }

  Widget _buildPermissionList() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Column(children: [
        const Divider(height: 1),
        for (final perm in widget.section.permissions)
          CheckboxListTile(
            value: widget.granted.contains(perm.key),
            onChanged: (_) => widget.onToggle(perm.key),
            dense: true,
            title: Text(perm.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text(perm.description, style: TextStyle(fontSize: 11, color: widget.theme.colorScheme.onSurfaceVariant)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
      ]),
    );
  }
}
