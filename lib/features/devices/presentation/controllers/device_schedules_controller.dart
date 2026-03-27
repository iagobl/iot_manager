import 'package:flutter/foundation.dart';
import 'package:iot_manager/core/error/app_exception.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/core/iot/shelly/shelly_rpc_client.dart';
import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';

class DeviceSchedulesController extends ChangeNotifier {
  DeviceSchedulesController({
    required this.deviceId,
    required this.host,
    required this.remoteDatasource,
  }) : rpcClient = ShellyRpcClient(host: host);

  final String deviceId;
  final String host;
  final DevicesRemoteDatasource remoteDatasource;
  final ShellyRpcClient rpcClient;

  bool loading = false;
  bool busy = false;
  List<Map<String, dynamic>> schedules = [];
  String? error;

  Future<void> load() async {
    setLoading(true);
    clearError();

    try {
      validateBaseData();
      schedules = await remoteDatasource.fetchAutomations(
        deviceId: deviceId,
        type: 'schedule',
      );
    } catch (err) {
      setMappedError(err);
    } finally {
      setLoading(false);
    }
  }

  Future<bool> create({
    required int hour,
    required int minute,
    required String action,
    required List<int> days,
  }) async {
    setBusy(true);
    clearError();

    int? shellyScheduleId;

    try {
      validateBaseData();
      validateInput(
        hour: hour,
        minute: minute,
        action: action,
        days: days,
      );

      final normalizedDays = normalizeDays(days);
      final timespec = buildTimespec(hour: hour, minute: minute, days: normalizedDays);
      final calls = buildCalls(action);

      shellyScheduleId = await rpcClient.createSchedule(enable: true, timespec: timespec, calls: calls);

      await remoteDatasource.upsertAutomation(
        deviceId: deviceId,
        type: 'schedule',
        enabled: true,
        config: {
          'hour': hour,
          'minute': minute,
          'action': action,
          'days': normalizedDays,
          'timespec': timespec,
          'shelly_schedule_id': shellyScheduleId,
        },
      );

      await reloadSchedulesSilently();
      return true;
    } catch (err) {
      if (shellyScheduleId != null) {
        try {
          await rpcClient.deleteSchedule(id: shellyScheduleId);
        } catch (_) {}
      }

      setMappedError(err);
      return false;
    } finally {
      setBusy(false);
    }
  }

  Future<bool> toggleEnabled(String automationId, bool enabled) async {
    if (automationId.trim().isEmpty) {
      setMappedError(
        const ValidationAppException('No se ha encontrado un identificador válido para el horario.'),
      );
      return false;
    }

    setBusy(true);
    clearError();

    try {
      validateBaseData();

      final row = findRowById(automationId);
      if (row == null) {
        throw const ValidationAppException('No se ha encontrado el horario seleccionado.');
      }

      final config = mapFrom(row['config']);
      final hour = intFrom(config['hour']);
      final minute = intFrom(config['minute']);
      final action = (config['action'] ?? 'on').toString().toLowerCase();
      final days = daysFromConfig(config['days']);

      if (hour == null || minute == null || days.isEmpty) {
        throw const ValidationAppException('El horario guardado no tiene una configuración válida.');
      }

      final timespec = buildTimespec(
        hour: hour,
        minute: minute,
        days: days,
      );
      final calls = buildCalls(action);

      final shellyId = intFrom(config['shelly_schedule_id']);

      if (shellyId != null) {
        await rpcClient.updateSchedule(
          id: shellyId,
          enable: enabled,
        );
      } else {
        final createdId = await rpcClient.createSchedule(
          enable: enabled,
          timespec: timespec,
          calls: calls,
        );
        config['shelly_schedule_id'] = createdId;
      }

      config['timespec'] = timespec;

      await remoteDatasource.upsertAutomation(
        id: automationId,
        deviceId: deviceId,
        type: 'schedule',
        enabled: enabled,
        config: config,
      );

      await reloadSchedulesSilently();
      return true;
    } catch (err) {
      setMappedError(err);
      return false;
    } finally {
      setBusy(false);
    }
  }

  Future<bool> delete(String automationId) async {
    if (automationId.trim().isEmpty) {
      setMappedError(
        const ValidationAppException('No se ha encontrado un identificador válido para el horario.'),
      );
      return false;
    }

    setBusy(true);
    clearError();

    try {
      validateBaseData();

      final row = findRowById(automationId);
      if (row == null) {
        throw const ValidationAppException('No se ha encontrado el horario seleccionado.');
      }

      final config = mapFrom(row['config']);
      final shellyId = intFrom(config['shelly_schedule_id']);

      if (shellyId != null) {
        await rpcClient.deleteSchedule(id: shellyId);
      }

      await remoteDatasource.deleteAutomation(automationId);
      await reloadSchedulesSilently();
      return true;
    } catch (err) {
      setMappedError(err);
      return false;
    } finally {
      setBusy(false);
    }
  }

  Map<String, dynamic>? findRowById(String automationId) {
    try {
      return schedules.firstWhere((row) => (row['id'] ?? '').toString() == automationId);
    } catch (_) {
      return null;
    }
  }

  Future<void> reloadSchedulesSilently() async {
    schedules = await remoteDatasource.fetchAutomations(
      deviceId: deviceId,
      type: 'schedule',
    );
    notifyListeners();
  }

  void validateBaseData() {
    if (deviceId.trim().isEmpty) {
      throw const ValidationAppException('No se ha encontrado un identificador válido para el dispositivo.');
    }

    if (host.trim().isEmpty) {
      throw const ValidationAppException('La dirección del dispositivo no es válida.');
    }
  }

  void setMappedError(Object err) {
    final failure = ErrorMapper.mapFailure(err);
    error = failure.message;
    notifyListeners();
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  void setLoading(bool value) {
    loading = value;
    notifyListeners();
  }

  void setBusy(bool value) {
    busy = value;
    notifyListeners();
  }

  static void validateInput({
    required int hour,
    required int minute,
    required String action,
    required List<int> days,
  }) {
    if (hour < 0 || hour > 23) {
      throw const ValidationAppException('La hora no es válida.');
    }

    if (minute < 0 || minute > 59) {
      throw const ValidationAppException('Los minutos no son válidos.');
    }

    if (action != 'on' && action != 'off') {
      throw const ValidationAppException('La acción del horario no es válida.');
    }

    if (days.isEmpty) {
      throw const ValidationAppException('Debes seleccionar al menos un día.');
    }
  }

  static List<Map<String, dynamic>> buildCalls(String action) {
    final on = action.toLowerCase() == 'on';

    return [
      {
        'method': 'Switch.Set',
        'params': {
          'id': 0,
          'on': on,
        },
      },
    ];
  }

  static String buildTimespec({
    required int hour,
    required int minute,
    required List<int> days,
  }) {
    final cronDays = normalizeDays(days).map(dayToCron).join(',');
    return '0 $minute $hour * * $cronDays';
  }

  static String dayToCron(int day) {
    switch (day) {
      case 1:
        return 'MON';
      case 2:
        return 'TUE';
      case 3:
        return 'WED';
      case 4:
        return 'THU';
      case 5:
        return 'FRI';
      case 6:
        return 'SAT';
      case 7:
        return 'SUN';
      default:
        throw const ValidationAppException('Se ha encontrado un día no válido en el horario.');
    }
  }

  static List<int> normalizeDays(List<int> rawDays) {
    final result = rawDays
        .map(intFrom)
        .whereType<int>()
        .where((d) => d >= 1 && d <= 7)
        .toSet()
        .toList()
      ..sort();

    return result;
  }

  static int? intFrom(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static Map<String, dynamic> mapFrom(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  static List<int> daysFromConfig(dynamic raw) {
    if (raw is! List) return const [];

    return raw
        .map(intFrom)
        .whereType<int>()
        .where((e) => e >= 1 && e <= 7)
        .toSet()
        .toList()
      ..sort();
  }

  static String formatDays(List<int> days) {
    if (days.isEmpty) return 'Sin días';
    if (sameDays(days, [1, 2, 3, 4, 5, 6, 7])) return 'Todos los días';
    if (sameDays(days, [1, 2, 3, 4, 5])) return 'Lunes a viernes';
    if (sameDays(days, [6, 7])) return 'Fin de semana';

    const names = {
      1: 'Lun',
      2: 'Mar',
      3: 'Mié',
      4: 'Jue',
      5: 'Vie',
      6: 'Sáb',
      7: 'Dom',
    };

    return days.map((d) => names[d] ?? d.toString()).join(', ');
  }

  static bool sameDays(List<int> a, List<int> b) {
    if (a.length != b.length) return false;

    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }

    return true;
  }
}