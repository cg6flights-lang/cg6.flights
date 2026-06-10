import 'dart:typed_data';

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
    String? cadetCourseId,
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
    DateTime? trainingStart,
    DateTime? trainingEnd,
    String? courseGroup,
    String? cadetCourseId,
  });

  Future<AppResult<void>> deactivateCrewMember(String crewMemberId);
  Future<AppResult<void>> moveSquadron({
    required String crewMemberId,
    required String newSquadronId,
  });
  Future<AppResult<String>> uploadCrewPhoto({
    required String crewMemberId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  });
  Future<AppResult<List<CrewFlightLog>>> listCrewFlightLogs(
    String crewMemberId,
  );
}

class CrewFlightLog {
  const CrewFlightLog({
    required this.itemId,
    required this.operationDate,
    this.orderNumber,
    this.aircraftRegistration,
    this.aircraftModel,
    this.mission,
    this.eteMinutes,
    this.actualMinutes,
    this.rating,
    this.cadetTurn,
    this.checkRide,
    this.roleCode,
  });

  final String itemId;
  final DateTime operationDate;
  final String? orderNumber;
  final String? aircraftRegistration;
  final String? aircraftModel;
  final String? mission;
  final int? eteMinutes;
  final int? actualMinutes;
  final String? rating;
  final int? cadetTurn;
  final String? checkRide;
  final String? roleCode;

  double get plannedHours => (eteMinutes ?? 0) / 60;
  double get actualHours => (actualMinutes ?? 0) / 60;
}

class SupabaseCrewRepository implements CrewRepository {
  SupabaseCrewRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AppResult<List<CrewMember>>> listCrewMembers({
    String? unitId,
    String? squadronId,
    String? cadetCourseId,
  }) async {
    try {
      var query = _client
          .from('crew_members')
          .select(
            'id,unit_id,grade,first_name,last_name,nsa,crew_category,assignment_type,appointment_date,active,qualifications,squadron_id,photo_path,flight_squadrons(name),training_start,training_end,course_group,cadet_course_id,cadet_courses(name)',
          );
      if (cadetCourseId != null) {
        query = query.eq('cadet_course_id', cadetCourseId);
      } else {
        query = query.eq('active', true);
      }
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
    DateTime? trainingStart,
    DateTime? trainingEnd,
    String? courseGroup,
    String? cadetCourseId,
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
      trainingStart: trainingStart,
      trainingEnd: trainingEnd,
      courseGroup: courseGroup,
      cadetCourseId: cadetCourseId,
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

  @override
  Future<AppResult<String>> uploadCrewPhoto({
    required String crewMemberId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    if (bytes.isEmpty) {
      return const AppFailure(
        AppError(
          code: 'STORAGE_CREW_PHOTO_PROCESSING_FAILED',
          message: 'No se pudo procesar la foto.',
          category: AppErrorCategory.storage,
          severity: AppErrorSeverity.medium,
        ),
      );
    }

    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
    final path = '$crewMemberId/$safeName';
    late final String publicUrl;

    try {
      await _client.storage
          .from('crew-photos')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: contentType,
              cacheControl: '3600',
            ),
          );
      publicUrl = _client.storage.from('crew-photos').getPublicUrl(path);
    } on FormatException {
      return const AppFailure(
        AppError(
          code: 'STORAGE_CREW_PHOTO_PROCESSING_FAILED',
          message: 'No se pudo procesar la foto.',
          category: AppErrorCategory.storage,
          severity: AppErrorSeverity.medium,
        ),
      );
    } on StorageException catch (error) {
      return AppFailure(
        AppError(
          code: 'STORAGE_CREW_PHOTO_UPLOAD_FAILED',
          message: error.message,
          category: AppErrorCategory.storage,
          severity: AppErrorSeverity.medium,
        ),
      );
    } catch (error) {
      return AppFailure(
        AppError(
          code: 'STORAGE_CREW_PHOTO_UPLOAD_FAILED',
          message: 'No se pudo subir la foto: $error',
          category: AppErrorCategory.storage,
          severity: AppErrorSeverity.medium,
        ),
      );
    }

    final result = await _manageCrew(
      action: 'photo',
      crewMemberId: crewMemberId,
      photoPath: publicUrl,
    );
    return switch (result) {
      AppSuccess<void>() => AppSuccess(publicUrl),
      AppFailure<void>(error: final error) => AppFailure(error),
    };
  }

  @override
  Future<AppResult<List<CrewFlightLog>>> listCrewFlightLogs(
    String crewMemberId,
  ) async {
    try {
      final crewRows = await _client
          .from('flight_order_crew')
          .select('flight_order_item_id,role_code')
          .eq('crew_member_id', crewMemberId);

      if (crewRows.isEmpty) return const AppSuccess([]);

      final roleByItem = <String, String>{};
      final itemIds = <String>[];
      for (final row in crewRows) {
        final map = Map<String, dynamic>.from(row);
        final itemId = map['flight_order_item_id']?.toString();
        if (itemId == null || itemId.isEmpty) continue;
        itemIds.add(itemId);
        roleByItem[itemId] = map['role_code']?.toString() ?? '';
      }
      if (itemIds.isEmpty) return const AppSuccess([]);

      final itemRows = await _client
          .from('flight_order_items')
          .select(
            'id,flight_order_id,aircraft_id,mission,ete_minutes,scheduled_departure,status,cancelled,rating,cadet_turn,check_ride',
          )
          .inFilter('id', itemIds)
          .eq('cancelled', false);

      if (itemRows.isEmpty) return const AppSuccess([]);

      final items = itemRows
          .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
          .toList();
      final orderIds = items
          .map((item) => item['flight_order_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();
      final aircraftIds = items
          .map((item) => item['aircraft_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      final results = await Future.wait([
        _client
            .from('flight_orders')
            .select('id,operation_date,order_number,status')
            .inFilter('id', orderIds),
        _client
            .from('aircraft')
            .select(
              'id,tail_number,ob_tail_number,display_registration,model,manufacturer',
            )
            .inFilter('id', aircraftIds),
        _client
            .from('flight_order_state_events')
            .select('flight_order_item_id,status,occurred_at')
            .inFilter('flight_order_item_id', itemIds),
      ]);

      final orders = <String, Map<String, dynamic>>{};
      for (final row in results[0] as List) {
        final map = Map<String, dynamic>.from(row);
        orders[map['id'].toString()] = map;
      }

      final aircraft = <String, Map<String, dynamic>>{};
      for (final row in results[1] as List) {
        final map = Map<String, dynamic>.from(row);
        aircraft[map['id'].toString()] = map;
      }

      final eventsByItem = <String, List<Map<String, dynamic>>>{};
      for (final row in results[2] as List) {
        final map = Map<String, dynamic>.from(row);
        final itemId = map['flight_order_item_id']?.toString();
        if (itemId == null) continue;
        eventsByItem.putIfAbsent(itemId, () => []).add(map);
      }

      final logs = <CrewFlightLog>[];
      for (final item in items) {
        final id = item['id'].toString();
        final order = orders[item['flight_order_id']?.toString()];
        final ac = aircraft[item['aircraft_id']?.toString()];
        final operationDate = order?['operation_date'] != null
            ? DateTime.tryParse(order!['operation_date'].toString())
            : DateTime.tryParse(item['scheduled_departure']?.toString() ?? '');
        if (operationDate == null) continue;

        logs.add(
          CrewFlightLog(
            itemId: id,
            operationDate: operationDate,
            orderNumber: order?['order_number']?.toString(),
            aircraftRegistration: _displayTailNumber(ac),
            aircraftModel: ac?['model']?.toString(),
            mission: item['mission']?.toString(),
            eteMinutes: item['ete_minutes'] != null
                ? int.tryParse(item['ete_minutes'].toString())
                : null,
            actualMinutes: _actualMinutes(eventsByItem[id] ?? const []),
            rating: item['rating']?.toString(),
            cadetTurn: item['cadet_turn'] != null
                ? int.tryParse(item['cadet_turn'].toString())
                : null,
            checkRide: item['check_ride']?.toString(),
            roleCode: roleByItem[id],
          ),
        );
      }

      logs.sort((a, b) => b.operationDate.compareTo(a.operationDate));
      return AppSuccess(logs);
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'SYSTEM_UNEXPECTED',
          message: 'No se pudo cargar la hoja de vida del tripulante.',
          category: AppErrorCategory.data,
          severity: AppErrorSeverity.medium,
        ),
      );
    }
  }

  static String? _displayTailNumber(Map<String, dynamic>? ac) {
    if (ac == null) return null;
    if (ac['display_registration']?.toString() == 'OB') {
      final ob = ac['ob_tail_number']?.toString();
      if (ob != null && ob.isNotEmpty) return ob;
    }
    return ac['tail_number']?.toString();
  }

  static int? _actualMinutes(List<Map<String, dynamic>> events) {
    DateTime? at(String status) {
      for (final event in events) {
        if (event['status']?.toString() == status) {
          return DateTime.tryParse(event['occurred_at']?.toString() ?? '');
        }
      }
      return null;
    }

    final takeoff = at('takeoff');
    final landing = at('landing');
    if (takeoff != null && landing != null && landing.isAfter(takeoff)) {
      return landing.difference(takeoff).inMinutes;
    }

    final taxi = at('taxi');
    final engineOff = at('engine_off');
    if (taxi != null && engineOff != null && engineOff.isAfter(taxi)) {
      return engineOff.difference(taxi).inMinutes;
    }
    return null;
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
    DateTime? trainingStart,
    DateTime? trainingEnd,
    String? courseGroup,
    String? cadetCourseId,
    String? photoPath,
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
          'training_start': trainingStart?.toIso8601String().split('T').first,
          'training_end': trainingEnd?.toIso8601String().split('T').first,
          'course_group': courseGroup,
          'cadet_course_id': cadetCourseId,
          'photo_path': photoPath,
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
