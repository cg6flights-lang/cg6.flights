import 'package:cg6_flights/core/errors/app_error.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/crew/domain/crew_member.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final crewRepositoryProvider = Provider<CrewRepository>((ref) {
  return SupabaseCrewRepository(Supabase.instance.client);
});

abstract class CrewRepository {
  Future<AppResult<List<CrewMember>>> listCrewMembers({
    String? unitId,
    String? squadronId,
  });

  Future<AppResult<void>> saveCrewMember({
    String? crewMemberId,
    required String unitId,
    required String grade,
    required String firstName,
    required String lastName,
    required String nsa,
    required String crewCategory,
    required DateTime appointmentDate,
    String assignmentType = 'nato',
    List<String> qualifications = const [],
    String? squadronId,
  });

  Future<AppResult<void>> deactivateCrewMember(String crewMemberId);
  Future<AppResult<void>> moveSquadron({
    required String crewMemberId,
    required String newSquadronId,
  });
}

class SupabaseCrewRepository implements CrewRepository {
  SupabaseCrewRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AppResult<List<CrewMember>>> listCrewMembers({
    String? unitId,
    String? squadronId,
  }) async {
    try {
      var query = _client
          .from('crew_members')
          .select(
            'id,unit_id,grade,first_name,last_name,nsa,crew_category,assignment_type,appointment_date,active,qualifications,squadron_id,flight_squadrons(name),training_start,training_end,course_group',
          )
          .eq('active', true);
      if (unitId != null) query = query.eq('unit_id', unitId);
      if (squadronId != null) query = query.eq('squadron_id', squadronId);
      final rows = await query.order('last_name').order('first_name');
      return AppSuccess(
        rows
            .map<CrewMember>(
              (row) => CrewMember.fromJson(Map<String, dynamic>.from(row)),
            )
            .toList(),
      );
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'SYSTEM_UNEXPECTED',
          message: 'No se pudo cargar tripulantes.',
          category: AppErrorCategory.data,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }

  @override
  Future<AppResult<void>> saveCrewMember({
    String? crewMemberId,
    required String unitId,
    required String grade,
    required String firstName,
    required String lastName,
    required String nsa,
    required String crewCategory,
    required DateTime appointmentDate,
    String assignmentType = 'nato',
    List<String> qualifications = const [],
    String? squadronId,
  }) async {
    final action = crewMemberId == null ? 'create' : 'update';
    return _manageCrew(
      action: action,
      crewMemberId: crewMemberId,
      unitId: unitId,
      grade: grade,
      firstName: firstName,
      lastName: lastName,
      nsa: nsa,
      crewCategory: crewCategory,
      appointmentDate: appointmentDate,
      assignmentType: assignmentType,
      qualifications: qualifications,
      squadronId: squadronId,
    );
  }

  @override
  Future<AppResult<void>> deactivateCrewMember(String crewMemberId) {
    return _manageCrew(action: 'deactivate', crewMemberId: crewMemberId);
  }

  @override
  Future<AppResult<void>> moveSquadron({
    required String crewMemberId,
    required String newSquadronId,
  }) async {
    return _manageCrew(
      action: 'move_squadron',
      crewMemberId: crewMemberId,
      squadronId: newSquadronId,
    );
  }

  Future<AppResult<void>> _manageCrew({
    required String action,
    String? crewMemberId,
    String? unitId,
    String? grade,
    String? firstName,
    String? lastName,
    String? nsa,
    String? crewCategory,
    DateTime? appointmentDate,
    String? assignmentType,
    List<String>? qualifications,
    String? squadronId,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'manage-crew',
        body: {
          'action': action,
          'crew_member_id': crewMemberId,
          'unit_id': unitId,
          'grade': grade,
          'first_name': firstName,
          'last_name': lastName,
          'nsa': nsa,
          'crew_category': crewCategory,
          'appointment_date': appointmentDate != null
              ? '${appointmentDate.year.toString().padLeft(4, '0')}-${appointmentDate.month.toString().padLeft(2, '0')}-${appointmentDate.day.toString().padLeft(2, '0')}'
              : null,
          'assignment_type': assignmentType,
          'qualifications': qualifications,
          'squadron_id': squadronId,
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
          code: 'SYSTEM_UNEXPECTED',
          message: 'No se pudo guardar el tripulante.',
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
        category: _categoryFromWire(error['category']?.toString()),
        severity: _severityFromWire(error['severity']?.toString()),
      );
    }
    return const AppError(
      code: 'SYSTEM_UNEXPECTED',
      message: 'Operacion no completada.',
      category: AppErrorCategory.system,
      severity: AppErrorSeverity.high,
    );
  }

  AppErrorCategory _categoryFromWire(String? value) {
    return switch (value) {
      'AUTH' => AppErrorCategory.auth,
      'AUTHORIZATION' => AppErrorCategory.authorization,
      'VALIDATION' => AppErrorCategory.validation,
      'BUSINESS_RULE' => AppErrorCategory.businessRule,
      'DATA' => AppErrorCategory.data,
      'NETWORK' => AppErrorCategory.network,
      'STORAGE' => AppErrorCategory.storage,
      'REALTIME' => AppErrorCategory.realtime,
      'EXPORT' => AppErrorCategory.export,
      _ => AppErrorCategory.system,
    };
  }

  AppErrorSeverity _severityFromWire(String? value) {
    return switch (value) {
      'low' => AppErrorSeverity.low,
      'medium' => AppErrorSeverity.medium,
      'critical' => AppErrorSeverity.critical,
      _ => AppErrorSeverity.high,
    };
  }
}
