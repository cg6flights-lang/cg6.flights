class OperationalDataPoint {
  const OperationalDataPoint({
    required this.periodLabel,
    required this.operational,
    required this.inoperative,
    required this.maintenance,
    required this.total,
    required this.operationalPct,
  });

  final String periodLabel;
  final int operational;
  final int inoperative;
  final int maintenance;
  final int total;
  final double operationalPct;

  factory OperationalDataPoint.fromJson(Map<String, dynamic> json) {
    return OperationalDataPoint(
      periodLabel: json['period_label'] as String,
      operational: (json['operational'] as num).toInt(),
      inoperative: (json['inoperative'] as num).toInt(),
      maintenance: (json['maintenance'] as num).toInt(),
      total: (json['total'] as num).toInt(),
      operationalPct: (json['operational_pct'] as num).toDouble(),
    );
  }
}
