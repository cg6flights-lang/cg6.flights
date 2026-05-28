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
  });

  final String id;
  final String email;
  final String displayName;
  final ProfileStatus status;
  final AppRole? role;
  final String? unitId;
  final String? unitName;

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
