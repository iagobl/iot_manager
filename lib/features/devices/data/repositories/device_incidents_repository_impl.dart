import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';
import 'package:iot_manager/features/devices/domain/repositories/device_incidents_repository.dart';

class DeviceIncidentsRepositoryImpl implements DeviceIncidentsRepository {
  DeviceIncidentsRepositoryImpl(this.remoteDatasource);

  final DevicesRemoteDatasource remoteDatasource;

  @override
  Future<bool> hasActiveIncidents(String deviceId) async {
    try {
      return await remoteDatasource.hasActiveIncidents(deviceId);
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }

  @override
  Future<Map<String, dynamic>?> getLatestActiveIncident(String deviceId) async {
    try {
      return await remoteDatasource.getLatestActiveIncident(deviceId);
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getActiveIncidentsByTypes({
    required String deviceId,
    required List<String> types,
  }) async {
    try {
      return await remoteDatasource.getActiveIncidentsByTypes(
        deviceId: deviceId,
        types: types,
      );
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }

  @override
  Future<void> acknowledgeIncident(String incidentId) async {
    try {
      await remoteDatasource.acknowledgeIncident(incidentId);
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }

  @override
  Future<void> resolveIncident(String incidentId) async {
    try {
      await remoteDatasource.resolveIncident(incidentId);
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }

  @override
  Future<void> resolveIncidents(List<String> incidentIds) async {
    try {
      await remoteDatasource.resolveIncidents(incidentIds);
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }

  @override
  Future<void> insertIncident({
    required String deviceId,
    required String type,
    required String message,
    int severity = 3,
  }) async {
    try {
      await remoteDatasource.insertIncident(
        deviceId: deviceId,
        type: type,
        message: message,
        severity: severity,
      );
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchIncidents({
    required String deviceId,
    int limit = 100,
  }) async {
    try {
      return await remoteDatasource.fetchIncidents(deviceId: deviceId, limit: limit);
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }
}
