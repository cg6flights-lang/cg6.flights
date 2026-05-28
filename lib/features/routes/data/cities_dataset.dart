const Map<String, List<String>> kCitiesByCountry = {
  'Argentina': ['Buenos Aires', 'Córdoba', 'Mendoza', 'Rosario', 'Bariloche'],
  'Belice': ['Belice'],
  'Bolivia': ['La Paz', 'Santa Cruz', 'Cochabamba', 'Sucre'],
  'Brasil': ['São Paulo', 'Río de Janeiro', 'Brasilia', 'Manaos', 'Recife', 'Salvador'],
  'Canadá': ['Toronto', 'Vancouver', 'Montreal', 'Ottawa'],
  'Chile': ['Santiago', 'Antofagasta', 'Concepción', 'Punta Arenas'],
  'Colombia': ['Bogotá', 'Medellín', 'Cali', 'Cartagena', 'Barranquilla'],
  'Costa Rica': ['San José', 'Liberia'],
  'Cuba': ['La Habana', 'Santiago de Cuba'],
  'Ecuador': ['Quito', 'Guayaquil', 'Manta', 'Cuenca'],
  'El Salvador': ['San Salvador'],
  'España': ['Madrid', 'Barcelona', 'Sevilla', 'Valencia', 'Málaga'],
  'Estados Unidos': ['Washington D.C.', 'Nueva York', 'Los Ángeles', 'Miami', 'Chicago', 'Houston', 'Atlanta'],
  'Francia': ['París', 'Lyon', 'Marsella', 'Toulouse'],
  'Guatemala': ['Ciudad de Guatemala'],
  'Honduras': ['Tegucigalpa', 'San Pedro Sula'],
  'Italia': ['Roma', 'Milán', 'Nápoles', 'Venecia'],
  'Jamaica': ['Kingston', 'Montego Bay'],
  'México': ['Ciudad de México', 'Cancún', 'Guadalajara', 'Monterrey', 'Tijuana'],
  'Nicaragua': ['Managua'],
  'Panamá': ['Ciudad de Panamá'],
  'Paraguay': ['Asunción', 'Ciudad del Este'],
  'Perú': ['Lima', 'Arequipa', 'Cusco', 'Iquitos', 'Piura', 'Trujillo', 'Pucallpa', 'Tarapoto'],
  'Portugal': ['Lisboa', 'Oporto'],
  'Reino Unido': ['Londres', 'Manchester', 'Edimburgo'],
  'República Dominicana': ['Santo Domingo', 'Punta Cana'],
  'Uruguay': ['Montevideo', 'Punta del Este'],
  'Venezuela': ['Caracas', 'Maracaibo', 'Valencia'],
};

List<String> get kCities {
  return kCitiesByCountry.values.expand((list) => list).toList()..sort();
}
