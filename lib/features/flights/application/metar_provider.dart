import 'dart:convert';

import 'package:cg6_flights/core/config/supabase_config.dart';
import 'package:cg6_flights/features/flights/domain/metar_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

final metarByIcaoProvider = FutureProvider.family<MetarData?, String>((
  ref,
  icao,
) async {
  ref.keepAlive();
  try {
    final normalizedIcao = _normalizeIcao(icao);
    if (normalizedIcao == null) return null;

    final data = await _fetchAviationWeather('metar', normalizedIcao);
    if (data.isNotEmpty) {
      return MetarData.fromJson(Map<String, dynamic>.from(data.first as Map));
    }
  } catch (_) {}
  return null;
});

final tafByIcaoProvider = FutureProvider.family<List<TafData>, String>((
  ref,
  icao,
) async {
  ref.keepAlive();
  try {
    final normalizedIcao = _normalizeIcao(icao);
    if (normalizedIcao == null) return [];

    final data = await _fetchAviationWeather('taf', normalizedIcao);
    return data
        .map((e) => TafData.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  } catch (_) {}
  return [];
});

String? _normalizeIcao(String icao) {
  final normalized = icao.trim().toUpperCase();
  return RegExp(r'^[A-Z]{4}$').hasMatch(normalized) ? normalized : null;
}

Future<List<dynamic>> _fetchAviationWeather(
  String reportType,
  String icao,
) async {
  if (SupabaseConfig.isConfigured) {
    return _fetchAviationWeatherViaProxy(reportType, icao);
  }
  return _fetchAviationWeatherDirect(reportType, icao);
}

Future<List<dynamic>> _fetchAviationWeatherViaProxy(
  String reportType,
  String icao,
) async {
  final response = await Supabase.instance.client.functions
      .invoke(
        'aviation-weather',
        body: {'report_type': reportType, 'icao': icao},
      )
      .timeout(const Duration(seconds: 10));
  final body = response.data;
  if (body is Map && body['ok'] == true && body['data'] is List) {
    return List<dynamic>.from(body['data'] as List);
  }
  return [];
}

Future<List<dynamic>> _fetchAviationWeatherDirect(
  String reportType,
  String icao,
) async {
  final uri = Uri.https('aviationweather.gov', '/api/data/$reportType', {
    'ids': icao,
    'format': 'json',
  });
  final response = await http
      .get(uri, headers: const {'Accept': 'application/json'})
      .timeout(const Duration(seconds: 10));
  if (response.statusCode != 200) return [];
  final body = jsonDecode(response.body);
  return body is List ? body : [];
}
