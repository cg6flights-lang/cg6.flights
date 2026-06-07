import 'package:cg6_flights/core/security/app_role.dart';
import 'package:cg6_flights/features/auth/domain/app_user.dart';

class ManagedProfile {
  const ManagedProfile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.status,
    this.role,
    this.unitId,
    this.unitName,
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
  });

  final String id;
  final String email;
  final String displayName;
  final ProfileStatus status;
  final AppRole? role;
  final String? unitId;
  final String? unitName;

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

  factory ManagedProfile.fromJson(Map<String, dynamic> json) {
    final unit = json['units'];
    return ManagedProfile(
      id: json['id'].toString(),
      email: json['email']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? 'Usuario',
      status: _statusFromKey(json['status']?.toString()),
      role: AppRole.fromKey(json['role']?.toString()),
      unitId: json['unit_id']?.toString(),
      unitName: unit is Map ? unit['name']?.toString() : null,
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
      documentType: json['document_type']?.toString(),
      documentId: json['document_id']?.toString(),
      phoneCountryCode: json['phone_country_code']?.toString(),
      phone: json['phone']?.toString(),
      birthDate: json['birth_date'] != null
          ? DateTime.tryParse(json['birth_date'].toString())
          : null,
      grade: json['grade']?.toString(),
      avatarPath: json['avatar_path']?.toString(),
      passwordChangedAt: json['password_changed_at'] != null
          ? DateTime.tryParse(json['password_changed_at'].toString())
          : null,
    );
  }

  static ProfileStatus _statusFromKey(String? key) {
    return switch (key) {
      'active' => ProfileStatus.active,
      'inactive' => ProfileStatus.inactive,
      'rejected' => ProfileStatus.rejected,
      _ => ProfileStatus.pending,
    };
  }
}
