class UnitOption {
  const UnitOption({
    required this.id,
    required this.code,
    required this.name,
    required this.active,
  });

  final String id;
  final String code;
  final String name;
  final bool active;

  factory UnitOption.fromJson(Map<String, dynamic> json) {
    return UnitOption(
      id: json['id'].toString(),
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      active: json['active'] == true,
    );
  }
}
