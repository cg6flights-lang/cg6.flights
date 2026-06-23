import 'package:cg6_flights/features/crew/domain/crew_member.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CrewMember.fromJson', () {
    test('parses happy-path fields', () {
      final c = CrewMember.fromJson({
        'id': 'c1',
        'unit_id': 'u1',
        'grade': 'Alf',
        'first_name': 'Juan',
        'last_name': 'Perez',
        'nsa': '12345',
        'crew_category': 'pilot',
        'assignment_type': 'nato',
        'appointment_date': '2020-01-15',
        'active': true,
        'qualifications': ['IP', 'PS'],
      });
      expect(c.id, 'c1');
      expect(c.grade, 'Alf');
      expect(c.firstName, 'Juan');
      expect(c.lastName, 'Perez');
      expect(c.fullName, 'Alf Juan Perez');
      expect(c.nsa, '12345');
      expect(c.crewCategory, 'pilot');
      expect(c.assignmentType, 'nato');
      expect(c.active, isTrue);
      expect(c.qualifications, ['IP', 'PS']);
      expect(c.appointmentDate, DateTime(2020, 1, 15));
      expect(c.isPilot, isTrue);
      expect(c.isMechanic, isFalse);
      expect(c.isNato, isTrue);
    });

    test('defaults crew_category to pilot and assignment_type to nato', () {
      final c = CrewMember.fromJson({'id': 'c'});
      expect(c.crewCategory, 'pilot');
      expect(c.assignmentType, 'nato');
      expect(c.isPilot, isTrue);
      expect(c.isNato, isTrue);
    });

    test('parses qualifications only when it is a list', () {
      expect(
        CrewMember.fromJson({'id': 'c', 'qualifications': 'IP'}).qualifications,
        isEmpty,
      );
      expect(
        CrewMember.fromJson({'id': 'c', 'qualifications': null}).qualifications,
        isEmpty,
      );
      expect(
        CrewMember.fromJson({
          'id': 'c',
          'qualifications': [1, 2],
        }).qualifications,
        ['1', '2'],
      );
    });

    test('falls back to DateTime.now() when appointment_date is missing or invalid', () {
      final before = DateTime.now();
      final c1 = CrewMember.fromJson({'id': 'c'});
      final c2 = CrewMember.fromJson({'id': 'c', 'appointment_date': 'not-a-date'});
      final after = DateTime.now();
      expect(
        c1.appointmentDate.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        c1.appointmentDate.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        c2.appointmentDate.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('squadronName from flight_squadrons map, falling back to squadron_name', () {
      expect(
        CrewMember.fromJson({
          'id': 'c',
          'flight_squadrons': {'name': 'Alpha'},
        }).squadronName,
        'Alpha',
      );
      expect(
        CrewMember.fromJson({'id': 'c', 'squadron_name': 'Bravo'}).squadronName,
        'Bravo',
      );
    });

    test('cadetCourseName from cadet_courses map, falling back to cadet_course_name', () {
      expect(
        CrewMember.fromJson({
          'id': 'c',
          'cadet_courses': {'name': 'Curso 2024'},
        }).cadetCourseName,
        'Curso 2024',
      );
      expect(
        CrewMember.fromJson({'id': 'c', 'cadet_course_name': 'Curso 2025'}).cadetCourseName,
        'Curso 2025',
      );
    });
  });

  group('isCadet', () {
    test('false for a plain NATO pilot with no cadet data', () {
      expect(CrewMember.fromJson({'id': 'c'}).isCadet, isFalse);
    });

    test('true when cadetCourseId is present', () {
      expect(
        CrewMember.fromJson({'id': 'c', 'cadet_course_id': 'cc1'}).isCadet,
        isTrue,
      );
    });

    test('true when trainingStart is present', () {
      expect(
        CrewMember.fromJson({'id': 'c', 'training_start': '2026-01-01'}).isCadet,
        isTrue,
      );
    });

    test('true when trainingEnd is present', () {
      expect(
        CrewMember.fromJson({'id': 'c', 'training_end': '2026-12-31'}).isCadet,
        isTrue,
      );
    });

    test('false when courseGroup is only whitespace', () {
      expect(
        CrewMember.fromJson({'id': 'c', 'course_group': '   '}).isCadet,
        isFalse,
      );
    });

    test('true when courseGroup has content', () {
      expect(
        CrewMember.fromJson({'id': 'c', 'course_group': 'Grupo A'}).isCadet,
        isTrue,
      );
    });
  });

  group('cadetCourseLabel', () {
    test('prefers cadetCourseName', () {
      expect(
        CrewMember.fromJson({
          'id': 'c',
          'cadet_course_name': 'Curso A',
          'course_group': 'Grupo B',
        }).cadetCourseLabel,
        'Curso A',
      );
    });

    test('falls back to courseGroup when course name is empty', () {
      expect(
        CrewMember.fromJson({'id': 'c', 'course_group': 'Grupo B'}).cadetCourseLabel,
        'Grupo B',
      );
    });

    test('returns empty string when neither is present', () {
      expect(CrewMember.fromJson({'id': 'c'}).cadetCourseLabel, '');
    });

    test('ignores whitespace-only course name and uses group', () {
      expect(
        CrewMember.fromJson({
          'id': 'c',
          'cadet_course_name': '   ',
          'course_group': 'Grupo B',
        }).cadetCourseLabel,
        'Grupo B',
      );
    });
  });

  group('category getters', () {
    test('isMechanic when crew_category is mechanic', () {
      final c = CrewMember.fromJson({'id': 'c', 'crew_category': 'mechanic'});
      expect(c.isMechanic, isTrue);
      expect(c.isPilot, isFalse);
    });

    test('isNato false when assignment_type is not nato', () {
      final c = CrewMember.fromJson({'id': 'c', 'assignment_type': 'contractor'});
      expect(c.isNato, isFalse);
    });
  });

  group('toJson', () {
    test('serializes core fields and formats appointment_date as YYYY-MM-DD', () {
      final c = CrewMember.fromJson({
        'id': 'c1',
        'grade': 'Alf',
        'first_name': 'Juan',
        'last_name': 'Perez',
        'nsa': '12345',
        'crew_category': 'pilot',
        'assignment_type': 'nato',
        'appointment_date': '2020-01-15',
        'qualifications': ['IP'],
        'callsign': 'JUAN',
      });
      final json = c.toJson();
      expect(json['grade'], 'Alf');
      expect(json['first_name'], 'Juan');
      expect(json['last_name'], 'Perez');
      expect(json['nsa'], '12345');
      expect(json['crew_category'], 'pilot');
      expect(json['assignment_type'], 'nato');
      expect(json['appointment_date'], '2020-01-15');
      expect(json['qualifications'], ['IP']);
      expect(json['callsign'], 'JUAN');
    });

    test('omits callsign when null', () {
      final c = CrewMember.fromJson({'id': 'c'});
      expect(c.toJson().containsKey('callsign'), isFalse);
    });
  });
}
