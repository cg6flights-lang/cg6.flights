class AuditLog {
  final String id;
  final String actorId;
  final String actorRole;
  final String? actorUnitId;
  final String action;
  final String resourceType;
  final String? resourceId;
  final String result; // 'success' | 'denied' | 'failed'
  final String? ipAddress;
  final String? userAgent;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const AuditLog({
    required this.id,
    required this.actorId,
    required this.actorRole,
    this.actorUnitId,
    required this.action,
    required this.resourceType,
    this.resourceId,
    required this.result,
    this.ipAddress,
    this.userAgent,
    this.metadata,
    required this.createdAt,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id']?.toString() ?? '',
      actorId: json['actor_id']?.toString() ?? '',
      actorRole: json['actor_role']?.toString() ?? '',
      actorUnitId: json['actor_unit_id']?.toString(),
      action: json['action']?.toString() ?? '',
      resourceType: json['resource_type']?.toString() ?? '',
      resourceId: json['resource_id']?.toString(),
      result: json['result']?.toString() ?? '',
      ipAddress: json['ip_address']?.toString(),
      userAgent: json['user_agent']?.toString(),
      metadata: json['metadata'] is Map ? Map<String, dynamic>.from(json['metadata']) : null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'actor_id': actorId,
    'actor_role': actorRole,
    'actor_unit_id': actorUnitId,
    'action': action,
    'resource_type': resourceType,
    'resource_id': resourceId,
    'result': result,
    'ip_address': ipAddress,
    'user_agent': userAgent,
    'metadata': metadata,
    'created_at': createdAt.toIso8601String(),
  };
}
