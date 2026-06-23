import 'package:cg6_flights/core/security/app_permission.dart';
import 'package:cg6_flights/core/security/app_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppRole', () {
    test('key round-trips through fromKey for every role', () {
      for (final role in AppRole.values) {
        expect(AppRole.fromKey(role.key), role);
      }
    });

    test('fromKey returns null for unknown, empty or null keys', () {
      expect(AppRole.fromKey('unknown'), isNull);
      expect(AppRole.fromKey(''), isNull);
      expect(AppRole.fromKey(null), isNull);
    });

    test('keys match the persisted snake_case format', () {
      expect(AppRole.leader.key, 'leader');
      expect(AppRole.generalAdmin.key, 'general_admin');
      expect(AppRole.unitCommand.key, 'unit_command');
      expect(AppRole.unitAdmin.key, 'unit_admin');
      expect(AppRole.squadronChief.key, 'squadron_chief');
      expect(AppRole.ttaa.key, 'ttaa');
    });

    test('isGlobal is true only for leader and generalAdmin', () {
      expect(AppRole.leader.isGlobal, isTrue);
      expect(AppRole.generalAdmin.isGlobal, isTrue);
      for (final role in AppRole.values) {
        if (role == AppRole.leader || role == AppRole.generalAdmin) continue;
        expect(role.isGlobal, isFalse, reason: '$role should not be global');
      }
    });

    test('requiresUnit is the inverse of isGlobal', () {
      for (final role in AppRole.values) {
        expect(role.requiresUnit, !role.isGlobal);
      }
    });

    test('labelEs is non-empty for every role', () {
      for (final role in AppRole.values) {
        expect(role.labelEs.isNotEmpty, isTrue);
      }
    });
  });

  group('AppPermission', () {
    test('all contains representative permissions across domains', () {
      expect(AppPermission.all, contains(AppPermission.usersManage));
      expect(AppPermission.all, contains(AppPermission.aircraftManage));
      expect(AppPermission.all, contains(AppPermission.flightOrdersClose));
      expect(AppPermission.all, contains(AppPermission.trashRead));
      expect(AppPermission.all, contains(AppPermission.settingsManage));
    });
  });

  group('rolePermissionMatrix', () {
    test('leader has every permission', () {
      expect(rolePermissionMatrix[AppRole.leader], AppPermission.all);
    });

    test('every role has a non-empty subset of all permissions', () {
      for (final role in AppRole.values) {
        final perms = rolePermissionMatrix[role]!;
        expect(perms.isNotEmpty, isTrue, reason: '$role should have permissions');
        expect(
          AppPermission.all.containsAll(perms),
          isTrue,
          reason: '$role has a permission not declared in AppPermission.all',
        );
      }
    });

    test('unitAdmin can manage aircraft and crew, squadronChief cannot', () {
      expect(
        rolePermissionMatrix[AppRole.unitAdmin]!,
        contains(AppPermission.aircraftManage),
      );
      expect(
        rolePermissionMatrix[AppRole.unitAdmin]!,
        contains(AppPermission.crewManage),
      );
      expect(
        rolePermissionMatrix[AppRole.squadronChief]!,
        isNot(contains(AppPermission.aircraftManage)),
      );
    });

    test('generalAdmin can read but not manage users', () {
      expect(
        rolePermissionMatrix[AppRole.generalAdmin]!,
        contains(AppPermission.usersRead),
      );
      expect(
        rolePermissionMatrix[AppRole.generalAdmin]!,
        isNot(contains(AppPermission.usersManage)),
      );
    });

    test('ttaa has the most restricted set with no manage permissions', () {
      final perms = rolePermissionMatrix[AppRole.ttaa]!;
      expect(perms, isNot(contains(AppPermission.aircraftManage)));
      expect(perms, isNot(contains(AppPermission.crewManage)));
      expect(perms, isNot(contains(AppPermission.usersManage)));
      expect(perms, contains(AppPermission.flightsRead));
    });
  });
}
