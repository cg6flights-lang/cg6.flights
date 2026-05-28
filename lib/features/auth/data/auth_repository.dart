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
  });

  Future<AppResult<AppUser>> claimFirstLeader();

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
            message: 'No se pudo iniciar sesion.',
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
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
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
          message: 'No se pudo activar el primer Lider.',
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
          .select('id,email,display_name,status,role,unit_id,units(name)')
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
          permissions: permissions,
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
