import 'package:flutter/foundation.dart';
import 'package:iot_manager/core/error/app_exception.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/core/iot/shelly/shelly_rpc_client.dart';
import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';
import 'package:iot_manager/features/devices/data/repositories/devices_repository_impl.dart';
import 'package:iot_manager/features/devices/domain/usecases/delete_automation.dart';
import 'package:iot_manager/features/devices/domain/usecases/fetch_automations.dart';
import 'package:iot_manager/features/devices/domain/usecases/upsert_automation.dart';

class DeviceSchedulesController extends ChangeNotifier {
  DeviceSchedulesController({
    required this.deviceId,
    required this.host,
    required DevicesRemoteDatasource remoteDatasource,
  })  : fetchAutomations = FetchAutomations(
    DevicesRepositoryImpl(remoteDatasource),
  ),
        upsertAutomation = UpsertAutomation(
          DevicesRepositoryImpl(remoteDatasource),
        ),
        deleteAutomation = DeleteAutomation(
          DevicesRepositoryImpl(remoteDatasource),
        ),
        rpcClient = ShellyRpcClient(host: host);

  final String deviceId;
  final String host;
  final FetchAutomations fetchAutomations;
  final UpsertAutomation upsertAutomation;
  final DeleteAutomation deleteAutomation;
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
      schedules = await fetchAutomations(
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
      final timespec = buildTimespec(
        hour: hour,
        minute: minute,
        days: normalizedDays,
      );
      final calls = buildCalls(action);

      shellyScheduleId = await rpcClient.createSchedule(
        enable: true,
        timespec: timespec,
        calls: calls,
      );

      await upsertAutomation(
        deviceId: deviceId,
        type: 'schedule',
        enabled: true,
        config: {
          'hour': hour,
          'minute': minute,
          'action': action,
          'days': normalizedDays,
          'timespec': timespec,
          'calls': calls,
          'shelly_schedule_id': shellyScheduleId,
        },
      );

      await load();
      return true;
    } catch (err) {
      if (shellyScheduleId != null) {
        try {
          await rpcClient.deleteSchedule(id: shellyScheduleId);
        } catch (_) {}
      }

      setMappedError(err);
      rethrow;
    } finally {
      setBusy(false);
    }
  }

  Future<void> toggle(Map<String, dynamic> row, bool enabled) async {
    setBusy(true);
    clearError();

    try {
      validateBaseData();

      final id = (row['id'] ?? '').toString();
      if (id.trim().isEmpty) {
        throw const ValidationAppException(
          'No se ha encontrado un horario válido.',
        );
      }

      final config = mapFrom(row['config']);
      final shellyScheduleId = intFrom(config['shelly_schedule_id']);
      if (shellyScheduleId == null) {
        throw const ValidationAppException(
          'El horario no tiene un identificador válido en el dispositivo.',
        );
      }

      await rpcClient.call(
        'Schedule.Update',
        params: {
          'id': shellyScheduleId,
          'enable': enabled,
        },
      );

      await upsertAutomation(
        id: id,
        deviceId: deviceId,
        type: 'schedule',
        enabled: enabled,
        config: config,
      );

      await load();
    } catch (err) {
      setMappedError(err);
      rethrow;
    } finally {
      setBusy(false);
    }
  }

  Future<void> remove(Map<String, dynamic> row) async {
    setBusy(true);
    clearError();

    try {
      validateBaseData();

      final automationId = (row['id'] ?? '').toString();
      if (automationId.trim().isEmpty) {
        throw const ValidationAppException(
          'No se ha encontrado un horario válido.',
        );
      }

      final config = mapFrom(row['config']);
      final shellyScheduleId = intFrom(config['shelly_schedule_id']);

      if (shellyScheduleId != null) {
        await rpcClient.deleteSchedule(id: shellyScheduleId);
      }

      await deleteAutomation(automationId);
      await load();
    } catch (err) {
      setMappedError(err);
      rethrow;
    } finally {
      setBusy(false);
    }
  }

  Future<void> refreshSilently() async {
    try {
      validateBaseData();
      schedules = await fetchAutomations(
        deviceId: deviceId,
        type: 'schedule',
      );

      if (error != null) {
        error = null;
        notifyListeners();
        return;
      }

      notifyListeners();
    } catch (err) {
      if (error == null) {
        setMappedError(err);
        notifyListeners();
      }
    }
  }

  void validateBaseData() {
    if (deviceId.trim().isEmpty) {
      throw const ValidationAppException(
        'No se ha encontrado un dispositivo válido.',
      );
    }

    if (host.trim().isEmpty) {
      throw const ValidationAppException(
        'No se ha encontrado la dirección del dispositivo.',
      );
    }
  }

  void validateInput({
    required int hour,
    required int minute,
    required String action,
    required List<int> days,
  }) {
    if (hour < 0 || hour > 23) {
      throw const ValidationAppException('La hora debe estar entre 0 y 23.');
    }

    if (minute < 0 || minute > 59) {
      throw const ValidationAppException(
        'Los minutos deben estar entre 0 y 59.',
      );
    }

    if (action != 'on' && action != 'off') {
      throw const ValidationAppException('La acción debe ser ON u OFF.');
    }

    if (days.isEmpty) {
      throw const ValidationAppException(
        'Debes seleccionar al menos un día.',
      );
    }
  }

  List<int> normalizeDays(List<int> days) {
    final normalized = days.toSet().toList()..sort();
    return normalized.where((day) => day >= 0 && day <= 6).toList();
  }

  String buildTimespec({
    required int hour,
    required int minute,
    required List<int> days,
  }) {
    final daysPart = days.join(',');
    final hh = hour.toString().padLeft(2, '0');
    final mm = minute.toString().padLeft(2, '0');
    return '0 $mm $hh * * $daysPart';
  }

  List<Map<String, dynamic>> buildCalls(String action) {
    final on = action == 'on';
    return [
      {
        'method': 'Switch.Set',
        'params': {'id': 0, 'on': on},
      },
    ];
  }

  Map<String, dynamic> mapFrom(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  int? intFrom(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  void setLoading(bool value) {
    loading = value;
    notifyListeners();
  }

  void setBusy(bool value) {
    busy = value;
    notifyListeners();
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  void setMappedError(Object error) {
    this.error = ErrorMapper.mapFailure(error).message;
    notifyListeners();
  }
}
