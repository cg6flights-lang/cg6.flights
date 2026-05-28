import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/core/security/app_permission.dart' show rolePermissionMatrix;
import 'package:cg6_flights/core/security/app_role.dart';
import 'package:cg6_flights/features/auth/domain/app_user.dart';
import 'package:cg6_flights/features/units/domain/unit_option.dart';
import 'package:cg6_flights/features/users/data/users_repository.dart';
import 'package:cg6_flights/features/users/domain/managed_profile.dart';
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
  var _loading = true;
  String? _error;
  List<ManagedProfile> _profiles = [];
  List<UnitOption> _units = [];

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

    final repository = ref.read(usersRepositoryProvider);
    final usersResult = await repository.listProfiles();
    final unitsResult = await repository.listUnits();

    if (!mounted) return;

    switch ((usersResult, unitsResult)) {
      case (
        AppSuccess<List<ManagedProfile>>(data: final profiles),
        AppSuccess<List<UnitOption>>(data: final units),
      ):
        setState(() {
          _profiles = profiles;
          _units = units;
          _loading = false;
        });
      case (AppFailure<List<ManagedProfile>>(error: final error), _):
        setState(() {
          _error = error.message;
          _loading = false;
        });
      case (_, AppFailure<List<UnitOption>>(error: final error)):
        setState(() {
          _error = error.message;
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const DataStateView(
        kind: DataStateKind.loading,
        title: 'Cargando usuarios',
      );
    }

    if (_error != null) {
      return DataStateView(
        kind: DataStateKind.systemError,
        title: 'No se pudo cargar usuarios',
        message: _error,
        onRetry: _load,
      );
    }

    if (_profiles.isEmpty) {
      return DataStateView(
        kind: DataStateKind.empty,
        title: 'Sin usuarios',
        message: 'Los usuarios registrados apareceran aqui.',
        onRetry: _load,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            const Icon(Icons.people_alt_outlined, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Usuarios',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Activa usuarios, asigna rol y unidad. Cada cambio pasa por Edge Function y queda auditado.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 20),
        for (final profile in _profiles) ...[
          _UserAccessCard(profile: profile, units: _units, onSaved: _load),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _UserAccessCard extends ConsumerStatefulWidget {
  const _UserAccessCard({
    required this.profile,
    required this.units,
    required this.onSaved,
  });

  final ManagedProfile profile;
  final List<UnitOption> units;
  final Future<void> Function() onSaved;

  @override
  ConsumerState<_UserAccessCard> createState() => _UserAccessCardState();
}

class _UserAccessCardState extends ConsumerState<_UserAccessCard> {
  AppRole? _role;
  ProfileStatus _status = ProfileStatus.pending;
  String? _unitId;
  var _saving = false;
  String? _error;
  var _showAllPermissions = false;

  @override
  void initState() {
    super.initState();
    _role = widget.profile.role;
    _status = widget.profile.status;
    _unitId = widget.profile.unitId;
  }

  @override
  Widget build(BuildContext context) {
    final unitRequired = _role?.requiresUnit ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.profile.displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(widget.profile.email),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                RoleBadge(role: widget.profile.role),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<AppRole?>(
                    initialValue: _role,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Rol',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<AppRole?>(
                        value: null,
                        child: Text('Sin rol'),
                      ),
                      for (final role in AppRole.values)
                        DropdownMenuItem<AppRole?>(
                          value: role,
                          child: Text(role.labelEs),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) {
                            setState(() {
                              _role = value;
                              if (!(value?.requiresUnit ?? false)) {
                                _unitId = null;
                              }
                            });
                          },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<ProfileStatus>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Estado'),
                    items: [
                      for (final status in ProfileStatus.values)
                        DropdownMenuItem(
                          value: status,
                          child: Text(status.labelEs),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() => _status = value);
                          },
                  ),
                ),
                SizedBox(
                  width: 300,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _unitId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: unitRequired ? 'Unidad requerida' : 'Unidad',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Sin unidad'),
                      ),
                      for (final unit in widget.units)
                        DropdownMenuItem<String?>(
                          value: unit.id,
                          child: Text('${unit.code} - ${unit.name}'),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _unitId = value),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Guardar'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _PermissionsPreview(role: _role, expanded: _showAllPermissions),
            if ((rolePermissionMatrix[_role]?.length ?? 0) > 8)
              TextButton.icon(
                onPressed: () =>
                    setState(() => _showAllPermissions = !_showAllPermissions),
                icon: Icon(
                  _showAllPermissions
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                ),
                label: Text(
                  _showAllPermissions ? 'Mostrar menos' : 'Mostrar todos',
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if ((_role?.requiresUnit ?? false) && _unitId == null) {
      setState(() => _error = 'Este rol requiere unidad.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final result = await ref
        .read(usersRepositoryProvider)
        .assignAccess(
          userId: widget.profile.id,
          role: _role,
          unitId: _unitId,
          status: _status,
        );

    if (!mounted) return;

    switch (result) {
      case AppSuccess<void>():
        await widget.onSaved();
      case AppFailure<void>(error: final error):
        setState(() {
          _error = error.message;
          _saving = false;
        });
    }
  }
}

class _PermissionsPreview extends StatelessWidget {
  const _PermissionsPreview({required this.role, required this.expanded});

  final AppRole? role;
  final bool expanded;

  String _formatPermission(String perm) {
    final parts = perm.split('.');
    if (parts.length == 2) {
      return '${parts[0]}: ${parts[1]}';
    }
    return perm;
  }

  @override
  Widget build(BuildContext context) {
    if (role == null) {
      return Text(
        'Sin rol asignado — sin permisos',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
      );
    }

    if (role == AppRole.leader) {
      return Chip(
        avatar: Icon(Icons.shield, size: 16, color: Theme.of(context).colorScheme.primary),
        label: const Text('Todos los permisos'),
        visualDensity: VisualDensity.compact,
      );
    }

    final permissions = rolePermissionMatrix[role]!;
    final displayPerms = expanded ? permissions.toList() : permissions.take(8).toList();
    final remaining = permissions.length - displayPerms.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Permisos del rol:',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final perm in displayPerms)
              Chip(
                label: Text(
                  _formatPermission(perm),
                  style: const TextStyle(fontSize: 11),
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            if (!expanded && remaining > 0)
              ActionChip(
                label: Text('+$remaining mas', style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onPressed: () {},
              ),
          ],
        ),
      ],
    );
  }
}
