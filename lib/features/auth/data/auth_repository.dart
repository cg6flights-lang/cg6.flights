import 'dart:typed_data';

import 'package:cg6_flights/core/config/supabase_config.dart';
import 'package:cg6_flights/core/errors/app_error.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/core/security/app_permission.dart';
import 'package:cg6_flights/core/security/app_role.dart';
import 'package:cg6_flights/features/auth/domain/app_user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseAuthRepository(Supabase.instance.client);
  }
  return DemoAuthRepository();
});

abstract class AuthRepository {
  Future<AppResult<AppUser?>> currentUser();

  Future<AppResult<AppUser>> signIn({
    required String email,
    required String password,
  });

  Future<AppResult<AppUser>> register({
    required String email,
    required String password,
    required String displayName,
    String? firstName,
    String? lastName,
    String? documentType,
    String? documentId,
    String? phoneCountryCode,
    String? phone,
    DateTime? birthDate,
    String? grade,
  });

  Future<AppResult<AppUser>> claimFirstLeader();

  Future<AppResult<AppUser>> updateProfile({
    required String userId,
    String? firstName,
    String? lastName,
    String? documentType,
    String? documentId,
    String? phoneCountryCode,
    String? phone,
    DateTime? birthDate,
    String? grade,
  });

  Future<AppResult<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<AppResult<String>> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  });

  Future<void> signOut();
}

class DemoAuthRepository implements AuthRepository {
  AppUser? _user;

  @override
  Future<AppResult<AppUser?>> currentUser() async {
    return AppSuccess(_user);
  }

  @override
  Future<AppResult<AppUser>> signIn({
    required String email,
    required String password,
  }) async {
    _user = AppUser.demoLeader();
    return AppSuccess(_user!);
  }

  @override
  Future<AppResult<AppUser>> register({
    required String email,
    required String password,
    required String displayName,
    String? firstName,
    String? lastName,
    String? documentType,
    String? documentId,
    String? phoneCountryCode,
    String? phone,
    DateTime? birthDate,
    String? grade,
  }) async {
    _user = AppUser.pending(email: email, displayName: displayName);
    return AppSuccess(_user!);
  }

  @override
  Future<AppResult<AppUser>> claimFirstLeader() async {
    _user = AppUser.demoLeader();
    return AppSuccess(_user!);
  }

  @override
  Future<AppResult<AppUser>> updateProfile({
    required String userId,
    String? firstName,
    String? lastName,
    String? documentType,
    String? documentId,
    String? phoneCountryCode,
    String? phone,
    DateTime? birthDate,
    String? grade,
  }) async {
    _user = _user?.copyWith(
      firstName: firstName,
      lastName: lastName,
      documentType: documentType,
      documentId: documentId,
      phoneCountryCode: phoneCountryCode,
      phone: phone,
      birthDate: birthDate,
      grade: grade,
    );
    return AppSuccess(_user!);
  }

  @override
  Future<AppResult<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return const AppSuccess(null);
  }

  @override
  Future<AppResult<String>> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    return const AppSuccess('');
  }

  @override
  Future<void> signOut() async {
    _user = null;
  }
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AppResult<AppUser?>> currentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return const AppSuccess(null);
    return _profileFor(user);
  }

  @override
  Future<AppResult<AppUser>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) {
        return const AppFailure(
          AppError(
            code: 'AUTH_SESSION_MISSING',
            message: 'No se pudo iniciar sesión.',
            category: AppErrorCategory.auth,
            severity: AppErrorSeverity.high,
          ),
        );
      }
      return _profileFor(user);
    } on AuthException catch (error) {
      return AppFailure(
        AppError(
          code: 'AUTH_INVALID_CREDENTIALS',
          message: error.message,
          category: AppErrorCategory.auth,
          severity: AppErrorSeverity.medium,
        ),
      );
    }
  }

  @override
  Future<AppResult<AppUser>> register({
    required String email,
    required String password,
    required String displayName,
    String? firstName,
    String? lastName,
    String? documentType,
    String? documentId,
    String? phoneCountryCode,
    String? phone,
    DateTime? birthDate,
    String? grade,
  }) async {
    try {
      final userMeta = <String, dynamic>{'display_name': displayName};
      if (firstName != null) userMeta['first_name'] = firstName;
      if (lastName != null) userMeta['last_name'] = lastName;
      if (documentType != null) userMeta['document_type'] = documentType;
      if (documentId != null) userMeta['document_id'] = documentId;
      if (phoneCountryCode != null) {
        userMeta['phone_country_code'] = phoneCountryCode;
      }
      if (phone != null) userMeta['phone'] = phone;
      if (birthDate != null) {
        userMeta['birth_date'] =
            '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}';
      }
      if (grade != null) userMeta['grade'] = grade;

      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: userMeta,
      );
      final user = response.user;
      if (user == null) {
        return const AppFailure(
          AppError(
            code: 'AUTH_SESSION_MISSING',
            message: 'No se pudo completar el registro.',
            category: AppErrorCategory.auth,
            severity: AppErrorSeverity.high,
          ),
        );
      }
      final pending = AppUser.pending(email: email, displayName: displayName);
      return AppSuccess(pending.copyWith(id: user.id));
    } on AuthException catch (error) {
      return AppFailure(
        AppError(
          code: 'AUTH_REGISTER_FAILED',
          message: error.message,
          category: AppErrorCategory.auth,
          severity: AppErrorSeverity.medium,
        ),
      );
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'SYSTEM_UNEXPECTED',
          message: 'No se pudo completar el registro.',
          category: AppErrorCategory.system,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }

  @override
  Future<AppResult<AppUser>> claimFirstLeader() async {
    try {
      if (_client.auth.currentSession == null) {
        return const AppFailure(
          AppError(
            code: 'AUTH_SESSION_MISSING',
            message:
                'Confirma tu correo e inicia sesion antes de activar el primer Lider.',
            category: AppErrorCategory.auth,
            severity: AppErrorSeverity.high,
          ),
        );
      }
      final response = await _client.functions.invoke('claim-first-leader');
      final body = response.data;
      if (body is Map && body['ok'] == true) {
        final authUser = _client.auth.currentUser;
        if (authUser == null) {
          return const AppFailure(
            AppError(
              code: 'AUTH_SESSION_MISSING',
              message: 'Sesion ausente o invalida.',
              category: AppErrorCategory.auth,
              severity: AppErrorSeverity.high,
            ),
          );
        }
        return _profileFor(authUser);
      }
      return AppFailure(_errorFromBody(body));
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'SYSTEM_UNEXPECTED',
          message: 'No se pudo activar el primer Líder.',
          category: AppErrorCategory.system,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  Future<AppResult<AppUser>> _profileFor(User authUser) async {
    try {
      final row = await _client
          .from('profiles')
          .select(
            'id,email,display_name,status,role,unit_id,squadron_id,units(name),first_name,last_name,document_type,document_id,phone_country_code,phone,birth_date,grade,avatar_path,password_changed_at',
          )
          .eq('id', authUser.id)
          .maybeSingle();

      if (row == null) {
        return AppSuccess(
          AppUser.pending(
            email: authUser.email ?? '',
            displayName:
                authUser.userMetadata?['display_name']?.toString() ??
                authUser.email ??
                'Usuario',
          ).copyWith(id: authUser.id),
        );
      }

      final role = AppRole.fromKey(row['role']?.toString());
      final status = _statusFromKey(row['status']?.toString());
      final permissions = role == null
          ? <String>{}
          : rolePermissionMatrix[role]!;
      final unit = row['units'];

      return AppSuccess(
        AppUser(
          id: row['id'].toString(),
          email: row['email']?.toString() ?? authUser.email ?? '',
          displayName: row['display_name']?.toString() ?? 'Usuario',
          status: status,
          role: role,
          unitId: row['unit_id']?.toString(),
          unitName: unit is Map ? unit['name']?.toString() : null,
          squadronId: row['squadron_id']?.toString(),
          permissions: permissions,
          firstName: row['first_name']?.toString(),
          lastName: row['last_name']?.toString(),
          documentType: row['document_type']?.toString(),
          documentId: row['document_id']?.toString(),
          phoneCountryCode: row['phone_country_code']?.toString(),
          phone: row['phone']?.toString(),
          birthDate: row['birth_date'] != null
              ? DateTime.tryParse(row['birth_date'].toString())
              : null,
          grade: row['grade']?.toString(),
          avatarPath: row['avatar_path']?.toString(),
          passwordChangedAt: row['password_changed_at'] != null
              ? DateTime.tryParse(row['password_changed_at'].toString())
              : null,
        ),
      );
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'DATA_PROFILE_NOT_FOUND',
          message: 'No se pudo cargar el perfil operativo.',
          category: AppErrorCategory.data,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }

  @override
  Future<AppResult<AppUser>> updateProfile({
    required String userId,
    String? firstName,
    String? lastName,
    String? documentType,
    String? documentId,
    String? phoneCountryCode,
    String? phone,
    DateTime? birthDate,
    String? grade,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (firstName != null) updateData['first_name'] = firstName;
      if (lastName != null) updateData['last_name'] = lastName;
      if (documentType != null) updateData['document_type'] = documentType;
      if (documentId != null) updateData['document_id'] = documentId;
      if (phoneCountryCode != null) {
        updateData['phone_country_code'] = phoneCountryCode;
      }
      if (phone != null) updateData['phone'] = phone;
      if (birthDate != null) {
        updateData['birth_date'] =
            '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}';
      }
      if (grade != null) updateData['grade'] = grade;

      if (updateData.isEmpty) {
        final user = _client.auth.currentUser;
        if (user != null) return _profileFor(user);
        return const AppFailure(
          AppError(
            code: 'AUTH_SESSION_MISSING',
            message: 'Sesion ausente.',
            category: AppErrorCategory.auth,
            severity: AppErrorSeverity.high,
          ),
        );
      }

      await _client.from('profiles').update(updateData).eq('id', userId);

      final user = _client.auth.currentUser;
      if (user != null) return _profileFor(user);
      return const AppFailure(
        AppError(
          code: 'AUTH_SESSION_MISSING',
          message: 'Sesion ausente.',
          category: AppErrorCategory.auth,
          severity: AppErrorSeverity.high,
        ),
      );
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'SYSTEM_PROFILE_UPDATE_FAILED',
          message: 'No se pudo actualizar el perfil.',
          category: AppErrorCategory.system,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }

  @override
  Future<AppResult<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'change-password',
        body: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
      final body = response.data;
      if (body is Map && body['ok'] == true) {
        return const AppSuccess(null);
      }
      return AppFailure(_errorFromBody(body));
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'SYSTEM_PASSWORD_CHANGE_FAILED',
          message: 'No se pudo cambiar la contraseña.',
          category: AppErrorCategory.system,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }

  @override
  Future<AppResult<String>> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    if (bytes.isEmpty) {
      return const AppFailure(
        AppError(
          code: 'STORAGE_AVATAR_PROCESSING_FAILED',
          message: 'No se pudo procesar la foto.',
          category: AppErrorCategory.storage,
          severity: AppErrorSeverity.medium,
        ),
      );
    }

    String publicUrl;
    final path = '$userId/$fileName';

    try {
      await _client.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: contentType,
              cacheControl: '3600',
            ),
          );
      publicUrl = _client.storage.from('avatars').getPublicUrl(path);
    } on FormatException {
      return const AppFailure(
        AppError(
          code: 'STORAGE_AVATAR_PROCESSING_FAILED',
          message: 'No se pudo procesar la foto.',
          category: AppErrorCategory.storage,
          severity: AppErrorSeverity.medium,
        ),
      );
    } on StorageException catch (error) {
      return AppFailure(
        AppError(
          code: 'STORAGE_AVATAR_UPLOAD_FAILED',
          message: error.message,
          category: AppErrorCategory.storage,
          severity: AppErrorSeverity.medium,
        ),
      );
    } catch (error) {
      return AppFailure(
        AppError(
          code: 'STORAGE_AVATAR_UPLOAD_FAILED',
          message: 'No se pudo subir la foto: $error',
          category: AppErrorCategory.storage,
          severity: AppErrorSeverity.medium,
        ),
      );
    }

    try {
      await _client
          .from('profiles')
          .update({'avatar_path': publicUrl})
          .eq('id', userId);
      return AppSuccess(publicUrl);
    } on PostgrestException catch (error) {
      return AppFailure(
        AppError(
          code: 'STORAGE_AVATAR_PROFILE_UPDATE_FAILED',
          message: error.message,
          category: AppErrorCategory.storage,
          severity: AppErrorSeverity.medium,
        ),
      );
    } catch (error) {
      return AppFailure(
        AppError(
          code: 'STORAGE_AVATAR_PROFILE_UPDATE_FAILED',
          message:
              'La foto subió, pero no se pudo actualizar el perfil: $error',
          category: AppErrorCategory.storage,
          severity: AppErrorSeverity.medium,
        ),
      );
    }
  }

  ProfileStatus _statusFromKey(String? key) {
    return switch (key) {
      'active' => ProfileStatus.active,
      'inactive' => ProfileStatus.inactive,
      'rejected' => ProfileStatus.rejected,
      _ => ProfileStatus.pending,
    };
  }

  AppError _errorFromBody(Object? body) {
    if (body is Map && body['error'] is Map) {
      final error = body['error'] as Map;
      return AppError(
        code: error['code']?.toString() ?? 'SYSTEM_UNEXPECTED',
        message: error['message']?.toString() ?? 'Operacion no completada.',
        category: AppErrorCategory.system,
        severity: AppErrorSeverity.high,
      );
    }
    return const AppError(
      code: 'SYSTEM_UNEXPECTED',
      message: 'Operacion no completada.',
      category: AppErrorCategory.system,
      severity: AppErrorSeverity.high,
    );
  }
}
