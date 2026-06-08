import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/auth/application/session_controller.dart';
import 'package:cg6_flights/features/auth/data/auth_repository.dart';
import 'package:cg6_flights/features/auth/domain/app_user.dart';
import 'package:cg6_flights/features/crew/data/grades_repository.dart';
import 'package:cg6_flights/shared/widgets/profile_avatar_picker.dart';
import 'package:cg6_flights/shared/widgets/password_strength_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showProfileModal(BuildContext context, AppUser user) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _ProfileModal(user: user),
  );
}

class _ProfileModal extends ConsumerStatefulWidget {
  const _ProfileModal({required this.user});

  final AppUser user;

  @override
  ConsumerState<_ProfileModal> createState() => _ProfileModalState();
}

class _ProfileModalState extends ConsumerState<_ProfileModal> {
  String _t(String key) => AppLocalizations.of(context).t(key);

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _documentIdController;
  late final TextEditingController _phoneController;

  // Password
  final _pwFormKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // State
  String? _grade;
  String? _documentType;
  String? _phoneCountryCode;
  DateTime? _birthDate;
  String? _avatarUrl;
  bool _savingProfile = false;
  bool _changingPassword = false;
  bool _uploadingPhoto = false;
  String? _profileError;
  String? _photoError;
  String? _passwordError;
  String? _passwordSuccess;
  List<Map<String, String>> _grades = [];

  bool _profileExpanded = true;
  bool _passwordExpanded = false;

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
    final u = widget.user;
    _firstNameController = TextEditingController(text: u.firstName ?? '');
    _lastNameController = TextEditingController(text: u.lastName ?? '');
    _documentIdController = TextEditingController(text: u.documentId ?? '');
    _phoneController = TextEditingController(text: u.phone ?? '');
    _grade = u.grade;
    _documentType = u.documentType;
    _phoneCountryCode = u.phoneCountryCode ?? '+51';
    _birthDate = u.birthDate;
    _avatarUrl = u.avatarPath;
    _loadGrades();
  }

  Future<void> _loadGrades() async {
    try {
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
    } catch (_) {
      if (mounted) setState(() => _grades = []);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _documentIdController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final u = widget.user;
    final needsPasswordChange = u.passwordChangedAt == null;
    final screenSize = MediaQuery.sizeOf(context);
    final dialogWidth = (screenSize.width - 80).clamp(240.0, 540.0).toDouble();
    final dialogMaxHeight = (screenSize.height - 96)
        .clamp(320.0, 720.0)
        .toDouble();

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Row(
        children: [
          Expanded(
            child: Text(
              _t('profile.title'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 540, maxHeight: dialogMaxHeight),
        child: SizedBox(
          width: dialogWidth,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Password Change Warning ─────────────────────
                if (needsPasswordChange)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFF9800).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFE65100),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Debes cambiar tu contraseña asignada por una propia.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFFBF360C),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Section 1: Photo ────────────────────────────
                _buildPhotoSection(theme),

                const SizedBox(height: 20),

                // ── Section 2: Personal Data ────────────────────
                _buildSectionHeader(
                  theme,
                  _t('profile.personalData'),
                  Icons.person_outline,
                  _profileExpanded,
                  () => setState(() => _profileExpanded = !_profileExpanded),
                ),
                if (_profileExpanded) ...[
                  const SizedBox(height: 12),
                  _buildPersonalDataForm(theme),
                ],

                const SizedBox(height: 16),

                // ── Section 3: Password Change ──────────────────
                _buildSectionHeader(
                  theme,
                  _t('profile.changePassword'),
                  Icons.lock_outline,
                  _passwordExpanded,
                  () => setState(() => _passwordExpanded = !_passwordExpanded),
                ),
                if (_passwordExpanded) ...[
                  const SizedBox(height: 12),
                  _buildPasswordForm(theme),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isValidHttpUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  Widget _buildPhotoSection(ThemeData theme) {
    final validUrl = _isValidHttpUrl(_avatarUrl);
    final showInitials = !validUrl;

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage: validUrl ? NetworkImage(_avatarUrl!) : null,
                  child: showInitials
                      ? Text(
                          widget.user.initials,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.surface,
                        width: 2,
                      ),
                    ),
                    child: _uploadingPhoto
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: Colors.white,
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _t('profile.photoHint'),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (_photoError != null) ...[
            const SizedBox(height: 6),
            Text(
              _photoError!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickAndUploadPhoto() async {
    // Clear previous errors
    setState(() => _photoError = null);

    final selected = await pickProfileImageData();
    if (selected == null || !mounted) return;

    if (!{
      'image/jpeg',
      'image/png',
      'image/webp',
    }.contains(selected.mimeType)) {
      if (mounted) {
        setState(() => _photoError = 'Selecciona una imagen JPG, PNG o WEBP.');
      }
      return;
    }

    final bytes = selected.bytes;
    if (bytes.isEmpty) {
      if (mounted) setState(() => _photoError = 'No se pudo leer la imagen.');
      return;
    }

    final cropped = await _showImagePreview(bytes, selected.fileName);
    if (cropped == null || !mounted) return;

    setState(() {
      _uploadingPhoto = true;
      _photoError = null;
    });

    try {
      final result = await ref
          .read(authRepositoryProvider)
          .uploadAvatar(
            userId: widget.user.id,
            bytes: cropped.bytes,
            fileName: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
            contentType: cropped.contentType,
          );

      if (!mounted) return;
      switch (result) {
        case AppSuccess(data: final url):
          setState(() {
            _avatarUrl = url;
            _uploadingPhoto = false;
            _photoError = null;
          });
          // Refresh session so avatar shows in header immediately
          final freshUser = await ref
              .read(authRepositoryProvider)
              .currentUser();
          if (freshUser is AppSuccess<AppUser?> &&
              freshUser.data != null &&
              mounted) {
            ref
                .read(sessionControllerProvider.notifier)
                .updateUser(freshUser.data!);
          }
          // Auto-clear success state
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) setState(() => _photoError = null);
          });
        case AppFailure(error: final e):
          setState(() {
            _photoError = e.message;
            _uploadingPhoto = false;
          });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploadingPhoto = false;
          _photoError = 'No se pudo procesar la foto.';
        });
      }
    }
  }

  Future<_AvatarCropResult?> _showImagePreview(
    List<int> bytes,
    String fileName,
  ) {
    return showDialog<_AvatarCropResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ImagePreviewDialog(bytes: bytes, fileName: fileName),
    );
  }

  Widget _responsivePair({
    required Widget first,
    required Widget second,
    double? firstDesktopWidth,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 430) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: 12), second],
          );
        }
        return Row(
          children: [
            if (firstDesktopWidth == null)
              Expanded(child: first)
            else
              SizedBox(width: firstDesktopWidth, child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  Widget _buildPersonalDataForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Grade
        DropdownButtonFormField<String?>(
          initialValue:
              _grade != null && _grades.any((g) => g['code'] == _grade)
              ? _grade
              : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: _t('common.grade'),
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('Sin grado')),
            for (final g in _grades)
              DropdownMenuItem(value: g['code'], child: Text(g['name'] ?? '')),
          ],
          onChanged: (v) => setState(() => _grade = v),
        ),
        const SizedBox(height: 12),

        // First Name + Last Name
        _responsivePair(
          first: TextFormField(
            controller: _firstNameController,
            decoration: InputDecoration(
              labelText: _t('common.firstName'),
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'[a-zA-ZáéíóúüñÁÉÍÓÚÜÑ\s]'),
              ),
            ],
          ),
          second: TextFormField(
            controller: _lastNameController,
            decoration: InputDecoration(
              labelText: _t('common.lastName'),
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'[a-zA-ZáéíóúüñÁÉÍÓÚÜÑ\s]'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Document type + ID
        _responsivePair(
          firstDesktopWidth: 140,
          first: DropdownButtonFormField<String>(
            initialValue: _documentType,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: _t('common.document'),
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'dni', child: Text('DNI')),
              DropdownMenuItem(value: 'passport', child: Text('Pasaporte')),
            ],
            onChanged: (v) => setState(() => _documentType = v),
          ),
          second: TextFormField(
            controller: _documentIdController,
            decoration: InputDecoration(
              labelText: _t('common.documentNumber'),
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Phone country code + number
        _responsivePair(
          firstDesktopWidth: 130,
          first: DropdownButtonFormField<String>(
            initialValue: _phoneCountryCode,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: _t('common.code'),
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            ),
            items: _countryCodes
                .map(
                  (c) => DropdownMenuItem(
                    value: c['code'],
                    child: Text(
                      '${c['code']} ${c['name']}',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _phoneCountryCode = v),
          ),
          second: TextFormField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: _t('common.phone'),
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
        const SizedBox(height: 12),

        // Birth date
        InkWell(
          onTap: _pickBirthDate,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: _t('common.birthDate'),
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              suffixIcon: Icon(Icons.calendar_today, size: 18),
            ),
            child: Text(
              _birthDate != null
                  ? '${_birthDate!.day.toString().padLeft(2, '0')}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year}'
                  : _t('common.selectDate'),
              style: TextStyle(
                color: _birthDate != null
                    ? null
                    : theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
        ),

        if (_profileError != null) ...[
          const SizedBox(height: 12),
          Text(
            _profileError!,
            style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
          ),
        ],

        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _savingProfile ? null : _saveProfile,
            icon: _savingProfile
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save, size: 18),
            label: Text(_savingProfile ? 'Guardando...' : 'Guardar Datos'),
          ),
        ),
      ],
    );
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(1990),
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
      helpText: _t('common.selectDate'),
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _savingProfile = true;
      _profileError = null;
    });

    final result = await ref
        .read(authRepositoryProvider)
        .updateProfile(
          userId: widget.user.id,
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

    if (!mounted) return;
    setState(() => _savingProfile = false);

    switch (result) {
      case AppSuccess(data: final updatedUser):
        ref.read(sessionControllerProvider.notifier).updateUser(updatedUser);
        if (mounted) Navigator.of(context).pop();
      case AppFailure(error: final e):
        setState(() => _profileError = e.message);
    }
  }

  Widget _buildPasswordForm(ThemeData theme) {
    final newPw = _newPasswordController.text;

    return Form(
      key: _pwFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _currentPasswordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: _t('profile.currentPassword'),
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? _t('common.required') : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _newPasswordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: _t('profile.newPassword'),
              hintText:
                  'Mín. 6 caracteres, mayúsculas, minúsculas, números y símbolos',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            onChanged: (_) => setState(() {}),
            validator: (v) {
              if (v == null || v.isEmpty) return _t('common.required');
              if (v.length < 6) return _t('common.minChars6');
              if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Falta una mayúscula';
              if (!RegExp(r'[a-z]').hasMatch(v)) return 'Falta una minúscula';
              if (!RegExp(r'[0-9]').hasMatch(v)) return 'Falta un número';
              if (!RegExp(r'[^A-Za-z0-9]').hasMatch(v)) {
                return 'Falta un carácter especial';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          PasswordStrengthBar(password: newPw),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: _t('profile.confirmPassword'),
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return _t('common.required');
              if (v != _newPasswordController.text) {
                return _t('validation.required');
              }
              return null;
            },
          ),

          if (_passwordError != null) ...[
            const SizedBox(height: 8),
            Text(
              _passwordError!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          ],
          if (_passwordSuccess != null) ...[
            const SizedBox(height: 8),
            Text(
              _passwordSuccess!,
              style: TextStyle(
                color: const Color(0xFF2E9D57),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _changingPassword ? null : _changePassword,
              icon: _changingPassword
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.lock_reset, size: 18),
              label: Text(
                _changingPassword
                    ? 'Cambiando...'
                    : _t('profile.changePassword'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    if (!_pwFormKey.currentState!.validate()) return;

    setState(() {
      _changingPassword = true;
      _passwordError = null;
      _passwordSuccess = null;
    });

    final result = await ref
        .read(authRepositoryProvider)
        .changePassword(
          currentPassword: _currentPasswordController.text,
          newPassword: _newPasswordController.text,
        );

    if (!mounted) return;
    setState(() => _changingPassword = false);

    switch (result) {
      case AppSuccess():
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        setState(() => _passwordSuccess = '¡Contraseña cambiada exitosamente!');
      case AppFailure(error: final e):
        setState(() => _passwordError = e.message);
    }
  }

  Widget _buildSectionHeader(
    ThemeData theme,
    String title,
    IconData icon,
    bool expanded,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.expand_more, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Image Preview Dialog ──────────────────────────────────────────────

class _AvatarCropResult {
  const _AvatarCropResult({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}

class _ImagePreviewDialog extends StatefulWidget {
  const _ImagePreviewDialog({required this.bytes, required this.fileName});

  final List<int> bytes;
  final String fileName;

  @override
  State<_ImagePreviewDialog> createState() => _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends State<_ImagePreviewDialog> {
  String _t(String key) => AppLocalizations.of(context).t(key);

  final TransformationController _transformController =
      TransformationController();
  bool _processing = false;
  String? _error;

  static const int _outputSize = 512;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.sizeOf(context);
    final dialogWidth = (screenSize.width - 80).clamp(240.0, 420.0).toDouble();
    final previewSize = _previewSizeFor(context);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(
        _t('profile.adjustPhoto'),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SizedBox(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: previewSize,
              height: previewSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipOval(
                    child: InteractiveViewer(
                      transformationController: _transformController,
                      minScale: 0.7,
                      maxScale: 4.0,
                      boundaryMargin: EdgeInsets.all(previewSize / 3),
                      child: SizedBox(
                        width: previewSize,
                        height: previewSize,
                        child: Center(
                          child: Image.memory(
                            Uint8List.fromList(widget.bytes),
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(Icons.broken_image, size: 64),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: Container(
                      width: previewSize,
                      height: previewSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.18,
                            ),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Mueve y acerca la imagen para centrarla dentro del círculo.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _processing ? null : () => Navigator.of(context).pop(),
          child: Text(_t('common.cancel')),
        ),
        TextButton(
          onPressed: _processing
              ? null
              : () => _transformController.value = Matrix4.identity(),
          child: Text(_t('common.reset')),
        ),
        FilledButton(
          onPressed: _processing ? null : _confirmCrop,
          child: _processing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_t('profile.useThisPhoto')),
        ),
      ],
    );
  }

  double _previewSizeFor(BuildContext context) {
    return (MediaQuery.sizeOf(context).width - 96)
        .clamp(200.0, 360.0)
        .toDouble();
  }

  Future<void> _confirmCrop() async {
    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      final croppedBytes = await _cropToAvatarJpeg(_previewSizeFor(context));
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(_AvatarCropResult(bytes: croppedBytes, contentType: 'image/jpeg'));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = 'No se pudo procesar esta imagen.';
      });
    }
  }

  Future<Uint8List> _cropToAvatarJpeg(double previewSize) async {
    return cropAvatarJpeg(
      bytes: widget.bytes,
      transformStorage: _transformController.value.storage,
      previewSize: previewSize,
      outputSize: _outputSize,
    );
  }
}
