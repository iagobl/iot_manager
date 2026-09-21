class ProfileEntity {
  const ProfileEntity({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.avatarPath,
    this.avatarSignedUrl,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? avatarPath;
  final String? avatarSignedUrl;

  String get fullName {
    final value = '$firstName $lastName'.trim();

    if (value.isEmpty) {
      return email;
    }

    return value;
  }

  String get initials {
    final cleanFirstName = firstName.trim();
    final cleanLastName = lastName.trim();

    if (cleanFirstName.isNotEmpty && cleanLastName.isNotEmpty) {
      return '${cleanFirstName[0]}${cleanLastName[0]}'.toUpperCase();
    }

    if (cleanFirstName.isNotEmpty) {
      return cleanFirstName[0].toUpperCase();
    }

    if (email.trim().isNotEmpty) {
      return email.trim()[0].toUpperCase();
    }

    return '?';
  }

  ProfileEntity copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? avatarPath,
    String? avatarSignedUrl,
  }) {
    return ProfileEntity(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      avatarPath: avatarPath ?? this.avatarPath,
      avatarSignedUrl: avatarSignedUrl ?? this.avatarSignedUrl,
    );
  }
}
