import 'dart:async';

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
  factory NotificationsController({
    NotificationsRepository? repository,
    GetNotifications? getNotifications,
    AcceptInvitationNotification? acceptInvitationNotification,
    RejectInvitationNotification? rejectInvitationNotification,
    AcknowledgeIncidentNotification? acknowledgeIncidentNotification,
  }) {
    final resolvedRepository = repository ?? NotificationsRepositoryImpl();

    return NotificationsController._(
      repository: resolvedRepository,
      getNotifications:
      getNotifications ?? GetNotifications(resolvedRepository),
      acceptInvitationNotification: acceptInvitationNotification ??
          AcceptInvitationNotification(resolvedRepository),
      rejectInvitationNotification: rejectInvitationNotification ??
          RejectInvitationNotification(resolvedRepository),
      acknowledgeIncidentNotification:
      acknowledgeIncidentNotification ??
          AcknowledgeIncidentNotification(resolvedRepository),
    );
  }

  NotificationsController._({
    required this.repository,
    required this.getNotifications,
    required this.acceptInvitationNotification,
    required this.rejectInvitationNotification,
    required this.acknowledgeIncidentNotification,
  });

  final NotificationsRepository repository;
  final GetNotifications getNotifications;
  final AcceptInvitationNotification acceptInvitationNotification;
  final RejectInvitationNotification rejectInvitationNotification;
  final AcknowledgeIncidentNotification acknowledgeIncidentNotification;

  bool loading = false;
  String? errorMessage;
  List<AppNotification> items = [];

  Timer? refreshTimer;
  StreamSubscription<void>? watchSubscription;
  bool disposed = false;

  int get pendingCount => items.where((e) => !e.isResolved).length;
  bool get hasError => errorMessage != null && errorMessage!.trim().isNotEmpty;

  void clearError() {
    errorMessage = null;
  }

  void setMappedError(Object error) {
    errorMessage =
        ErrorMapper.mapFailure(ErrorMapper.mapException(error)).message;
  }

  Future<void> startLiveUpdates() async {
    watchSubscription ??=
        repository.watchNotificationEvents().listen((_) async {
          await refreshSilently();
        });

    refreshTimer ??= Timer.periodic(
      const Duration(seconds: 20),
          (_) {
        unawaited(refreshSilently());
      },
    );

    if (items.isEmpty && !loading) {
      await load();
    }
  }

  Future<void> load() async {
    await _loadInternal(showLoader: true);
  }

  Future<void> refresh() async {
    await _loadInternal(showLoader: true);
  }

  Future<void> refreshSilently() async {
    await _loadInternal(showLoader: false);
  }

  Future<void> _loadInternal({required bool showLoader}) async {
    if (loading) return;

    if (showLoader) {
      loading = true;
      clearError();
      notifyListeners();
    } else {
      clearError();
    }

    try {
      items = await getNotifications();
    } catch (error) {
      setMappedError(error);
      if (showLoader) {
        items = [];
      }
    } finally {
      if (showLoader) {
        loading = false;
      }
      if (!disposed) {
        notifyListeners();
      }
    }
  }

  Future<void> accept(String shareId) async {
    final normalizedId = shareId.trim();
    if (normalizedId.isEmpty) {
      final error = const ValidationAppException(
        'No se ha encontrado una invitación válida.',
      );
      setMappedError(error);
      notifyListeners();
      throw error;
    }

    final index = items.indexWhere(
          (e) => e is DeviceInvitationNotification && e.id == normalizedId,
    );

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
      final error = const ValidationAppException(
        'No se ha encontrado una invitación válida.',
      );
      setMappedError(error);
      notifyListeners();
      throw error;
    }

    final index = items.indexWhere(
          (e) => e is DeviceInvitationNotification && e.id == normalizedId,
    );

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
      final error = const ValidationAppException(
        'No se ha encontrado una incidencia válida.',
      );
      setMappedError(error);
      notifyListeners();
      throw error;
    }

    final index = items.indexWhere(
          (e) => e is DeviceIncidentNotification && e.id == normalizedId,
    );

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

  @override
  void dispose() {
    disposed = true;
    refreshTimer?.cancel();
    watchSubscription?.cancel();
    unawaited(repository.disposeWatcher());
    super.dispose();
  }
}
