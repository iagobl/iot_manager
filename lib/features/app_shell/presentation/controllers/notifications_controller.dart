import 'package:flutter/foundation.dart';
import 'package:iot_manager/core/error/app_exception.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/features/app_shell/data/repositories/notifications_repository_impl.dart';
import 'package:iot_manager/features/app_shell/domain/entities/app_notification.dart';
import 'package:iot_manager/features/app_shell/domain/entities/device_incident_notification.dart';
import 'package:iot_manager/features/app_shell/domain/entities/device_invitation_notification.dart';
import 'package:iot_manager/features/app_shell/domain/repositories/notifications_repository.dart';
import 'package:iot_manager/features/app_shell/domain/usecases/accept_invitation_notification.dart';
import 'package:iot_manager/features/app_shell/domain/usecases/acknowledge_incident_notification.dart';
import 'package:iot_manager/features/app_shell/domain/usecases/get_notifications.dart';
import 'package:iot_manager/features/app_shell/domain/usecases/reject_invitation_notification.dart';

class NotificationsController extends ChangeNotifier {
  NotificationsController({
    NotificationsRepository? repository,
    GetNotifications? getNotifications,
    AcceptInvitationNotification? acceptInvitationNotification,
    RejectInvitationNotification? rejectInvitationNotification,
    AcknowledgeIncidentNotification? acknowledgeIncidentNotification,
  })  : repository = repository ?? NotificationsRepositoryImpl(),
        getNotifications = getNotifications ?? GetNotifications(repository ?? NotificationsRepositoryImpl()),
        acceptInvitationNotification = acceptInvitationNotification ??
            AcceptInvitationNotification(repository ?? NotificationsRepositoryImpl()),
        rejectInvitationNotification = rejectInvitationNotification ??
            RejectInvitationNotification(repository ?? NotificationsRepositoryImpl()),
        acknowledgeIncidentNotification = acknowledgeIncidentNotification ??
            AcknowledgeIncidentNotification(repository ?? NotificationsRepositoryImpl());

  final NotificationsRepository repository;
  final GetNotifications getNotifications;
  final AcceptInvitationNotification acceptInvitationNotification;
  final RejectInvitationNotification rejectInvitationNotification;
  final AcknowledgeIncidentNotification acknowledgeIncidentNotification;

  bool loading = false;
  String? errorMessage;
  List<AppNotification> items = [];

  int get pendingCount => items.where((e) => !e.isResolved).length;
  bool get hasError => errorMessage != null && errorMessage!.trim().isNotEmpty;

  void clearError() {
    errorMessage = null;
  }

  void setMappedError(Object error) {
    errorMessage = ErrorMapper.mapFailure(ErrorMapper.mapException(error)).message;
  }

  Future<void> load() async {
    loading = true;
    clearError();
    notifyListeners();

    try {
      items = await getNotifications();
    } catch (error) {
      setMappedError(error);
      items = [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> accept(String shareId) async {
    final normalizedId = shareId.trim();
    if (normalizedId.isEmpty) {
      final error = const ValidationAppException('No se ha encontrado una invitación válida.');
      setMappedError(error);
      notifyListeners();
      throw error;
    }

    final index = items.indexWhere((e) => e is DeviceInvitationNotification && e.id == normalizedId);

    AppNotification? backup;
    if (index != -1) {
      backup = items[index];
      items.removeAt(index);
      clearError();
      notifyListeners();
    }

    try {
      await acceptInvitationNotification(normalizedId);
      clearError();
      notifyListeners();
    } catch (error) {
      if (backup != null) {
        items.insert(index, backup);
      }
      setMappedError(error);
      notifyListeners();
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> reject(String shareId) async {
    final normalizedId = shareId.trim();
    if (normalizedId.isEmpty) {
      final error = const ValidationAppException('No se ha encontrado una invitación válida.',);
      setMappedError(error);
      notifyListeners();
      throw error;
    }

    final index = items.indexWhere((e) => e is DeviceInvitationNotification && e.id == normalizedId);

    AppNotification? backup;
    if (index != -1) {
      backup = items[index];
      items.removeAt(index);
      clearError();
      notifyListeners();
    }

    try {
      await rejectInvitationNotification(normalizedId);
      clearError();
      notifyListeners();
    } catch (error) {
      if (backup != null) {
        items.insert(index, backup);
      }
      setMappedError(error);
      notifyListeners();
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> acknowledgeIncident(String incidentId) async {
    final normalizedId = incidentId.trim();
    if (normalizedId.isEmpty) {
      final error = const ValidationAppException('No se ha encontrado una incidencia válida.');
      setMappedError(error);
      notifyListeners();
      throw error;
    }

    final index = items.indexWhere((e) => e is DeviceIncidentNotification && e.id == normalizedId);

    AppNotification? backup;
    if (index != -1) {
      backup = items[index];
      items.removeAt(index);
      clearError();
      notifyListeners();
    }

    try {
      await acknowledgeIncidentNotification(normalizedId);
      clearError();
      notifyListeners();
    } catch (error) {
      if (backup != null) {
        items.insert(index, backup);
      }
      setMappedError(error);
      notifyListeners();
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> refresh() async {
    await load();
  }
}