import 'package:cg6_flights/core/errors/app_error.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/crew/domain/grade_option.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final gradesRepositoryProvider = Provider<GradesRepository>((ref) {
  return SupabaseGradesRepository(Supabase.instance.client);
});

abstract class GradesRepository {
  Future<AppResult<List<GradeOption>>> listGrades({String? category});
}

class SupabaseGradesRepository implements GradesRepository {
  SupabaseGradesRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AppResult<List<GradeOption>>> listGrades({String? category}) async {
    try {
      var filter = _client
          .from('grades')
          .select('id,code,name,category')
          .eq('active', true);

      if (category != null) {
        filter = filter.eq('category', category);
      }

      final rows = await filter.order('sort_order');
      return AppSuccess(
        rows
            .map<GradeOption>(
              (row) => GradeOption.fromJson(Map<String, dynamic>.from(row)),
            )
            .toList(),
      );
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'SYSTEM_UNEXPECTED',
          message: 'No se pudo cargar grados.',
          category: AppErrorCategory.data,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }
}
