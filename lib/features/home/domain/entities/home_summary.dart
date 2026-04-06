class HomeSummary {
  HomeSummary({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.createdAt,
  });

  factory HomeSummary.fromMap(Map<String, dynamic> map) {
    final rawName = (map['name'] ?? '').toString().trim();

    return HomeSummary(
      id: (map['id'] ?? '').toString(),
      name: rawName.isEmpty ? 'Hogar sin nombre' : rawName,
      ownerId: (map['owner_id'] ?? '').toString(),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
    );
  }

  final String id;
  String name;
  final String ownerId;
  final DateTime? createdAt;
}