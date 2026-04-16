class AuthProfileModel {
  const AuthProfileModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.avatarUrl,
    this.unitPreferences = const {
      'energy': 'kWh',
      'power': 'W',
      'voltage': 'V',
    },
    this.notificationPreferences = const {
      'incidents': true,
      'device_status': true,
      'sharing': true,
    },
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? avatarUrl;
  final Map<String, dynamic> unitPreferences;
  final Map<String, dynamic> notificationPreferences;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'email': email.trim(),
      'avatar_url': avatarUrl,
      'unit_preferences': unitPreferences,
      'notification_preferences': notificationPreferences,
    };
  }
}
