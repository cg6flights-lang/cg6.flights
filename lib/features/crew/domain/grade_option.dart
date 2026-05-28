class GradeOption {
  const GradeOption({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
  });

  final String id;
  final String code;
  final String name;
  final String category;

  factory GradeOption.fromJson(Map<String, dynamic> json) {
    return GradeOption(
      id: json['id'].toString(),
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'pilot',
    );
  }
}
