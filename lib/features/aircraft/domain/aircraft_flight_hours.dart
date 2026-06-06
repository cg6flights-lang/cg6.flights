class AircraftFlightHours {
  const AircraftFlightHours({
    required this.aircraftId,
    required this.tailNumber,
    required this.model,
    required this.status,
    required this.realHours,
    required this.plannedHours,
    required this.flightCount,
  });

  final String aircraftId;
  final String tailNumber;
  final String model;
  final String status;
  final double realHours;
  final double plannedHours;
  final int flightCount;

  double get diffHours => realHours - plannedHours;
  bool get isOperational => status == 'operational';

  factory AircraftFlightHours.fromJson(Map<String, dynamic> json) {
    return AircraftFlightHours(
      aircraftId: json['aircraft_id'].toString(),
      tailNumber: json['tail_number']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      status: json['status']?.toString() ?? 'operational',
      realHours: double.tryParse(json['real_hours']?.toString() ?? '0') ?? 0,
      plannedHours: double.tryParse(json['planned_hours']?.toString() ?? '0') ?? 0,
      flightCount: int.tryParse(json['flight_count']?.toString() ?? '0') ?? 0,
    );
  }
}
