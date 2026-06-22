class MetarData {
  const MetarData({
    required this.icao,
    required this.raw,
    this.temp,
    this.dewpoint,
    this.windDir,
    this.windSpeed,
    this.visibility,
    this.qnh,
    this.flightCategory,
    this.observationTime,
  });

  final String icao;
  final String raw;
  final double? temp;
  final double? dewpoint;
  final int? windDir;
  final int? windSpeed;
  final double? visibility;
  final double? qnh;
  final String? flightCategory; // VFR, MVFR, IFR, LIFR
  final DateTime? observationTime;

  factory MetarData.fromJson(Map<String, dynamic> json) {
    return MetarData(
      icao: json['icaoId']?.toString() ?? '--',
      raw: json['rawOb']?.toString() ?? '',
      temp: double.tryParse(json['temp']?.toString() ?? ''),
      dewpoint: double.tryParse(json['dewp']?.toString() ?? ''),
      windDir: int.tryParse(json['wdir']?.toString() ?? ''),
      windSpeed: int.tryParse(json['wspd']?.toString() ?? ''),
      visibility: _parseNumber(json['visib']),
      qnh: double.tryParse(json['altim']?.toString() ?? ''),
      flightCategory: (json['fltCat'] ?? json['fltcat'])?.toString(),
      observationTime: _parseTime(json['obsTime'] ?? json['reportTime']),
    );
  }

  String get tempDisplay =>
      temp != null ? '${temp!.toStringAsFixed(0)}°C' : '--';
  String get windDisplay {
    if (windDir == null || windSpeed == null) return '--';
    return '${windDir.toString().padLeft(3, "0")}/${windSpeed}KT';
  }

  String get visDisplay => visibility != null
      ? '${(visibility! * 1.609344).toStringAsFixed(0)} Km'
      : '--';
  String get qnhDisplay =>
      qnh != null ? 'QNH ${qnh!.toStringAsFixed(0)}' : '--';

  String get categoryDisplay => switch (flightCategory) {
    'VFR' => 'VFR 🟢',
    'MVFR' => 'MVFR 🔵',
    'IFR' => 'IFR 🔴',
    'LIFR' => 'LIFR ⭕',
    _ => flightCategory ?? '--',
  };

  static double? _parseNumber(Object? value) {
    if (value == null) return null;
    final text = value.toString().replaceAll('+', '').trim();
    return double.tryParse(text);
  }

  static DateTime? _parseTime(Object? value) {
    if (value == null) return null;
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        (value * 1000).round(),
        isUtc: true,
      );
    }
    return DateTime.tryParse(value.toString());
  }
}

class TafData {
  const TafData({required this.icao, required this.raw});
  final String icao;
  final String raw;

  factory TafData.fromJson(Map<String, dynamic> json) {
    return TafData(
      icao: json['icaoId']?.toString() ?? '--',
      raw: (json['rawTAF'] ?? json['raw'])?.toString() ?? '',
    );
  }
}
