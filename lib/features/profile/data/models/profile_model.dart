import 'package:iot_manager/features/profile/domain/entities/profile_entity.dart';

class ProfileModel extends ProfileEntity {
  const ProfileModel({
    required super.id,
    required super.firstName,
    required super.lastName,
    required super.email,
    required super.unitPreferences,
    required super.notificationPreferences,
    super.avatarPath,
    super.avatarSignedUrl,
  });

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    final avatarPath = (map['avatar_url'] ?? '').toString().trim();

    return ProfileModel(
      id: (map['id'] ?? '').toString(),
      firstName: (map['first_name'] ?? '').toString(),
      lastName: (map['last_name'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      avatarPath: avatarPath.isEmpty ? null : avatarPath,
      unitPreferences: normalizeUnitPreferences(map['unit_preferences']),
      notificationPreferences:
      normalizeNotificationPreferences(map['notification_preferences']),
    );
  }

  ProfileModel copyWithModel({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? avatarPath,
    String? avatarSignedUrl,
    Map<String, String>? unitPreferences,
    Map<String, bool>? notificationPreferences,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      avatarPath: avatarPath ?? this.avatarPath,
      avatarSignedUrl: avatarSignedUrl ?? this.avatarSignedUrl,
      unitPreferences: unitPreferences ?? this.unitPreferences,
      notificationPreferences:
      notificationPreferences ?? this.notificationPreferences,
    );
  }

  static Map<String, String> normalizeUnitPreferences(dynamic raw) {
    if (raw is Map) {
      return {
        'energy': (raw['energy'] ?? 'kWh').toString(),
        'power': (raw['power'] ?? 'W').toString(),
        'voltage': (raw['voltage'] ?? 'V').toString(),
      };
    }

    return {
      'energy': 'kWh',
      'power': 'W',
      'voltage': 'V',
    };
  }

  static Map<String, bool> normalizeNotificationPreferences(dynamic raw) {
    bool parseBool(dynamic value, bool fallback) {
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
      return fallback;
    }

    if (raw is Map) {
      return {
        'incidents': parseBool(raw['incidents'], true),
        'device_status': parseBool(raw['device_status'], true),
        'sharing': parseBool(raw['sharing'], true),
      };
    }

    return {
      'incidents': true,
      'device_status': true,
      'sharing': true,
    };
  }
}