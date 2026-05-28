class AirportData {
  const AirportData({
    required this.name,
    required this.icao,
    required this.iata,
    required this.city,
    required this.country,
    required this.lat,
    required this.lng,
  });

  final String name;
  final String icao;
  final String iata;
  final String city;
  final String country;
  final double lat;
  final double lng;

  String get displayName => '$name ($icao)';
}

const List<AirportData> kAirports = [
  // Perú
  AirportData(name: 'Aeropuerto Internacional Jorge Chávez', icao: 'SPJC', iata: 'LIM', city: 'Lima', country: 'Perú', lat: -12.0219, lng: -77.1143),
  AirportData(name: 'Aeropuerto Internacional Rodríguez Ballón', icao: 'SPQU', iata: 'AQP', city: 'Arequipa', country: 'Perú', lat: -16.3411, lng: -71.5831),
  AirportData(name: 'Aeropuerto Internacional Alejandro Velasco Astete', icao: 'SPZO', iata: 'CUZ', city: 'Cusco', country: 'Perú', lat: -13.5357, lng: -71.9388),
  AirportData(name: 'Aeropuerto Internacional Coronel FAP Francisco Secada', icao: 'SPQT', iata: 'IQT', city: 'Iquitos', country: 'Perú', lat: -3.7847, lng: -73.3088),
  AirportData(name: 'Aeropuerto Internacional Capitán FAP Guillermo Concha', icao: 'SPUR', iata: 'PIU', city: 'Piura', country: 'Perú', lat: -5.2056, lng: -80.6164),
  AirportData(name: 'Aeropuerto Internacional Capitán FAP Carlos Martínez de Pinillos', icao: 'SPRU', iata: 'TRU', city: 'Trujillo', country: 'Perú', lat: -8.0814, lng: -79.1088),
  AirportData(name: 'Aeropuerto Internacional Capitán FAP David Abensur Rengifo', icao: 'SPCL', iata: 'PCL', city: 'Pucallpa', country: 'Perú', lat: -8.3779, lng: -74.5743),
  AirportData(name: 'Aeropuerto Cadete FAP Guillermo del Castillo Paredes', icao: 'SPST', iata: 'TPP', city: 'Tarapoto', country: 'Perú', lat: -6.5087, lng: -76.3732),
  AirportData(name: 'Base Aérea Las Palmas', icao: 'SPLP', iata: '', city: 'Lima', country: 'Perú', lat: -12.1628, lng: -76.9955),
  AirportData(name: 'Aeropuerto Internacional Inca Manco Cápac', icao: 'SPJL', iata: 'JUL', city: 'Juliaca', country: 'Perú', lat: -15.4671, lng: -70.1582),
  AirportData(name: 'Aeropuerto Internacional Coronel Carlos Ciriani Santa Rosa', icao: 'SPTN', iata: 'TCQ', city: 'Tacna', country: 'Perú', lat: -18.0533, lng: -70.2758),
  AirportData(name: 'Aeródromo de Collique', icao: 'SPOL', iata: '', city: 'Lima', country: 'Perú', lat: -11.9286, lng: -77.0633),

  // Argentina
  AirportData(name: 'Aeropuerto Internacional Ministro Pistarini', icao: 'SAEZ', iata: 'EZE', city: 'Buenos Aires', country: 'Argentina', lat: -34.8222, lng: -58.5358),
  AirportData(name: 'Aeroparque Jorge Newbery', icao: 'SABE', iata: 'AEP', city: 'Buenos Aires', country: 'Argentina', lat: -34.5592, lng: -58.4156),
  AirportData(name: 'Aeropuerto Internacional Ing. Ambrosio Taravella', icao: 'SACO', iata: 'COR', city: 'Córdoba', country: 'Argentina', lat: -31.3236, lng: -64.2080),

  // Bolivia
  AirportData(name: 'Aeropuerto Internacional El Alto', icao: 'SLLP', iata: 'LPB', city: 'La Paz', country: 'Bolivia', lat: -16.5133, lng: -68.1923),
  AirportData(name: 'Aeropuerto Internacional Viru Viru', icao: 'SLVR', iata: 'VVI', city: 'Santa Cruz', country: 'Bolivia', lat: -17.6448, lng: -63.1354),

  // Brasil
  AirportData(name: 'Aeropuerto Internacional de São Paulo-Guarulhos', icao: 'SBGR', iata: 'GRU', city: 'São Paulo', country: 'Brasil', lat: -23.4356, lng: -46.4731),
  AirportData(name: 'Aeropuerto Internacional de Galeão', icao: 'SBGL', iata: 'GIG', city: 'Río de Janeiro', country: 'Brasil', lat: -22.8100, lng: -43.2506),
  AirportData(name: 'Aeropuerto Internacional de Brasilia', icao: 'SBBR', iata: 'BSB', city: 'Brasilia', country: 'Brasil', lat: -15.8697, lng: -47.9208),

  // Chile
  AirportData(name: 'Aeropuerto Internacional Arturo Merino Benítez', icao: 'SCEL', iata: 'SCL', city: 'Santiago', country: 'Chile', lat: -33.3930, lng: -70.7858),
  AirportData(name: 'Aeropuerto Internacional Cerro Moreno', icao: 'SCFA', iata: 'ANF', city: 'Antofagasta', country: 'Chile', lat: -23.4444, lng: -70.4450),

  // Colombia
  AirportData(name: 'Aeropuerto Internacional El Dorado', icao: 'SKBO', iata: 'BOG', city: 'Bogotá', country: 'Colombia', lat: 4.7016, lng: -74.1469),
  AirportData(name: 'Aeropuerto Internacional José María Córdova', icao: 'SKRG', iata: 'MDE', city: 'Medellín', country: 'Colombia', lat: 6.1645, lng: -75.4231),
  AirportData(name: 'Aeropuerto Internacional Alfonso Bonilla Aragón', icao: 'SKCL', iata: 'CLO', city: 'Cali', country: 'Colombia', lat: 3.5432, lng: -76.3816),

  // Ecuador
  AirportData(name: 'Aeropuerto Internacional Mariscal Sucre', icao: 'SEQM', iata: 'UIO', city: 'Quito', country: 'Ecuador', lat: -0.1292, lng: -78.3575),
  AirportData(name: 'Aeropuerto Internacional José Joaquín de Olmedo', icao: 'SEGU', iata: 'GYE', city: 'Guayaquil', country: 'Ecuador', lat: -2.1575, lng: -79.8836),

  // México
  AirportData(name: 'Aeropuerto Internacional Benito Juárez', icao: 'MMMX', iata: 'MEX', city: 'Ciudad de México', country: 'México', lat: 19.4363, lng: -99.0721),
  AirportData(name: 'Aeropuerto Internacional de Cancún', icao: 'MMUN', iata: 'CUN', city: 'Cancún', country: 'México', lat: 21.0365, lng: -86.8771),

  // Panamá
  AirportData(name: 'Aeropuerto Internacional de Tocumen', icao: 'MPTO', iata: 'PTY', city: 'Ciudad de Panamá', country: 'Panamá', lat: 9.0714, lng: -79.3835),

  // Venezuela
  AirportData(name: 'Aeropuerto Internacional de Maiquetía Simón Bolívar', icao: 'SVMI', iata: 'CCS', city: 'Caracas', country: 'Venezuela', lat: 10.6031, lng: -66.9906),

  // Estados Unidos
  AirportData(name: 'Aeropuerto Internacional John F. Kennedy', icao: 'KJFK', iata: 'JFK', city: 'Nueva York', country: 'Estados Unidos', lat: 40.6413, lng: -73.7781),
  AirportData(name: 'Aeropuerto Internacional de Los Ángeles', icao: 'KLAX', iata: 'LAX', city: 'Los Ángeles', country: 'Estados Unidos', lat: 33.9416, lng: -118.4085),
  AirportData(name: 'Aeropuerto Internacional de Miami', icao: 'KMIA', iata: 'MIA', city: 'Miami', country: 'Estados Unidos', lat: 25.7959, lng: -80.2870),

  // España
  AirportData(name: 'Aeropuerto Adolfo Suárez Madrid-Barajas', icao: 'LEMD', iata: 'MAD', city: 'Madrid', country: 'España', lat: 40.4983, lng: -3.5676),
  AirportData(name: 'Aeropuerto Josep Tarradellas Barcelona-El Prat', icao: 'LEBL', iata: 'BCN', city: 'Barcelona', country: 'España', lat: 41.2974, lng: 2.0833),

  // Francia
  AirportData(name: 'Aeropuerto Charles de Gaulle', icao: 'LFPG', iata: 'CDG', city: 'París', country: 'Francia', lat: 49.0097, lng: 2.5479),

  // Reino Unido
  AirportData(name: 'Aeropuerto de Londres-Heathrow', icao: 'EGLL', iata: 'LHR', city: 'Londres', country: 'Reino Unido', lat: 51.4700, lng: -0.4543),

  // Italia
  AirportData(name: 'Aeropuerto Leonardo da Vinci-Fiumicino', icao: 'LIRF', iata: 'FCO', city: 'Roma', country: 'Italia', lat: 41.8003, lng: 12.2389),

  // Paraguay
  AirportData(name: 'Aeropuerto Internacional Silvio Pettirossi', icao: 'SGAS', iata: 'ASU', city: 'Asunción', country: 'Paraguay', lat: -25.2397, lng: -57.5191),

  // Uruguay
  AirportData(name: 'Aeropuerto Internacional de Carrasco', icao: 'SUMU', iata: 'MVD', city: 'Montevideo', country: 'Uruguay', lat: -34.8384, lng: -56.0308),

  // Costa Rica
  AirportData(name: 'Aeropuerto Internacional Juan Santamaría', icao: 'MROC', iata: 'SJO', city: 'San José', country: 'Costa Rica', lat: 9.9939, lng: -84.2089),

  // Cuba
  AirportData(name: 'Aeropuerto Internacional José Martí', icao: 'MUHA', iata: 'HAV', city: 'La Habana', country: 'Cuba', lat: 22.9892, lng: -82.4091),

  // República Dominicana
  AirportData(name: 'Aeropuerto Internacional de Punta Cana', icao: 'MDPC', iata: 'PUJ', city: 'Punta Cana', country: 'República Dominicana', lat: 18.5674, lng: -68.3634),

  // Portugal
  AirportData(name: 'Aeropuerto Humberto Delgado', icao: 'LPPT', iata: 'LIS', city: 'Lisboa', country: 'Portugal', lat: 38.7742, lng: -9.1342),
];
