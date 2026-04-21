import 'package:flutter/foundation.dart';

import 'package:iot_manager/core/constants/devices_strings.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/core/iot/models/discovered_iot_device.dart';
import 'package:iot_manager/core/iot/shelly/shelly_lan_discovery.dart';
import 'package:iot_manager/core/iot/shelly/shelly_rpc_client.dart';
import 'package:iot_manager/core/iot/shelly/shelly_telemetry_script_service.dart';

import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';
import 'package:iot_manager/features/devices/data/repositories/devices_repository_impl.dart';
import 'package:iot_manager/features/devices/domain/entities/device_item.dart';
import 'package:iot_manager/features/devices/domain/usecases/create_manual_device.dart';
import 'package:iot_manager/features/devices/domain/usecases/delete_device.dart';
import 'package:iot_manager/features/devices/domain/usecases/get_user_devices.dart';
import 'package:iot_manager/features/devices/domain/usecases/update_device_state.dart';

class DevicesController extends ChangeNotifier {
  DevicesController._(
      this.getUserDevices,
      this.createManualDevice,
      this.updateDeviceState,
      this.deleteDevice,
      this.telemetryScriptService,
      );

  factory DevicesController.create() {
    final datasource = DevicesRemoteDatasource();
    final repository = DevicesRepositoryImpl(datasource);

    return DevicesController._(
      GetUserDevices(repository),
      CreateManualDevice(repository),
      UpdateDeviceState(repository),
      DeleteDevice(repository),
      const ShellyTelemetryScriptService(),
    );
  }

  final GetUserDevices getUserDevices;
  final CreateManualDevice createManualDevice;
  final UpdateDeviceState updateDeviceState;
  final DeleteDevice deleteDevice;
  final ShellyTelemetryScriptService telemetryScriptService;

  bool isLoading = false;
  String? errorMessages;
  List<DeviceItem> isDevices = <DeviceItem>[];
  List<DiscoveredIotDevice> discoveredDevices = <DiscoveredIotDevice>[];

  bool get loading => isLoading;
  String? get errorMessage => errorMessages;
  List<DeviceItem> get devices => isDevices;
  List<DiscoveredIotDevice> get scannedDevices => discoveredDevices;

  Future<void> load() async {
    setLoading(true);
    clearError(notify: false);

    try {
      isDevices = await getUserDevices();
      discoveredDevices = <DiscoveredIotDevice>[];
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
    clearError(notify: false);

    try {
      final createdDevice = await createManualDevice(
        name: name,
        deviceType: deviceType,
        identifier: identifier,
      );

      try {
        await telemetryScriptService.installOrUpdate(
          host: identifier,
          deviceId: createdDevice.id,
        );
      } catch (error) {
        await deleteDevice(createdDevice.id);
        rethrow;
      }

      isDevices = await getUserDevices();
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
    clearError(notify: false);

    try {
      final currentDevices = await getUserDevices();
      isDevices = currentDevices;

      final discovery = ShellyLanDiscovery();
      final foundDevices = await discovery.discoverAll(maxResults: 50);

      final existingIdentifiers = currentDevices
          .map((device) => device.identifier.trim().toLowerCase())
          .where((identifier) => identifier.isNotEmpty).toSet();

      final uniqueByIp = <String, DiscoveredIotDevice>{};

      for (final device in foundDevices) {
        final normalizedIp = device.ip.trim().toLowerCase();
        if (normalizedIp.isEmpty) continue;
        if (existingIdentifiers.contains(normalizedIp)) continue;

        uniqueByIp[normalizedIp] = device;
      }

      discoveredDevices = uniqueByIp.values.toList()..sort((a, b) => a.ip.compareTo(b.ip));

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
    clearError(notify: false);

    try {
      final rpc = ShellyRpcClient(host: device.identifier);
      await rpc.setSwitch(on: on);
      await updateDeviceState(device.id, on);
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

  void clearError({bool notify = true}) {
    errorMessages = null;
    if (notify) {
      notifyListeners();
    }
  }
}
