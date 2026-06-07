import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/core/security/app_permission.dart';
import 'package:cg6_flights/features/auth/application/session_controller.dart';
import 'package:cg6_flights/features/units/data/units_repository.dart';
import 'package:cg6_flights/features/units/domain/unit_option.dart';
import 'package:cg6_flights/shared/widgets/app_badges.dart';
import 'package:cg6_flights/shared/widgets/data_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UnitsPage extends ConsumerStatefulWidget {
  const UnitsPage({super.key});

  @override
  ConsumerState<UnitsPage> createState() => _UnitsPageState();
}

class _UnitsPageState extends ConsumerState<UnitsPage> {
  String _t(String key) => AppLocalizations.of(context).t(key);

  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  var _active = true;
  UnitOption? _editing;
  var _loading = true;
  var _saving = false;
  String? _error;
  List<UnitOption> _units = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ref.read(unitsRepositoryProvider).listUnits();
    if (!mounted) return;

    switch (result) {
      case AppSuccess<List<UnitOption>>(data: final units):
        setState(() {
          _units = units;
          _loading = false;
        });
      case AppFailure<List<UnitOption>>(error: final error):
        setState(() {
          _error = error.message;
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref
        .watch(sessionControllerProvider)
        .can(AppPermission.unitsManage);

    if (_loading) {
      return DataStateView(
        kind: DataStateKind.loading,
        title: _t('misc.loadingUnits'),
      );
    }

    if (_error != null) {
      return DataStateView(
        kind: DataStateKind.systemError,
        title: _t('misc.routeNotFound'),
        message: _error,
        onRetry: _load,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            const Icon(Icons.flag_outlined, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Unidades',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton(
              tooltip: _t('common.refresh'),
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Crea y administra unidades operativas. Los cambios pasan por permisos, Edge Function y auditoria.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 20),
        if (canManage)
          _UnitFormCard(
            codeController: _codeController,
            nameController: _nameController,
            active: _active,
            editing: _editing,
            saving: _saving,
            onActiveChanged: (value) => setState(() => _active = value),
            onCancel: _clearForm,
            onSave: _save,
          )
        else
          DataStateView(
            kind: DataStateKind.permissionDenied,
            title: _t('units.noPermissionTitle'),
            message: _t('units.noPermissionMsg'),
          ),
        const SizedBox(height: 20),
        if (_units.isEmpty)
          DataStateView(
            kind: DataStateKind.empty,
            title: _t('units.emptyTitle'),
            message: _t('units.emptyMsg'),
          )
        else
          for (final unit in _units) ...[
            _UnitCard(
              unit: unit,
              canManage: canManage,
              onEdit: () => _edit(unit),
              onDeactivate: unit.active ? () => _deactivate(unit) : null,
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  void _edit(UnitOption unit) {
    setState(() {
      _editing = unit;
      _codeController.text = unit.code;
      _nameController.text = unit.name;
      _active = unit.active;
      _error = null;
    });
  }

  void _clearForm() {
    setState(() {
      _editing = null;
      _codeController.clear();
      _nameController.clear();
      _active = true;
      _error = null;
    });
  }

  Future<void> _save() async {
    final code = _codeController.text.trim();
    final name = _nameController.text.trim();
    if (code.isEmpty || name.isEmpty) {
      setState(() => _error = 'Codigo y nombre son obligatorios.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final result = await ref
        .read(unitsRepositoryProvider)
        .saveUnit(
          unitId: _editing?.id,
          code: code,
          name: name,
          active: _active,
        );

    if (!mounted) return;

    switch (result) {
      case AppSuccess<void>():
        _clearForm();
        await _load();
      case AppFailure<void>(error: final error):
        setState(() {
          _error = error.message;
          _saving = false;
        });
    }
  }

  Future<void> _deactivate(UnitOption unit) async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final result = await ref
        .read(unitsRepositoryProvider)
        .deactivateUnit(unit.id);
    if (!mounted) return;

    switch (result) {
      case AppSuccess<void>():
        await _load();
      case AppFailure<void>(error: final error):
        setState(() {
          _error = error.message;
          _saving = false;
        });
    }
  }
}

class _UnitFormCard extends StatelessWidget {
  const _UnitFormCard({
    required this.codeController,
    required this.nameController,
    required this.active,
    required this.editing,
    required this.saving,
    required this.onActiveChanged,
    required this.onCancel,
    required this.onSave,
  });

  final TextEditingController codeController;
  final TextEditingController nameController;
  final bool active;
  final UnitOption? editing;
  final bool saving;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              editing == null ? t('units.create') : t('units.edit'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: t('units.code'),
                      prefixIcon: const Icon(Icons.tag),
                    ),
                  ),
                ),
                SizedBox(
                  width: 340,
                  child: TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: t('units.name'),
                      prefixIcon: const Icon(Icons.flag_outlined),
                    ),
                  ),
                ),
                FilterChip(
                  selected: active,
                  avatar: Icon(
                    active ? Icons.check_circle : Icons.pause_circle,
                  ),
                  label: Text(active ? 'Activa' : 'Inactiva'),
                  onSelected: saving ? null : onActiveChanged,
                ),
                FilledButton.icon(
                  onPressed: saving ? null : onSave,
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(editing == null ? 'Crear' : 'Guardar'),
                ),
                if (editing != null)
                  OutlinedButton.icon(
                    onPressed: saving ? null : onCancel,
                    icon: const Icon(Icons.close),
                    label: const Text('Cancelar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({
    required this.unit,
    required this.canManage,
    required this.onEdit,
    this.onDeactivate,
  });

  final UnitOption unit;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unit.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StatusBadge(text: unit.code, icon: Icons.tag),
                      StatusBadge(
                        text: unit.active ? 'Activa' : 'Inactiva',
                        icon: unit.active
                            ? Icons.check_circle_outline
                            : Icons.pause_circle_outline,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (canManage) ...[
              IconButton(
                tooltip: AppLocalizations.of(context).t('units.edit'),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: AppLocalizations.of(context).t('units.deactivate'),
                onPressed: onDeactivate,
                icon: const Icon(Icons.block),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
