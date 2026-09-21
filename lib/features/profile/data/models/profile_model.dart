import 'package:iot_manager/features/profile/domain/entities/profile_entity.dart';

class ProfileModel extends ProfileEntity {
  const ProfileModel({
    required super.id,
    required super.firstName,
    required super.lastName,
    required super.email,
    super.avatarPath,
    super.avatarSignedUrl,
  });

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      id: (map['id'] ?? '').toString(),
      firstName: (map['first_name'] ?? '').toString(),
      lastName: (map['last_name'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      avatarPath: map['avatar_url']?.toString(),
    );
  }

  ProfileModel copyWithModel({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? avatarPath,
    String? avatarSignedUrl,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      avatarPath: avatarPath ?? this.avatarPath,
      avatarSignedUrl: avatarSignedUrl ?? this.avatarSignedUrl,
    );
  }
}
