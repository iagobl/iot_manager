import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';
import 'package:iot_manager/features/devices/domain/repositories/device_share_repository.dart';

class DeviceSharesRepositoryImpl implements DeviceSharesRepository {
  DeviceSharesRepositoryImpl(this.remoteDatasource);

  final DevicesRemoteDatasource remoteDatasource;

  @override
  Future<int> getPendingInvitationsCount() async {
    try {
      return await remoteDatasource.getPendingInvitationsCount();
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingInvitations() async {
    try {
      return await remoteDatasource.getPendingInvitations();
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }

  @override
  Future<void> acceptInvitation(String shareId) async {
    try {
      await remoteDatasource.acceptInvitation(shareId);
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }

  @override
  Future<void> rejectInvitation(String shareId) async {
    try {
      await remoteDatasource.rejectInvitation(shareId);
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchDeviceOwnership(String deviceId) async {
    try {
      return await remoteDatasource.fetchDeviceOwnership(deviceId);
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getDeviceShares(String deviceId) async {
    try {
      return await remoteDatasource.getDeviceShares(deviceId);
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getProfilesByIds(List<String> ids) async {
    try {
      return await remoteDatasource.getProfilesByIds(ids);
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }

  @override
  Future<void> inviteDeviceShareByEmail({
    required String deviceId,
    required String email,
  }) async {
    try {
      await remoteDatasource.inviteDeviceShareByEmail(deviceId: deviceId, email: email);
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }

  @override
  Future<void> revokeDeviceShare(String shareId) async {
    try {
      await remoteDatasource.revokeDeviceShare(shareId);
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }

  @override
  Future<void> leaveSharedDevice(String shareId) async {
    try {
      await remoteDatasource.leaveSharedDevice(shareId);
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }
}
