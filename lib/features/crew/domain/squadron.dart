class FlightSquadron {
  const FlightSquadron({
    required this.id,
    required this.unitId,
    required this.name,
    required this.displayOrder,
    required this.active,
  });

  final String id;
  final String unitId;
  final String name;
  final int displayOrder;
  final bool active;

  factory FlightSquadron.fromJson(Map<String, dynamic> json) {
    return FlightSquadron(
      id: json['id'].toString(),
      unitId: json['unit_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      displayOrder: json['display_order'] is int
          ? json['display_order'] as int
          : int.tryParse(json['display_order']?.toString() ?? '0') ?? 0,
      active: json['active'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'unit_id': unitId,
      'name': name,
      'display_order': displayOrder,
    };
  }
}
