import 'package:cg6_flights/features/flights/domain/metar_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses Aviation Weather METAR json fields', () {
    final metar = MetarData.fromJson({
      'icaoId': 'SPJC',
      'obsTime': 1780279200,
      'temp': 23,
      'dewp': 19,
      'wdir': 160,
      'wspd': 12,
      'visib': '6+',
      'altim': 1013,
      'rawOb': 'METAR SPJC 010200Z 16012KT 9999 OVC010 23/19 Q1013',
      'fltCat': 'MVFR',
    });

    expect(metar.icao, 'SPJC');
    expect(metar.raw, contains('METAR SPJC'));
    expect(metar.visibility, 6);
    expect(metar.flightCategory, 'MVFR');
    expect(metar.observationTime, DateTime.utc(2026, 6, 1, 2));
  });

  test('parses Aviation Weather TAF rawTAF field', () {
    final taf = TafData.fromJson({
      'icaoId': 'SPJC',
      'rawTAF': 'TAF SPJC 312310Z 0100/0124 17008KT 7000 OVC012',
    });

    expect(taf.icao, 'SPJC');
    expect(taf.raw, startsWith('TAF SPJC'));
  });
}
