class CadetCourse {
  const CadetCourse({
    required this.id,
    required this.unitId,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.cadetCount = 0,
  });

  final String id;
  final String unitId;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // 'active', 'archived'
  final int cadetCount;

  bool get isActive => status == 'active';

  factory CadetCourse.fromJson(Map<String, dynamic> json) {
    return CadetCourse(
      id: json['id'].toString(),
      unitId: json['unit_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      startDate: DateTime.tryParse(json['start_date']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['end_date']?.toString() ?? '') ?? DateTime.now(),
      status: json['status']?.toString() ?? 'active',
      cadetCount: json['cadet_count'] is int ? json['cadet_count'] as int : int.tryParse(json['cadet_count']?.toString() ?? '0') ?? 0,
    );
  }
}
