import 'package:cg6_flights/core/errors/app_error.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/crew/domain/cadet_course.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final cadetCourseRepositoryProvider = Provider<CadetCourseRepository>((ref) {
  return SupabaseCadetCourseRepository(Supabase.instance.client);
});

abstract class CadetCourseRepository {
  Future<AppResult<List<CadetCourse>>> listCourses({required String unitId});
  Future<AppResult<CadetCourse>> createCourse({required String unitId, required String name, required DateTime startDate, required DateTime endDate});
  Future<AppResult<void>> archiveCourse(String courseId);
}

class SupabaseCadetCourseRepository implements CadetCourseRepository {
  SupabaseCadetCourseRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<AppResult<List<CadetCourse>>> listCourses({required String unitId}) async {
    try {
      final rows = await _client
          .from('cadet_courses')
          .select('*, cadet_count:crew_members(count)')
          .eq('unit_id', unitId)
          .order('start_date', ascending: false);
      return AppSuccess(
        (rows as List<dynamic>).map((r) {
          final m = Map<String, dynamic>.from(r);
          final countList = m['cadet_count'] as List<dynamic>?;
          if (countList != null && countList.isNotEmpty) {
            m['cadet_count'] = (countList.first as Map)['count'];
          }
          return CadetCourse.fromJson(m);
        }).toList(),
      );
    } catch (_) {
      return const AppFailure(AppError(code: 'COURSE_LOAD_FAILED', message: 'No se pudieron cargar los cursos.', category: AppErrorCategory.data, severity: AppErrorSeverity.low));
    }
  }

  @override
  Future<AppResult<CadetCourse>> createCourse({required String unitId, required String name, required DateTime startDate, required DateTime endDate}) async {
    try {
      final row = await _client.from('cadet_courses').insert({
        'unit_id': unitId,
        'name': name,
        'start_date': startDate.toIso8601String().split('T').first,
        'end_date': endDate.toIso8601String().split('T').first,
      }).select('*').single();
      return AppSuccess(CadetCourse.fromJson(Map<String, dynamic>.from(row)));
    } catch (_) {
      return const AppFailure(AppError(code: 'COURSE_CREATE_FAILED', message: 'No se pudo crear el curso.', category: AppErrorCategory.data, severity: AppErrorSeverity.high));
    }
  }

  @override
  Future<AppResult<void>> archiveCourse(String courseId) async {
    try {
      await _client.from('cadet_courses').update({'status': 'archived'}).eq('id', courseId);
      await _client.from('crew_members').update({'active': false}).eq('cadet_course_id', courseId);
      return const AppSuccess(null);
    } catch (_) {
      return const AppFailure(AppError(code: 'COURSE_ARCHIVE_FAILED', message: 'No se pudo archivar el curso.', category: AppErrorCategory.data, severity: AppErrorSeverity.high));
    }
  }
}
