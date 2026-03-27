import 'package:flutter/foundation.dart';
import 'package:iot_manager/core/error/app_exception.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';

class NotificationsController extends ChangeNotifier {
  NotificationsController({DevicesRemoteDatasource? remoteDatasource})
      : remoteDatasource = remoteDatasource ?? DevicesRemoteDatasource();

  final DevicesRemoteDatasource remoteDatasource;

  bool loading = false;
  String? errorMessage;
  List<DeviceInvitationNotification> items = [];

  int get pendingCount => items.where((e) => e.status == 'pending').length;
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
      final rows = await remoteDatasource.getPendingInvitations();
      items = rows.map(DeviceInvitationNotification.fromMap).toList();
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

    final index = items.indexWhere((e) => e.id == normalizedId);
    DeviceInvitationNotification? backup;

    if (index != -1) {
      backup = items[index];
      items.removeAt(index);
      clearError();
      notifyListeners();
    }

    try {
      await remoteDatasource.acceptInvitation(normalizedId);
      clearError();
      notifyListeners();
    } catch (error) {
      if (backup != null) {items.insert(index, backup);}

      setMappedError(error);
      notifyListeners();
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> reject(String shareId) async {
    final normalizedId = shareId.trim();
    if (normalizedId.isEmpty) {
      final error = const ValidationAppException('No se ha encontrado una invitación válida.');
      setMappedError(error);
      notifyListeners();
      throw error;
    }

    final index = items.indexWhere((e) => e.id == normalizedId);
    DeviceInvitationNotification? backup;

    if (index != -1) {
      backup = items[index];
      items.removeAt(index);
      clearError();
      notifyListeners();
    }

    try {
      await remoteDatasource.rejectInvitation(normalizedId);
      clearError();
      notifyListeners();
    } catch (error) {
      if (backup != null) {items.insert(index, backup);}
      setMappedError(error);
      notifyListeners();
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> refresh() async {
    await load();
  }
}

class DeviceInvitationNotification {
  const DeviceInvitationNotification({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
    required this.ownerId,
    required this.ownerName,
    required this.sharedWithEmail,
    required this.createdAt,
    required this.status,
  });

  factory DeviceInvitationNotification.fromMap(Map<String, dynamic> map) {
    return DeviceInvitationNotification(
      id: (map['id'] ?? '').toString(),
      deviceId: (map['device_id'] ?? '').toString(),
      deviceName: (map['device_name'] ?? 'Dispositivo').toString(),
      deviceType: (map['device_type'] ?? '').toString(),
      ownerId: (map['owner_id'] ?? '').toString(),
      ownerName: (map['owner_name'] ?? '').toString(),
      sharedWithEmail: (map['shared_with_email'] ?? '').toString(),
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()),
      status: (map['status'] ?? 'pending').toString(),
    );
  }

  final String id;
  final String deviceId;
  final String deviceName;
  final String? deviceType;
  final String ownerId;
  final String ownerName;
  final String sharedWithEmail;
  final DateTime? createdAt;
  final String status;
}