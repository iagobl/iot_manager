class HomeSummary {

  const HomeSummary({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory HomeSummary.fromMap(Map<String, dynamic> map) {
    return HomeSummary(
      id: (map['id'] ?? '').toString(),
      name: ((map['name'] ?? '') as String).trim().isEmpty
          ? 'Hogar sin nombre'
          : (map['name'] as String).trim(),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
    );
  }
  final String id;
  final String name;
  final DateTime? createdAt;
}
