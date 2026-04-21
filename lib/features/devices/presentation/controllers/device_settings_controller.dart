import 'package:flutter/material.dart';
import 'package:iot_manager/core/constants/devices_panel_strings.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/core/iot/shelly/shelly_rpc_client.dart';
import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';
import 'package:iot_manager/features/devices/data/repositories/devices_repository_impl.dart';
import 'package:iot_manager/features/devices/domain/usecases/delete_device.dart';
import 'package:iot_manager/features/devices/domain/usecases/fetch_device_ownership.dart';
import 'package:iot_manager/features/devices/domain/usecases/rename_device.dart';
import 'package:iot_manager/features/devices/domain/usecases/set_device_updating.dart';
import 'package:iot_manager/features/devices/domain/usecases/unlink_device.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceSettingsController extends ChangeNotifier {
  DeviceSettingsController({
    required this.deviceId,
    required this.host,
    required DevicesRemoteDatasource remoteDatasource,
  })  : fetchDeviceOwnership = FetchDeviceOwnership(
    DevicesRepositoryImpl(remoteDatasource),
  ),
        renameDeviceUseCase = RenameDevice(
          DevicesRepositoryImpl(remoteDatasource),
        ),
        setDeviceUpdating = SetDeviceUpdating(
          DevicesRepositoryImpl(remoteDatasource),
        ),
        unlinkDeviceUseCase = UnlinkDevice(
          DevicesRepositoryImpl(remoteDatasource),
        ),
        deleteDeviceUseCase = DeleteDevice(
          DevicesRepositoryImpl(remoteDatasource),
        );

  final String deviceId;
  final String host;
  final FetchDeviceOwnership fetchDeviceOwnership;
  final RenameDevice renameDeviceUseCase;
  final SetDeviceUpdating setDeviceUpdating;
  final UnlinkDevice unlinkDeviceUseCase;
  final DeleteDevice deleteDeviceUseCase;

  final SupabaseClient _supabase = Supabase.instance.client;

  bool loading = false;
  bool canFactoryReset = false;
  bool canManageDevice = false;

  bool nightModeSupported = false;
  bool nightModeEnabled = false;
  double nightBrightness = 25;
  String nightStart = '23:00';
  String nightEnd = '07:00';
  bool savingNightMode = false;

  String? timezone;
  double? lat;
  double? lon;
  bool loadingLocation = false;

  bool savingName = false;

  bool checkingUpdate = false;
  bool updatingFirmware = false;
  String? availableVersion;
  String? availableBuildId;
  String? updateMessage;

  bool rebooting = false;
  bool unlinking = false;
  bool factoryResetting = false;

  Future<void> load() async {
    loading = true;
    notifyListeners();

    final rpc = ShellyRpcClient(host: host);

    try {
      await _loadOwnership();

      final sysConfig = await rpc.getSysConfig();
      final location = mapFrom(sysConfig['location']);
      timezone = stringOrNull(location['tz']);
      lat = doubleOrNull(location['lat']);
      lon = doubleOrNull(location['lon']);

      try {
        final update = await rpc.checkForUpdate();
        final stable = mapFrom(update['stable']);
        availableVersion = stringOrNull(stable['version']);
        availableBuildId = stringOrNull(stable['build_id']);
      } catch (_) {
        availableVersion = null;
        availableBuildId = null;
      }

      try {
        final uiConfig = await rpc.call('PLUGS_UI.GetConfig');
        final leds = mapFrom(uiConfig['leds']);
        final nightMode = mapFrom(leds['night_mode']);

        nightModeSupported = nightMode.isNotEmpty;

        if (nightModeSupported) {
          nightModeEnabled = nightMode['enable'] == true;
          nightBrightness =
              (doubleOrNull(nightMode['brightness']) ?? 25).clamp(1, 100);
          final activeBetween = (nightMode['active_between'] as List?)?.cast<String>() ?? [];
          if (activeBetween.length == 2) {
            nightStart = activeBetween[0];
            nightEnd = activeBetween[1];
          }
        } else {
          nightModeEnabled = false;
          nightBrightness = 25;
          nightStart = '23:00';
          nightEnd = '07:00';
        }
      } catch (_) {
        nightModeSupported = false;
      }
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadOwnership() async {
    try {
      final row = await fetchDeviceOwnership(deviceId);
      final ownerId = (row?['owner_id'] ?? '').toString();
      final currentUserId = _supabase.auth.currentUser?.id ?? '';

      canManageDevice = ownerId.isNotEmpty && currentUserId.isNotEmpty && ownerId == currentUserId;
      canFactoryReset = canManageDevice;
    } catch (_) {
      canFactoryReset = false;
    }
  }

  Future<void> saveNightMode() async {
    if (!nightModeSupported || savingNightMode) return;

    savingNightMode = true;
    notifyListeners();

    try {
      final rpc = ShellyRpcClient(host: host);
      await rpc.setPlugsUiConfig(
        config: {
          'leds': {
            'night_mode': {
              'enable': nightModeEnabled,
              'brightness': nightBrightness.round(),
              'active_between': [nightStart, nightEnd],
            },
          },
        },
      );
    } finally {
      savingNightMode = false;
      notifyListeners();
    }
  }

  void setNightModeEnabled(bool value) {
    nightModeEnabled = value;
    notifyListeners();
  }

  void setNightBrightness(double value) {
    nightBrightness = value;
    notifyListeners();
  }

  void setNightStart(String value) {
    nightStart = value;
    notifyListeners();
  }

  void setNightEnd(String value) {
    nightEnd = value;
    notifyListeners();
  }

  Future<void> detectLocation() async {
    if (loadingLocation) return;

    loadingLocation = true;
    notifyListeners();

    try {
      final rpc = ShellyRpcClient(host: host);
      final detected = await rpc.detectLocation();

      final tz = stringOrNull(detected['tz']);
      final la = doubleOrNull(detected['lat']);
      final lo = doubleOrNull(detected['lon']);

      if (tz != null || la != null || lo != null) {
        await rpc.setSysConfig(
          config: {
            'location': {
              'tz': tz,
              'lat': la,
              'lon': lo,
            },
          },
        );

        timezone = tz;
        lat = la;
        lon = lo;
      }
    } finally {
      loadingLocation = false;
      notifyListeners();
    }
  }

  Future<void> saveName(String name) async {
    if (name.trim().isEmpty || savingName) return;

    if (name.length > 18) {
      throw Exception(DevicesPanelStrings.notValidName);
    }

    savingName = true;
    notifyListeners();

    try {
      final cleanName = name.trim();
      final rpc = ShellyRpcClient(host: host);

      await rpc.setSysConfig(config: {'device': {'name': cleanName}});

      await renameDeviceUseCase(
        deviceId: deviceId,
        name: cleanName,
      );
    } finally {
      savingName = false;
      notifyListeners();
    }
  }

  Future<void> checkUpdate() async {
    if (checkingUpdate) return;

    checkingUpdate = true;
    notifyListeners();

    try {
      final rpc = ShellyRpcClient(host: host);
      final result = await rpc.checkForUpdate();
      final stable = mapFrom(result['stable']);

      availableVersion = stringOrNull(stable['version']);
      availableBuildId = stringOrNull(stable['build_id']);
      updateMessage = availableVersion == null
          ? DevicesPanelStrings.notAvaliableUpdateStable
          : '${DevicesPanelStrings.pedingUpdate}: $availableVersion';
    } finally {
      checkingUpdate = false;
      notifyListeners();
    }
  }

  Future<void> runUpdate() async {
    if (availableVersion == null || updatingFirmware) return;

    updatingFirmware = true;
    notifyListeners();

    try {
      await setDeviceUpdating(
        deviceId: deviceId,
        isUpdating: true,
      );

      final rpc = ShellyRpcClient(host: host);
      await rpc.updateFirmware();
    } finally {
      updatingFirmware = false;
      notifyListeners();
    }
  }

  Future<void> rebootDevice() async {
    if (rebooting) return;

    rebooting = true;
    notifyListeners();

    try {
      final rpc = ShellyRpcClient(host: host);
      await rpc.reboot();
    } finally {
      rebooting = false;
      notifyListeners();
    }
  }

  Future<void> unlinkDevice() async {
    if (!canManageDevice) {
      throw Exception('Solo el propietario puede eliminar el dispositivo.');
    }

    if (unlinking) return;

    unlinking = true;
    notifyListeners();

    try {
      await unlinkDeviceUseCase(deviceId);
    } finally {
      unlinking = false;
      notifyListeners();
    }
  }

  Future<void> factoryReset() async {
    if (!canFactoryReset) {
      throw Exception(DevicesPanelStrings.notFactoryReset);
    }

    if (factoryResetting) return;

    factoryResetting = true;
    notifyListeners();

    try {
      final rpc = ShellyRpcClient(host: host);
      await rpc.factoryReset();
      await deleteDeviceUseCase(deviceId);
    } finally {
      factoryResetting = false;
      notifyListeners();
    }
  }

  static Map<String, dynamic> mapFrom(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static String? stringOrNull(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == 'null') return null;
    return text;
  }

  static double? doubleOrNull(dynamic value) {
    if (value is num) return value.toDouble();
    return null;
  }

  static String formatTimeOfDay(TimeOfDay value) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
}
