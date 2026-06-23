import 'package:cg6_flights/core/errors/app_error.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSuccess', () {
    test('ok is true and exposes data', () {
      const result = AppSuccess<int>(42);
      expect(result.ok, isTrue);
      expect(result.data, 42);
    });

    test('holds collection data', () {
      final result = AppSuccess<List<String>>(['a', 'b']);
      expect(result.ok, isTrue);
      expect(result.data, ['a', 'b']);
    });
  });

  group('AppFailure', () {
    test('ok is false and exposes error fields', () {
      const result = AppFailure<int>(AppError(
        code: 'ERR_001',
        message: 'algo falló',
        category: AppErrorCategory.network,
        severity: AppErrorSeverity.high,
      ));
      expect(result.ok, isFalse);
      expect(result, isA<AppFailure<int>>());
      expect(result, isNot(isA<AppSuccess<int>>()));
      expect(result.error.code, 'ERR_001');
      expect(result.error.message, 'algo falló');
      expect(result.error.category, AppErrorCategory.network);
      expect(result.error.severity, AppErrorSeverity.high);
    });

    test('critical system error is constructible', () {
      const result = AppFailure<void>(AppError(
        code: 'SYSTEM_DOWN',
        message: 'caída del sistema',
        category: AppErrorCategory.system,
        severity: AppErrorSeverity.critical,
      ));
      expect(result.ok, isFalse);
      expect(result.error.severity, AppErrorSeverity.critical);
    });
  });

  group('AppError', () {
    test('every category and severity combination is constructible', () {
      for (final cat in AppErrorCategory.values) {
        for (final sev in AppErrorSeverity.values) {
          final err = AppError(
            code: 'c',
            message: 'm',
            category: cat,
            severity: sev,
          );
          expect(err.category, cat);
          expect(err.severity, sev);
        }
      }
    });
  });
}
