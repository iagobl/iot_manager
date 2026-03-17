import 'package:iot_manager/features/devices/domain/entities/device_item.dart';

class DeviceModel extends DeviceItem {
  DeviceModel({
    required super.id,
    required super.name,
    required super.deviceType,
    required super.protocol,
    required super.identifier,
    required super.isActive,
    required super.ownerId,
    required super.homeId,
    required super.roomId,
    required super.energyTodayWh,
  });

  factory DeviceModel.fromMap(Map<String, dynamic> map) {
    return DeviceModel(
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

  @override
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