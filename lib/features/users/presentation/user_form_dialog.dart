import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/security/app_role.dart';
import 'package:cg6_flights/features/auth/domain/app_user.dart';
import 'package:cg6_flights/features/units/domain/unit_option.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UserFormResult {
  const UserFormResult({
    required this.email,
    required this.password,
    required this.displayName,
    required this.role,
    required this.unitId,
    required this.status,
    this.firstName,
    this.lastName,
    this.documentType,
    this.documentId,
    this.phoneCountryCode,
    this.phone,
    this.birthDate,
    this.grade,
  });

  final String email;
  final String password;
  final String displayName;
  final AppRole? role;
  final String? unitId;
  final ProfileStatus status;
  final String? firstName;
  final String? lastName;
  final String? documentType;
  final String? documentId;
  final String? phoneCountryCode;
  final String? phone;
  final DateTime? birthDate;
  final String? grade;
}

class UserFormDialog extends StatefulWidget {
  const UserFormDialog({super.key, required this.units, required this.grades});

  final List<UnitOption> units;
  final List<Map<String, String>> grades;

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _documentIdController = TextEditingController();
  final _phoneController = TextEditingController();
  AppRole? _role;
  String? _unitId;
  ProfileStatus _status = ProfileStatus.active;
  String? _grade;
  String? _documentType;
  String _phoneCountryCode = '+51';
  DateTime? _birthDate;
  bool _obscurePassword = true;

  static const _countryCodes = [
    {'code': '+51', 'name': 'Perú'},
    {'code': '+1', 'name': 'USA'},
    {'code': '+52', 'name': 'México'},
    {'code': '+54', 'name': 'Argentina'},
    {'code': '+55', 'name': 'Brasil'},
    {'code': '+56', 'name': 'Chile'},
    {'code': '+57', 'name': 'Colombia'},
    {'code': '+34', 'name': 'España'},
    {'code': '+593', 'name': 'Ecuador'},
    {'code': '+591', 'name': 'Bolivia'},
    {'code': '+595', 'name': 'Paraguay'},
    {'code': '+598', 'name': 'Uruguay'},
    {'code': '+58', 'name': 'Venezuela'},
    {'code': '+44', 'name': 'Reino Unido'},
    {'code': '+49', 'name': 'Alemania'},
    {'code': '+33', 'name': 'Francia'},
    {'code': '+39', 'name': 'Italia'},
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    _documentIdController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    final viewport = MediaQuery.of(context).size;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(t('users.createTitle')),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: viewport.height * 0.72,
        ),
        child: SizedBox(
          width: mathMin(500, viewport.width - 80),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Email
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: t('common.email'),
                      hintText: 'usuario@ejemplo.com',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return t('users.emailRequired');
                      if (!value.contains('@') || !value.contains('.')) {
                        return t('users.emailInvalid');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),

                  _responsivePair(
                    first: TextFormField(
                      controller: _firstNameController,
                      decoration: InputDecoration(
                        labelText: t('common.firstName'),
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-ZáéíóúüñÁÉÍÓÚÜÑ\s]'),
                        ),
                      ],
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? t('users.required')
                          : null,
                    ),
                    second: TextFormField(
                      controller: _lastNameController,
                      decoration: InputDecoration(
                        labelText: t('common.lastName'),
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-ZáéíóúüñÁÉÍÓÚÜÑ\s]'),
                        ),
                      ],
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? t('users.required')
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: t('common.password'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 20,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return t('users.passwordRequired');
                      if (value.length < 6) {
                        return t('users.passwordMinLength');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),

                  // Grade
                  DropdownButtonFormField<String?>(
                    initialValue:
                        _grade != null &&
                            widget.grades.any((g) => g['code'] == _grade)
                        ? _grade
                        : null,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: t('common.grade'),
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Sin grado'),
                      ),
                      for (final g in widget.grades)
                        DropdownMenuItem(
                          value: g['code'],
                          child: Text(g['name'] ?? ''),
                        ),
                    ],
                    onChanged: (v) => setState(() => _grade = v),
                  ),
                  const SizedBox(height: 10),

                  _responsivePair(
                    firstFlex: 0,
                    firstWidth: 132,
                    first: DropdownButtonFormField<String>(
                      initialValue: _documentType,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: t('common.document'),
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'dni', child: Text('DNI')),
                        DropdownMenuItem(
                          value: 'passport',
                          child: Text('Pasaporte'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _documentType = v),
                    ),
                    second: TextFormField(
                      controller: _documentIdController,
                      decoration: InputDecoration(
                        labelText: t('common.documentNumber'),
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z0-9]'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  _responsivePair(
                    firstFlex: 0,
                    firstWidth: 118,
                    first: DropdownButtonFormField<String>(
                      initialValue: _phoneCountryCode,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: t('common.code'),
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 10,
                        ),
                      ),
                      items: _countryCodes
                          .map(
                            (c) => DropdownMenuItem(
                              value: c['code'],
                              child: Text(
                                '${c['code']}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _phoneCountryCode = v ?? '+51'),
                    ),
                    second: TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: t('common.phone'),
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Birth date
                  InkWell(
                    onTap: _pickBirthDate,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: t('common.birthDate'),
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        suffixIcon: Icon(Icons.calendar_today, size: 16),
                      ),
                      child: Text(
                        _birthDate != null
                            ? '${_birthDate!.day.toString().padLeft(2, '0')}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year}'
                            : t('common.selectDate'),
                        style: TextStyle(
                          color: _birthDate != null
                              ? null
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Role
                  DropdownButtonFormField<AppRole?>(
                    initialValue: _role,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: t('common.role'),
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<AppRole?>(
                        value: null,
                        child: Text('Sin rol'),
                      ),
                      for (final r in AppRole.values)
                        DropdownMenuItem<AppRole?>(
                          value: r,
                          child: Text(r.labelEs),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      _role = v;
                      if (v == null || !v.requiresUnit) _unitId = null;
                    }),
                  ),

                  // Unit (conditional)
                  if (_role?.requiresUnit == true) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _unitId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: t('common.unit'),
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      items: [
                        for (final u in widget.units)
                          DropdownMenuItem(
                            value: u.id,
                            child: Text('${u.code} — ${u.name}'),
                          ),
                      ],
                      onChanged: (v) => setState(() => _unitId = v),
                      validator: (v) {
                        if (_role?.requiresUnit == true &&
                            (v == null || v.isEmpty)) {
                          return t('users.roleRequiredUnit');
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 10),

                  // Status
                  DropdownButtonFormField<ProfileStatus>(
                    initialValue: _status,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: t('common.status'),
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: ProfileStatus.values
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(_statusLabel(s)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _status = v ?? ProfileStatus.active),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('common.cancel')),
        ),
        FilledButton(onPressed: _submit, child: Text(t('users.createButton'))),
      ],
    );
  }

  Widget _responsivePair({
    required Widget first,
    required Widget second,
    int firstFlex = 1,
    double? firstWidth,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: 10), second],
          );
        }

        final firstChild = firstWidth != null
            ? SizedBox(width: firstWidth, child: first)
            : Expanded(flex: firstFlex, child: first);
        return Row(
          children: [
            firstChild,
            const SizedBox(width: 10),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  double mathMin(double a, double b) => a < b ? a : b;

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(1990),
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
      helpText: AppLocalizations.of(context).t('common.birthDate'),
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final displayName =
        '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';

    Navigator.of(context).pop(
      UserFormResult(
        email: _emailController.text.trim().toLowerCase(),
        password: _passwordController.text,
        displayName: displayName,
        role: _role,
        unitId: _unitId,
        status: _status,
        firstName: _firstNameController.text.trim().isNotEmpty
            ? _firstNameController.text.trim().toUpperCase()
            : null,
        lastName: _lastNameController.text.trim().isNotEmpty
            ? _lastNameController.text.trim().toUpperCase()
            : null,
        documentType: _documentType,
        documentId: _documentIdController.text.trim().isNotEmpty
            ? _documentIdController.text.trim()
            : null,
        phoneCountryCode: _phoneCountryCode,
        phone: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        birthDate: _birthDate,
        grade: _grade,
      ),
    );
  }

  String _statusLabel(ProfileStatus s) => switch (s) {
    ProfileStatus.pending => AppLocalizations.of(context).t('common.pending'),
    ProfileStatus.active => AppLocalizations.of(context).t('common.active'),
    ProfileStatus.inactive => AppLocalizations.of(context).t('common.inactive'),
    ProfileStatus.rejected => AppLocalizations.of(context).t('common.rejected'),
  };
}
