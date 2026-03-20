import 'package:flutter/material.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/core/iot/shelly/shelly_rpc_client.dart';

enum LightMode {
  power,
  switchColors,
  off,
}

class DeviceLightController extends ChangeNotifier {
  DeviceLightController({
    required this.host,
  }) : rpc = ShellyRpcClient(host: host);

  final String host;
  final ShellyRpcClient rpc;

  bool loading = false;
  bool saving = false;
  bool supported = true;
  String? error;

  LightMode mode = LightMode.power;

  double powerBrightness = 100;

  List<int> onRgb = [0, 100, 0];
  double onBrightness = 100;

  List<int> offRgb = [100, 0, 0];
  double offBrightness = 100;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final config = await rpc.getPlugsUiConfig();
      final leds = mapFrom(config['leds']);

      if (leds.isEmpty) {
        supported = false;
        error = 'Este dispositivo no expone la configuración de luces por RPC.';
      } else {
        supported = true;
        error = null;

        final modeStr = (leds['mode']?.toString() ?? 'power').toLowerCase();
        switch (modeStr) {
          case 'switch':
            mode = LightMode.switchColors;
            break;
          case 'off':
            mode = LightMode.off;
            break;
          default:
            mode = LightMode.power;
        }

        final colors = mapFrom(leds['colors']);
        final power = mapFrom(colors['power']);
        final sw0 = mapFrom(colors['switch:0']);
        final on = mapFrom(sw0['on']);
        final off = mapFrom(sw0['off']);

        powerBrightness = (doubleOrNull(power['brightness']) ?? 100).clamp(0, 100).toDouble();
        onRgb = rgbFrom(on['rgb'], fallback: const [0, 100, 0]);
        onBrightness = (doubleOrNull(on['brightness']) ?? 100).clamp(0, 100).toDouble();
        offRgb = rgbFrom(off['rgb'], fallback: const [100, 0, 0]);
        offBrightness = (doubleOrNull(off['brightness']) ?? 100).clamp(0, 100).toDouble();
      }
    } catch (err) {
      final failure = ErrorMapper.mapFailure(err);
      supported = false;
      error = failure.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> saveMode(LightMode newMode) async {
    final previous = mode;
    mode = newMode;
    error = null;
    notifyListeners();

    try {
      await persist();
    } catch (err) {
      mode = previous;
      error = ErrorMapper.mapFailure(err).message;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> savePowerBrightness(double value) async {
    final previous = powerBrightness;
    powerBrightness = value;
    error = null;
    notifyListeners();

    try {
      await persist();
    } catch (err) {
      powerBrightness = previous;
      error = ErrorMapper.mapFailure(err).message;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> saveOnBrightness(double value) async {
    final previous = onBrightness;
    onBrightness = value;
    error = null;
    notifyListeners();

    try {
      await persist();
    } catch (err) {
      onBrightness = previous;
      error = ErrorMapper.mapFailure(err).message;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> saveOffBrightness(double value) async {
    final previous = offBrightness;
    offBrightness = value;
    error = null;
    notifyListeners();

    try {
      await persist();
    } catch (err) {
      offBrightness = previous;
      error = ErrorMapper.mapFailure(err).message;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> saveRgb({
    required bool isOn,
    required List<int> rgb,
  }) async {
    final previous = List<int>.from(isOn ? onRgb : offRgb);

    if (isOn) {
      onRgb = List<int>.from(rgb);
    } else {
      offRgb = List<int>.from(rgb);
    }
    error = null;
    notifyListeners();

    try {
      await persist();
    } catch (err) {
      if (isOn) {
        onRgb = previous;
      } else {
        offRgb = previous;
      }
      error = ErrorMapper.mapFailure(err).message;
      notifyListeners();
      rethrow;
    }
  }

  void setPowerBrightness(double value) {
    powerBrightness = value;
    notifyListeners();
  }

  void setOnBrightness(double value) {
    onBrightness = value;
    notifyListeners();
  }

  void setOffBrightness(double value) {
    offBrightness = value;
    notifyListeners();
  }

  Future<void> persist() async {
    if (saving) return;

    saving = true;
    notifyListeners();

    try {
      await rpc.setPlugsUiConfig(
        config: {
          'leds': {
            'mode': modeValue(mode),
            'colors': {
              'power': {
                'brightness': powerBrightness.round(),
              },
              'switch:0': {
                'on': {
                  'rgb': onRgb,
                  'brightness': onBrightness.round(),
                },
                'off': {
                  'rgb': offRgb,
                  'brightness': offBrightness.round(),
                },
              },
            },
          },
        },
      );

      error = null;
    } catch (err) {
      error = ErrorMapper.mapFailure(err).message;
      rethrow;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  static Color previewColor(List<int> rgb, double brightness) {
    final factor = brightness.clamp(0, 100) / 100;
    final r = (255 * (rgb[0] / 100) * factor).round().clamp(0, 255);
    final g = (255 * (rgb[1] / 100) * factor).round().clamp(0, 255);
    final b = (255 * (rgb[2] / 100) * factor).round().clamp(0, 255);
    return Color.fromARGB(255, r, g, b);
  }

  static bool sameRgb(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static String modeValue(LightMode mode) {
    switch (mode) {
      case LightMode.power:
        return 'power';
      case LightMode.switchColors:
        return 'switch';
      case LightMode.off:
        return 'off';
    }
  }

  static Map<String, dynamic> mapFrom(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static double? doubleOrNull(dynamic value) {
    if (value is num) return value.toDouble();
    return null;
  }

  static List<int> rgbFrom(
      dynamic value, {
        required List<int> fallback,
      }) {
    if (value is List && value.length >= 3) {
      return [pct(value[0]), pct(value[1]), pct(value[2])];
    }
    return List<int>.from(fallback);
  }

  static int pct(dynamic value) {
    if (value is num) return value.round().clamp(0, 100);
    return 0;
  }
}