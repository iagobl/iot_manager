class DeviceItem {

  const DeviceItem({
    required this.id,
    required this.name,
    required this.deviceType,
    required this.protocol,
    required this.identifier,
    required this.isActive,
    required this.ownerId,
    required this.homeId,
    required this.roomId,
    required this.energyTodayWh,
  });

  factory DeviceItem.fromMap(Map<String, dynamic> map) {
    return DeviceItem(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      deviceType: map['device_type'] as String? ?? '',
      protocol: map['protocol'] as String? ?? 'http',
      identifier: map['identifier'] as String? ?? '',
      isActive: map['is_active'] as bool? ?? false,
      ownerId: map['owner_id'] as String? ?? '',
      homeId: map['home_id'] as String?,
      roomId: map['room_id'] as String?,
      energyTodayWh: (map['energy_today_wh'] ?? 0).toDouble(),
    );
  }
  final String id;
  final String name;
  final String deviceType;
  final String protocol;
  final String identifier;
  final bool isActive;
  final String ownerId;
  final String? homeId;
  final String? roomId;
  final double energyTodayWh;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'device_type': deviceType,
      'protocol': protocol,
      'identifier': identifier,
      'is_active': isActive,
      'owner_id': ownerId,
      'home_id': homeId,
      'room_id': roomId,
      'energy_today_wh': energyTodayWh,
    };
  }
}