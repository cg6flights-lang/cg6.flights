class Route {
  const Route({
    required this.id,
    required this.airportName,
    required this.category,
    required this.country,
    required this.city,
    required this.active,
    this.icaoCode,
    this.iataCode,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String airportName;
  final String category;
  final String? icaoCode;
  final String? iataCode;
  final String country;
  final String city;
  final double? latitude;
  final double? longitude;
  final bool active;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory Route.fromJson(Map<String, dynamic> json) {
    return Route(
      id: json['id'].toString(),
      airportName: json['airport_name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'internacional',
      icaoCode: json['icao_code']?.toString(),
      iataCode: json['iata_code']?.toString(),
      country: json['country']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      latitude: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
      active: json['active'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'airport_name': airportName,
      'category': category,
      'icao_code': icaoCode,
      'iata_code': iataCode,
      'country': country,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
