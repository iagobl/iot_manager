import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';
import 'package:iot_manager/features/devices/data/repositories/device_automations_repository_impl.dart';
import 'package:iot_manager/features/devices/data/repositories/device_base_repository_impl.dart';
import 'package:iot_manager/features/devices/data/repositories/device_incidents_repository_impl.dart';
import 'package:iot_manager/features/devices/data/repositories/device_live_state_repository_impl.dart';
import 'package:iot_manager/features/devices/data/repositories/device_readings_repository_impl.dart';
import 'package:iot_manager/features/devices/data/repositories/device_shares_repository_impl.dart';
import 'package:iot_manager/features/devices/domain/entities/device_item.dart';
import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class DevicesRepositoryImpl implements DevicesRepository {
  DevicesRepositoryImpl(this.remoteDatasource)
      : baseRepository = DeviceBaseRepositoryImpl(remoteDatasource),
        sharesRepository = DeviceSharesRepositoryImpl(remoteDatasource),
        incidentsRepository = DeviceIncidentsRepositoryImpl(remoteDatasource),
        automationsRepository = DeviceAutomationsRepositoryImpl(remoteDatasource),
        readingsRepository = DeviceReadingsRepositoryImpl(remoteDatasource),
        liveStateRepository = DeviceLiveStateRepositoryImpl(remoteDatasource);

  final DevicesRemoteDatasource remoteDatasource;

  final DeviceBaseRepositoryImpl baseRepository;
  final DeviceSharesRepositoryImpl sharesRepository;
  final DeviceIncidentsRepositoryImpl incidentsRepository;
  final DeviceAutomationsRepositoryImpl automationsRepository;
  final DeviceReadingsRepositoryImpl readingsRepository;
  final DeviceLiveStateRepositoryImpl liveStateRepository;

  @override
  Future<List<DeviceItem>> getUserDevices() {
    return baseRepository.getUserDevices();
  }

  @override
  Future<DeviceItem> createManualDevice({
    required String name,
    required String deviceType,
    required String identifier,
    String protocol = 'http',
    String? homeId,
  }) {
    return baseRepository.createManualDevice(
      name: name,
      deviceType: deviceType,
      identifier: identifier,
      protocol: protocol,
      homeId: homeId,
    );
  }

  @override
  Future<void> updateDeviceState(String deviceId, bool isActive) {
    return baseRepository.updateDeviceState(deviceId, isActive);
  }

  @override
  Future<void> renameDevice({required String deviceId, required String name}) {
    return baseRepository.renameDevice(deviceId: deviceId, name: name);
  }

  @override
  Future<void> setDeviceUpdating({required String deviceId, required bool isUpdating}) {
    return baseRepository.setDeviceUpdating(deviceId: deviceId, isUpdating: isUpdating);
  }

  @override
  Future<void> unlinkDevice(String deviceId) {
    return baseRepository.unlinkDevice(deviceId);
  }

  @override
  Future<void> deleteDevice(String deviceId) {
    return baseRepository.deleteDevice(deviceId);
  }

  @override
  Future<String?> getDeviceIdByIdentifier(String identifier) {
    return baseRepository.getDeviceIdByIdentifier(identifier);
  }

  @override
  Future<int> getPendingInvitationsCount() {
    return sharesRepository.getPendingInvitationsCount();
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingInvitations() {
    return sharesRepository.getPendingInvitations();
  }

  @override
  Future<void> acceptInvitation(String shareId) {
    return sharesRepository.acceptInvitation(shareId);
  }

  @override
  Future<void> rejectInvitation(String shareId) {
    return sharesRepository.rejectInvitation(shareId);
  }

  @override
  Future<Map<String, dynamic>?> fetchDeviceOwnership(String deviceId) {
    return sharesRepository.fetchDeviceOwnership(deviceId);
  }

  @override
  Future<List<Map<String, dynamic>>> getDeviceShares(String deviceId) {
    return sharesRepository.getDeviceShares(deviceId);
  }

  @override
  Future<List<Map<String, dynamic>>> getProfilesByIds(List<String> ids) {
    return sharesRepository.getProfilesByIds(ids);
  }

  @override
  Future<void> inviteDeviceShareByEmail({required String deviceId, required String email}) {
    return sharesRepository.inviteDeviceShareByEmail(deviceId: deviceId, email: email);
  }

  @override
  Future<void> revokeDeviceShare(String shareId) {
    return sharesRepository.revokeDeviceShare(shareId);
  }

  @override
  Future<void> leaveSharedDevice(String shareId) {
    return sharesRepository.leaveSharedDevice(shareId);
  }

  @override
  Future<bool> hasActiveIncidents(String deviceId) {
    return incidentsRepository.hasActiveIncidents(deviceId);
  }

  @override
  Future<Map<String, dynamic>?> getLatestActiveIncident(String deviceId) {
    return incidentsRepository.getLatestActiveIncident(deviceId);
  }

  @override
  Future<List<Map<String, dynamic>>> getActiveIncidentsByTypes({
    required String deviceId,
    required List<String> types,
  }) {
    return incidentsRepository.getActiveIncidentsByTypes(deviceId: deviceId, types: types);
  }

  @override
  Future<void> acknowledgeIncident(String incidentId) {
    return incidentsRepository.acknowledgeIncident(incidentId);
  }

  @override
  Future<void> resolveIncident(String incidentId) {
    return incidentsRepository.resolveIncident(incidentId);
  }

  @override
  Future<void> resolveIncidents(List<String> incidentIds) {
    return incidentsRepository.resolveIncidents(incidentIds);
  }

  @override
  Future<void> insertIncident({
    required String deviceId,
    required String type,
    required String message,
    int severity = 3,
  }) {
    return incidentsRepository.insertIncident(
      deviceId: deviceId,
      type: type,
      message: message,
      severity: severity,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> fetchIncidents({required String deviceId, int limit = 100}) {
    return incidentsRepository.fetchIncidents(deviceId: deviceId, limit: limit);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAutomations({
    required String deviceId,
    required String type,
  }) {
    return automationsRepository.fetchAutomations(deviceId: deviceId, type: type);
  }

  @override
  Future<void> upsertAutomation({
    String? id,
    required String deviceId,
    required String type,
    required bool enabled,
    required Map<String, dynamic> config,
  }) {
    return automationsRepository.upsertAutomation(
      id: id,
      deviceId: deviceId,
      type: type,
      enabled: enabled,
      config: config,
    );
  }

  @override
  Future<void> deleteAutomation(String automationId) {
    return automationsRepository.deleteAutomation(automationId);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchReadingsRange({
    required String deviceId,
    required DateTime from,
    required DateTime to,
    int limit = 10000,
  }) {
    return readingsRepository.fetchReadingsRange(
      deviceId: deviceId,
      from: from,
      to: to,
      limit: limit,
    );
  }

  @override
  Future<void> insertReadingSample({
    required String deviceId,
    required DateTime timestamp,
    required double powerW,
    required double voltageV,
    required double energyWh,
  }) {
    return readingsRepository.insertReadingSample(
      deviceId: deviceId,
      timestamp: timestamp,
      powerW: powerW,
      voltageV: voltageV,
      energyWh: energyWh,
    );
  }

  @override
  Future<bool> isDeviceActive(dynamic device) {
    return liveStateRepository.isDeviceActive(device);
  }
}
