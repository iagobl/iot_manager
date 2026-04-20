import 'package:iot_manager/features/app_shell/data/datasources/notifications_remote_datasource.dart';
import 'package:iot_manager/features/app_shell/data/models/device_incident_notification_model.dart';
import 'package:iot_manager/features/app_shell/data/models/device_invitation_notification_model.dart';
import 'package:iot_manager/features/app_shell/domain/entities/app_notification.dart';
import 'package:iot_manager/features/app_shell/domain/repositories/notifications_repository.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl({
    NotificationsRemoteDatasource? remoteDatasource,
  }) : remoteDatasource =
      remoteDatasource ?? NotificationsRemoteDatasource();

  final NotificationsRemoteDatasource remoteDatasource;

  @override
  Future<List<AppNotification>> getNotifications() async {
    final invitationRows = await remoteDatasource.getPendingInvitations();
    final incidentRows = await remoteDatasource.getUnreadIncidentNotifications();

    final invitationItems = invitationRows.map(DeviceInvitationNotificationModel.fromMap)
        .cast<AppNotification>();

    final incidentItems = incidentRows.map(DeviceIncidentNotificationModel.fromMap)
        .cast<AppNotification>();

    final items = <AppNotification>[...incidentItems, ...invitationItems];

    items.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return items;
  }

  @override
  Future<void> acceptInvitation(String shareId) {
    return remoteDatasource.acceptInvitation(shareId);
  }

  @override
  Future<void> rejectInvitation(String shareId) {
    return remoteDatasource.rejectInvitation(shareId);
  }

  @override
  Future<void> acknowledgeIncident(String incidentId) {
    return remoteDatasource.acknowledgeIncident(incidentId);
  }

  @override
  Stream<void> watchNotificationEvents() {
    return remoteDatasource.watchNotificationEvents();
  }

  @override
  Future<void> disposeWatcher() {
    return remoteDatasource.disposeWatcher();
  }
}
