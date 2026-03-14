class DeviceItem {
  final String id;
  final String name;
  final String deviceType;
  final String protocol;
  final String identifier;
  final bool isActive;
  final String? homeId;
  final String? roomId;
  final double energyTodayWh;
  final DateTime? createdAt;

  const DeviceItem({
    required this.id,
    required this.name,
    required this.deviceType,
    required this.protocol,
    required this.identifier,
    required this.isActive,
    required this.homeId,
    required this.roomId,
    required this.energyTodayWh,
    required this.createdAt,
  });

  factory DeviceItem.fromMap(Map<String, dynamic> map) {
    return DeviceItem(
      id: (map['id'] ?? '').toString(),
      name: ((map['name'] ?? '') as String).trim().isEmpty
          ? 'Dispositivo sin nombre'
          : (map['name'] as String).trim(),
      deviceType: (map['device_type'] ?? 'desconocido').toString(),
      protocol: (map['protocol'] ?? 'N/D').toString(),
      identifier: (map['identifier'] ?? 'N/D').toString(),
      isActive: map['is_active'] == true,
      homeId: map['home_id']?.toString(),
      roomId: map['room_id']?.toString(),
      energyTodayWh: _toDouble(map['energy_today_wh']),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
