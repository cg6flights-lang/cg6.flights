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
    this.firstName,
    this.lastName,
    this.documentType,
    this.documentId,
    this.phoneCountryCode,
    this.phone,
    this.birthDate,
    this.grade,
    this.avatarPath,
    this.passwordChangedAt,
  }) : permissions = permissions ?? const {};

  final String id;
  final String email;
  final String displayName;
  final ProfileStatus status;
  final AppRole? role;
  final String? unitId;
  final String? unitName;
  final Set<String> permissions;

  // Extended profile fields
  final String? firstName;
  final String? lastName;
  final String? documentType;
  final String? documentId;
  final String? phoneCountryCode;
  final String? phone;
  final DateTime? birthDate;
  final String? grade;
  final String? avatarPath;
  final DateTime? passwordChangedAt;

  bool get isActive => status == ProfileStatus.active;

  bool get hasChangedPassword => passwordChangedAt != null;

  bool get canOperate {
    if (!isActive || role == null) return false;
    if (role!.requiresUnit && unitId == null) return false;
    return true;
  }

  bool can(String permission) => permissions.contains(permission);

  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    return displayName;
  }

  String get greetingName {
    final buffer = StringBuffer();
    if (grade != null) buffer.write('$grade ');
    buffer.write(fullName);
    return buffer.toString().trim();
  }

  String get initials {
    if (firstName != null && lastName != null) {
      final fi = firstName!.isNotEmpty ? firstName![0].toUpperCase() : '';
      final li = lastName!.isNotEmpty ? lastName![0].toUpperCase() : '';
      if (fi.isNotEmpty && li.isNotEmpty) return '$fi$li';
    }
    if (displayName.isNotEmpty) {
      final parts = displayName.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return displayName[0].toUpperCase();
    }
    return '?';
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    ProfileStatus? status,
    AppRole? role,
    String? unitId,
    String? unitName,
    Set<String>? permissions,
    String? firstName,
    String? lastName,
    String? documentType,
    String? documentId,
    String? phoneCountryCode,
    String? phone,
    DateTime? birthDate,
    String? grade,
    String? avatarPath,
    DateTime? passwordChangedAt,
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
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      documentType: documentType ?? this.documentType,
      documentId: documentId ?? this.documentId,
      phoneCountryCode: phoneCountryCode ?? this.phoneCountryCode,
      phone: phone ?? this.phone,
      birthDate: birthDate ?? this.birthDate,
      grade: grade ?? this.grade,
      avatarPath: avatarPath ?? this.avatarPath,
      passwordChangedAt: passwordChangedAt ?? this.passwordChangedAt,
    );
  }

  factory AppUser.demoLeader() {
    return AppUser(
      id: 'local-leader',
      email: 'lider@cg6.local',
      displayName: 'Lider Operacional',
      status: ProfileStatus.active,
      role: AppRole.leader,
      unitName: 'Base Aerea Las Palmas',
      permissions: AppPermission.all,
      firstName: 'Lider',
      lastName: 'Operacional',
      grade: 'COR FAP',
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
