import 'package:flutter/foundation.dart';
import 'package:iot_manager/core/constants/devices_strings.dart';

import '../../../../core/error/error_mapper.dart';
import '../../../../core/iot/models/discovered_iot_device.dart';
import '../../../../core/iot/shelly/shelly_lan_discovery.dart';
import '../../../../core/iot/shelly/shelly_rpc_client.dart';
import '../../data/datasources/devices_remote_datasource.dart';
import '../../data/repositories/devices_repository_impl.dart';
import '../../domain/entities/device_item.dart';
import '../../domain/usecases/get_user_devices.dart';

class DevicesController extends ChangeNotifier {
  final GetUserDevices getUserDevices;
  final DevicesRemoteDatasource remoteDatasource;

  DevicesController(
      this.getUserDevices,
      this.remoteDatasource,
      );

  bool isLoading = false;
  String? errorMessages;
  List<DeviceItem> items = [];
  List<DiscoveredIotDevice> discoveredDevices = [];

  bool get loading => isLoading;
  String? get errorMessage => errorMessages;
  List<DeviceItem> get devices => items;
  List<DiscoveredIotDevice> get scannedDevices => discoveredDevices;

  factory DevicesController.create() {
    final datasource = DevicesRemoteDatasource();
    final repository = DevicesRepositoryImpl(datasource);
    final usecase = GetUserDevices(repository);

    return DevicesController(usecase, datasource);
  }

  Future<void> load() async {
    setLoading(true);
    clearError();

    try {
      items = await getUserDevices();
    } catch (error) {
      final failure = ErrorMapper.mapFailure(error);
      setError(failure.message);
    } finally {
      setLoading(false);
    }
  }

  Future<void> addManualDevice({
    required String name,
    required String deviceType,
    required String identifier,
  }) async {
    setLoading(true);
    clearError();

    try {
      await remoteDatasource.createManualDevice(
        name: name,
        deviceType: deviceType,
        identifier: identifier,
      );
      items = await getUserDevices();
    } catch (error) {
      final failure = ErrorMapper.mapFailure(error);
      setError(failure.message);
    } finally {
      setLoading(false);
    }
  }

  Future<void> addDiscoveredDevice({
    required String name,
    required String deviceType,
    required String host,
  }) async {
    await addManualDevice(
      name: name,
      deviceType: deviceType,
      identifier: host,
    );
  }

  Future<void> discoverDevicesInLan() async {
    setLoading(true);
    clearError();

    try {
      final discovery = ShellyLanDiscovery();
      discoveredDevices = await discovery.discoverAll(maxResults: 50);

      if (discoveredDevices.isEmpty) {
        setError(DevicesStrings.notShellyinLAN);
      } else {
        notifyListeners();
      }
    } catch (error) {
      final failure = ErrorMapper.mapFailure(error);
      setError(failure.message);
    } finally {
      setLoading(false);
    }
  }

  Future<void> toggleDevice(DeviceItem device, bool on) async {
    try {
      final rpc = ShellyRpcClient(host: device.identifier);
      await rpc.setSwitch(on: on);
      await remoteDatasource.updateDeviceState(device.id, on);
      await load();
    } catch (error) {
      final failure = ErrorMapper.mapFailure(error);
      setError(failure.message);
    }
  }

  void setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  void setError(String message) {
    errorMessages = message;
    notifyListeners();
  }

  void clearError() {
    errorMessages = null;
    notifyListeners();
  }
}