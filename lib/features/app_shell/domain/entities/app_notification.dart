abstract class AppNotification {
  const AppNotification({
    required this.id,
    required this.createdAt,
  });

  final String id;
  final DateTime? createdAt;

  bool get isResolved;
}