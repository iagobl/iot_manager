class ProfileEntity {
  const ProfileEntity({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.unitPreferences,
    required this.notificationPreferences,
    this.avatarPath,
    this.avatarSignedUrl,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? avatarPath;
  final String? avatarSignedUrl;
  final Map<String, String> unitPreferences;
  final Map<String, bool> notificationPreferences;

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final first = firstName.trim().isEmpty ? '' : firstName.trim()[0];
    final last = lastName.trim().isEmpty ? '' : lastName.trim()[0];
    final text = '$first$last'.trim();
    return text.isEmpty ? 'U' : text.toUpperCase();
  }

  ProfileEntity copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? avatarPath,
    String? avatarSignedUrl,
    Map<String, String>? unitPreferences,
    Map<String, bool>? notificationPreferences,
  }) {
    return ProfileEntity(
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
}