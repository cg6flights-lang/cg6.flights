import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/auth/application/session_controller.dart';
import 'package:cg6_flights/features/crew/data/grades_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _documentIdController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _grade;
  String? _documentType;
  String _phoneCountryCode = '+51';
  DateTime? _birthDate;
  List<Map<String, String>> _grades = [];

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
    {'code': '+507', 'name': 'Panamá'},
    {'code': '+506', 'name': 'Costa Rica'},
    {'code': '+503', 'name': 'El Salvador'},
    {'code': '+502', 'name': 'Guatemala'},
    {'code': '+504', 'name': 'Honduras'},
    {'code': '+505', 'name': 'Nicaragua'},
    {'code': '+58', 'name': 'Venezuela'},
    {'code': '+44', 'name': 'Reino Unido'},
    {'code': '+49', 'name': 'Alemania'},
    {'code': '+33', 'name': 'Francia'},
    {'code': '+39', 'name': 'Italia'},
  ];

  @override
  void initState() {
    super.initState();
    _loadGrades();
  }

  Future<void> _loadGrades() async {
    final result = await ref.read(gradesRepositoryProvider).listGrades();
    if (mounted) {
      setState(() {
        _grades = switch (result) {
          AppSuccess(data: final list) =>
            list.map((g) => {'code': g.code, 'name': g.code}).toList(),
          _ => [],
        };
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _documentIdController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    final session = ref.watch(sessionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: t('auth.back'),
          onPressed: () => context.go('/login'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(t('auth.register')),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Grade
                  DropdownButtonFormField<String?>(
                    initialValue:
                        _grade != null &&
                            _grades.any((g) => g['code'] == _grade)
                        ? _grade
                        : null,
                    isExpanded: true,
                    decoration: InputDecoration(
              labelText: t('common.grade'),
                      prefixIcon: Icon(Icons.military_tech_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(t('common.noGrade')),
                      ),
                      for (final g in _grades)
                        DropdownMenuItem(
                          value: g['code'],
                          child: Text(g['name'] ?? ''),
                        ),
                    ],
                    onChanged: (v) => setState(() => _grade = v),
                  ),
                  const SizedBox(height: 12),

                  // First name
                  TextFormField(
                    controller: _firstNameController,
                    decoration: InputDecoration(
                      labelText: t('common.firstName'),
                      prefixIcon: const Icon(Icons.person_outline),
                      border: const OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-ZáéíóúüñÁÉÍÓÚÜÑ\s]'),
                      ),
                    ],
                    validator: _required,
                  ),
                  const SizedBox(height: 12),

                  // Last name
                  TextFormField(
                    controller: _lastNameController,
                    decoration: InputDecoration(
                      labelText: t('common.lastName'),
                      prefixIcon: const Icon(Icons.person_outline),
                      border: const OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-ZáéíóúüñÁÉÍÓÚÜÑ\s]'),
                      ),
                    ],
                    validator: _required,
                  ),
                  const SizedBox(height: 12),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: t('auth.email'),
                      prefixIcon: const Icon(Icons.mail_outline),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return t('common.required');
                      if (!value.contains('@') || !value.contains('.')) {
                        return t('users.emailInvalid');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: t('auth.password'),
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      hintText: t('common.minChars6'),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return t('common.required');
                      }
                      if (v.length < 6) return t('common.minChars6');
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Document type + ID
                  Row(
                    children: [
                      SizedBox(
                        width: 130,
                        child: DropdownButtonFormField<String>(
                          initialValue: _documentType,
                          isExpanded: true,
                          decoration: InputDecoration(
              labelText: t('common.document'),
                            border: OutlineInputBorder(),
                            isDense: true,
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
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _documentIdController,
                          decoration: InputDecoration(
              labelText: t('common.documentNumber'),
                            border: OutlineInputBorder(),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9]'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Phone country code + number
                  Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: DropdownButtonFormField<String>(
                          initialValue: _phoneCountryCode,
                          isExpanded: true,
                          decoration: InputDecoration(
              labelText: t('common.code'),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _countryCodes
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c['code'],
                                  child: Text(
                                    '${c['code']}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _phoneCountryCode = v ?? '+51'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          decoration: InputDecoration(
              labelText: t('common.phone'),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Birth date
                  InkWell(
                    onTap: _pickBirthDate,
                    child: InputDecorator(
                      decoration: InputDecoration(
              labelText: t('common.birthDate'),
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(
                        _birthDate != null
                            ? '${_birthDate!.day.toString().padLeft(2, '0')}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year}'
                            : t('common.selectDate'),
                        style: TextStyle(
                          color: _birthDate != null
                              ? null
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit
                  FilledButton.icon(
                    onPressed: session.isLoading ? null : _submit,
                    icon: const Icon(Icons.person_add_alt),
                    label: Text(t('auth.register')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return AppLocalizations.of(context).t('common.required');
    return null;
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(1990),
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
      helpText: AppLocalizations.of(context).t('common.selectDate'),
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final displayName =
        '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';

    await ref
        .read(sessionControllerProvider.notifier)
        .register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: displayName,
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
        );
  }
}
