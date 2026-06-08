class Aircraft {
  const Aircraft({
    required this.id,
    required this.unitId,
    required this.tailNumber,
    required this.model,
    required this.manufacturer,
    required this.status,
    required this.active,
    this.serialNumber,
    this.year,
    this.inoperativeReason,
    this.obTailNumber,
    this.displayRegistration = 'FAP',
    this.squadronId,
    this.squadronName,
    this.squadronIds = const [],
    this.lastFlightAt,
    this.lastFlightOrderNumber,
    this.daysWithoutFlying,
  });

  final String id;
  final String unitId;
  final String tailNumber;
  final String model;
  final String manufacturer;
  final String status;
  final bool active;
  final String? serialNumber;
  final int? year;
  final String? inoperativeReason;
  final String? obTailNumber;
  final String displayRegistration; // 'FAP' or 'OB'
  final String? squadronId;
  final String? squadronName;
  final List<String> squadronIds; // M:N junction
  final DateTime? lastFlightAt;
  final String? lastFlightOrderNumber;
  final int? daysWithoutFlying;

  bool get isOperational => status == 'operational';

  /// The registration to display across the system.
  /// Returns OB tail number when OB is selected and available, otherwise FAP.
  String get displayTailNumber {
    if (displayRegistration == 'OB' &&
        obTailNumber != null &&
        obTailNumber!.isNotEmpty) {
      return obTailNumber!;
    }
    return tailNumber;
  }

  factory Aircraft.fromJson(Map<String, dynamic> json) {
    return Aircraft(
      id: json['id'].toString(),
      unitId: json['unit_id']?.toString() ?? '',
      tailNumber: json['tail_number']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      manufacturer: json['manufacturer']?.toString() ?? '',
      status: json['status']?.toString() ?? 'operational',
      active: json['active'] == true,
      serialNumber: json['serial_number']?.toString(),
      year: json['year'] != null ? int.tryParse(json['year'].toString()) : null,
      inoperativeReason: json['inoperative_reason']?.toString(),
      obTailNumber: json['ob_tail_number']?.toString(),
      displayRegistration: json['display_registration']?.toString() ?? 'FAP',
      squadronId: json['squadron_id']?.toString(),
      squadronName: json['flight_squadrons'] is Map
          ? (json['flight_squadrons'] as Map)['name']?.toString()
          : null,
      squadronIds:
          (json['squadron_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          (json['aircraft_squadrons'] is List
              ? (json['aircraft_squadrons'] as List)
                    .map((r) => (r as Map)['squadron_id']?.toString() ?? '')
                    .where((id) => id.isNotEmpty)
                    .toList()
              : <String>[]),
      lastFlightAt: json['last_flight_at'] != null
          ? DateTime.tryParse(json['last_flight_at'].toString())
          : null,
      lastFlightOrderNumber: json['last_flight_order_number']?.toString(),
      daysWithoutFlying: json['days_without_flying'] != null
          ? int.tryParse(json['days_without_flying'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'unit_id': unitId,
      'tail_number': tailNumber,
      'model': model,
      'manufacturer': manufacturer,
      'serial_number': serialNumber,
      'year': year,
      'status': status,
      'inoperative_reason': inoperativeReason,
      if (obTailNumber != null) 'ob_tail_number': obTailNumber,
      'display_registration': displayRegistration,
    };
  }
}
