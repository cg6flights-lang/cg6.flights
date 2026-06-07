import 'package:cg6_flights/core/errors/app_error.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/core/security/app_role.dart';
import 'package:cg6_flights/features/auth/domain/app_user.dart';
import 'package:cg6_flights/features/units/domain/unit_option.dart';
import 'package:cg6_flights/features/users/domain/managed_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return SupabaseUsersRepository(Supabase.instance.client);
});

abstract class UsersRepository {
  Future<AppResult<List<ManagedProfile>>> listProfiles();

  Future<AppResult<List<UnitOption>>> listUnits();

  Future<AppResult<void>> assignAccess({
    required String userId,
    required AppRole? role,
    required String? unitId,
    required ProfileStatus status,
  });

  Future<AppResult<void>> createUser({
    required String email,
    required String password,
    required String displayName,
    required AppRole? role,
    required String? unitId,
    required ProfileStatus status,
    String? firstName,
    String? lastName,
    String? documentType,
    String? documentId,
    String? phoneCountryCode,
    String? phone,
    DateTime? birthDate,
    String? grade,
  });
}

class SupabaseUsersRepository implements UsersRepository {
  SupabaseUsersRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AppResult<List<ManagedProfile>>> listProfiles() async {
    try {
      final rows = await _client
          .from('profiles')
          .select('id,email,display_name,status,role,unit_id,units(name)')
          .order('created_at', ascending: false);
      return AppSuccess(
        rows
            .map<ManagedProfile>(
              (row) => ManagedProfile.fromJson(Map<String, dynamic>.from(row)),
            )
            .toList(),
      );
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'DATA_USERS_LOAD_FAILED',
          message: 'No se pudo cargar usuarios.',
          category: AppErrorCategory.data,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }

  @override
  Future<AppResult<List<UnitOption>>> listUnits() async {
    try {
      final rows = await _client
          .from('units')
          .select('id,code,name,active')
          .eq('active', true)
          .order('name');
      return AppSuccess(
        rows
            .map<UnitOption>(
              (row) => UnitOption.fromJson(Map<String, dynamic>.from(row)),
            )
            .toList(),
      );
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'DATA_UNITS_LOAD_FAILED',
          message: 'No se pudo cargar unidades.',
          category: AppErrorCategory.data,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }

  @override
  Future<AppResult<void>> assignAccess({
    required String userId,
    required AppRole? role,
    required String? unitId,
    required ProfileStatus status,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'assign-user-access',
        body: {
          'user_id': userId,
          'role': role?.key,
          'unit_id': unitId,
          'status': status.key,
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
          code: 'SYSTEM_ASSIGN_ACCESS_FAILED',
          message: 'No se pudo actualizar acceso.',
          category: AppErrorCategory.system,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }

  @override
  Future<AppResult<void>> createUser({
    required String email,
    required String password,
    required String displayName,
    required AppRole? role,
    required String? unitId,
    required ProfileStatus status,
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
      final bodyMap = <String, dynamic>{
        'action': 'create',
        'email': email,
        'password': password,
        'display_name': displayName,
        'role': role?.key,
        'unit_id': unitId,
        'status': status.key,
      };
      if (firstName != null) bodyMap['first_name'] = firstName;
      if (lastName != null) bodyMap['last_name'] = lastName;
      if (documentType != null) bodyMap['document_type'] = documentType;
      if (documentId != null) bodyMap['document_id'] = documentId;
      if (phoneCountryCode != null) bodyMap['phone_country_code'] = phoneCountryCode;
      if (phone != null) bodyMap['phone'] = phone;
      if (birthDate != null) {
        bodyMap['birth_date'] =
            '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}';
      }
      if (grade != null) bodyMap['grade'] = grade;

      final response = await _client.functions.invoke(
        'manage-user',
        body: bodyMap,
      );
      final body = response.data;
      if (body is Map && body['ok'] == true) {
        return const AppSuccess(null);
      }
      return AppFailure(_errorFromBody(body));
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'SYSTEM_CREATE_USER_FAILED',
          message: 'No se pudo crear el usuario.',
          category: AppErrorCategory.system,
          severity: AppErrorSeverity.high,
        ),
      );
    }
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

extension ProfileStatusKey on ProfileStatus {
  String get key => switch (this) {
    ProfileStatus.pending => 'pending',
    ProfileStatus.active => 'active',
    ProfileStatus.inactive => 'inactive',
    ProfileStatus.rejected => 'rejected',
  };

  String get labelEs => switch (this) {
    ProfileStatus.pending => 'Pendiente',
    ProfileStatus.active => 'Activo',
    ProfileStatus.inactive => 'Inactivo',
    ProfileStatus.rejected => 'Rechazado',
  };
}
