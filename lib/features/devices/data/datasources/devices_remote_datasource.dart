import 'package:iot_manager/features/devices/data/datasources/device_automations_remote_datasource.dart';
import 'package:iot_manager/features/devices/data/datasources/device_base_remote_datasource.dart';
import 'package:iot_manager/features/devices/data/datasources/device_incidents_remote_datasource.dart';
import 'package:iot_manager/features/devices/data/datasources/device_readings_remote_datasource.dart';
import 'package:iot_manager/features/devices/data/datasources/device_shares_remote_datasource.dart';
import 'package:iot_manager/features/devices/domain/entities/device_item.dart';

class DevicesRemoteDatasource {
  DevicesRemoteDatasource()
      : baseDatasource = DeviceBaseRemoteDatasource(),
        sharesDatasource = DeviceSharesRemoteDatasource(),
        incidentsDatasource = DeviceIncidentsRemoteDatasource(),
        automationsDatasource = DeviceAutomationsRemoteDatasource(),
        readingsDatasource = DeviceReadingsRemoteDatasource();

  final DeviceBaseRemoteDatasource baseDatasource;
  final DeviceSharesRemoteDatasource sharesDatasource;
  final DeviceIncidentsRemoteDatasource incidentsDatasource;
  final DeviceAutomationsRemoteDatasource automationsDatasource;
  final DeviceReadingsRemoteDatasource readingsDatasource;

  Future<List<DeviceItem>> getUserDevices() {
    return baseDatasource.getUserDevices();
  }

  Future<int> getPendingInvitationsCount() {
    return sharesDatasource.getPendingInvitationsCount();
  }

  Future<List<Map<String, dynamic>>> getPendingInvitations() {
    return sharesDatasource.getPendingInvitations();
  }

  Future<void> acceptInvitation(String shareId) {
    return sharesDatasource.acceptInvitation(shareId);
  }

  Future<void> rejectInvitation(String shareId) {
    return sharesDatasource.rejectInvitation(shareId);
  }

  Future<Map<String, dynamic>?> fetchDeviceOwnership(String deviceId) {
    return sharesDatasource.fetchDeviceOwnership(deviceId);
  }

  Future<List<Map<String, dynamic>>> getDeviceShares(String deviceId) {
    return sharesDatasource.getDeviceShares(deviceId);
  }

  Future<List<Map<String, dynamic>>> getProfilesByIds(List<String> ids) {
    return sharesDatasource.getProfilesByIds(ids);
  }

  Future<void> inviteDeviceShareByEmail({
    required String deviceId,
    required String email,
  }) {
    return sharesDatasource.inviteDeviceShareByEmail(
      deviceId: deviceId,
      email: email,
    );
  }

  Future<void> revokeDeviceShare(String shareId) {
    return sharesDatasource.revokeDeviceShare(shareId);
  }

  Future<void> leaveSharedDevice(String shareId) {
    return sharesDatasource.leaveSharedDevice(shareId);
  }

  Future<DeviceItem> createManualDevice({
    required String name,
    required String deviceType,
    required String identifier,
    String protocol = 'http',
    String? homeId,
    String? roomId,
  }) {
    return baseDatasource.createManualDevice(
      name: name,
      deviceType: deviceType,
      identifier: identifier,
      protocol: protocol,
      homeId: homeId,
      roomId: roomId,
    );
  }

  Future<void> updateDeviceState(String deviceId, bool isActive) {
    return baseDatasource.updateDeviceState(deviceId, isActive);
  }

  Future<void> renameDevice({
    required String deviceId,
    required String name,
  }) {
    return baseDatasource.renameDevice(
      deviceId: deviceId,
      name: name,
    );
  }

  Future<void> setDeviceUpdating({
    required String deviceId,
    required bool isUpdating,
  }) {
    return baseDatasource.setDeviceUpdating(
      deviceId: deviceId,
      isUpdating: isUpdating,
    );
  }

  Future<void> unlinkDevice(String deviceId) {
    return baseDatasource.unlinkDevice(deviceId);
  }

  Future<void> deleteDevice(String id) {
    return baseDatasource.deleteDevice(id);
  }

  Future<bool> hasActiveIncidents(String deviceId) {
    return incidentsDatasource.hasActiveIncidents(deviceId);
  }

  Future<Map<String, dynamic>?> getLatestActiveIncident(String deviceId) {
    return incidentsDatasource.getLatestActiveIncident(deviceId);
  }

  Future<List<Map<String, dynamic>>> getActiveIncidentsByTypes({
    required String deviceId,
    required List<String> types,
  }) {
    return incidentsDatasource.getActiveIncidentsByTypes(
      deviceId: deviceId,
      types: types,
    );
  }

  Future<void> acknowledgeIncident(String incidentId) {
    return incidentsDatasource.acknowledgeIncident(incidentId);
  }

  Future<void> resolveIncident(String incidentId) {
    return incidentsDatasource.resolveIncident(incidentId);
  }

  Future<void> resolveIncidents(List<String> incidentIds) {
    return incidentsDatasource.resolveIncidents(incidentIds);
  }

  Future<String?> getDeviceIdByIdentifier(String identifier) {
    return baseDatasource.getDeviceIdByIdentifier(identifier);
  }

  Future<void> insertIncident({
    required String deviceId,
    required String type,
    required String message,
    int severity = 3,
  }) {
    return incidentsDatasource.insertIncident(
      deviceId: deviceId,
      type: type,
      message: message,
      severity: severity,
    );
  }

  Future<List<Map<String, dynamic>>> fetchIncidents({
    required String deviceId,
    int limit = 100,
  }) {
    return incidentsDatasource.fetchIncidents(
      deviceId: deviceId,
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> fetchAutomations({
    required String deviceId,
    required String type,
  }) {
    return automationsDatasource.fetchAutomations(
      deviceId: deviceId,
      type: type,
    );
  }

  Future<void> upsertAutomation({
    String? id,
    required String deviceId,
    required String type,
    required bool enabled,
    required Map<String, dynamic> config,
  }) {
    return automationsDatasource.upsertAutomation(
      id: id,
      deviceId: deviceId,
      type: type,
      enabled: enabled,
      config: config,
    );
  }

  Future<void> deleteAutomation(String automationId) {
    return automationsDatasource.deleteAutomation(automationId);
  }

  Future<List<Map<String, dynamic>>> fetchReadingsRange({
    required String deviceId,
    required DateTime from,
    required DateTime to,
    int limit = 10000,
  }) {
    return readingsDatasource.fetchReadingsRange(
      deviceId: deviceId,
      from: from,
      to: to,
      limit: limit,
    );
  }

  Future<void> insertReadingSample({
    required String deviceId,
    required DateTime timestamp,
    required double powerW,
    required double voltageV,
    required double energyWh,
  }) {
    return readingsDatasource.insertReadingSample(
      deviceId: deviceId,
      timestamp: timestamp,
      powerW: powerW,
      voltageV: voltageV,
      energyWh: energyWh,
    );
  }
}
