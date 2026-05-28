import 'package:cg6_flights/core/security/app_permission.dart';
import 'package:cg6_flights/core/security/app_role.dart';

enum ProfileStatus { pending, active, inactive, rejected }

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.status,
    this.role,
    this.unitId,
    this.unitName,
    Set<String>? permissions,
  }) : permissions = permissions ?? const {};

  final String id;
  final String email;
  final String displayName;
  final ProfileStatus status;
  final AppRole? role;
  final String? unitId;
  final String? unitName;
  final Set<String> permissions;

  bool get isActive => status == ProfileStatus.active;

  bool get canOperate {
    if (!isActive || role == null) return false;
    if (role!.requiresUnit && unitId == null) return false;
    return true;
  }

  bool can(String permission) => permissions.contains(permission);

  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    ProfileStatus? status,
    AppRole? role,
    String? unitId,
    String? unitName,
    Set<String>? permissions,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      status: status ?? this.status,
      role: role ?? this.role,
      unitId: unitId ?? this.unitId,
      unitName: unitName ?? this.unitName,
      permissions: permissions ?? this.permissions,
    );
  }

  factory AppUser.demoLeader() {
    return const AppUser(
      id: 'local-leader',
      email: 'lider@cg6.local',
      displayName: 'Lider Operacional',
      status: ProfileStatus.active,
      role: AppRole.leader,
      unitName: 'Base Aerea Las Palmas',
      permissions: AppPermission.all,
    );
  }

  factory AppUser.pending({
    required String email,
    required String displayName,
  }) {
    return AppUser(
      id: 'pending-local-user',
      email: email,
      displayName: displayName,
      status: ProfileStatus.pending,
    );
  }
}
