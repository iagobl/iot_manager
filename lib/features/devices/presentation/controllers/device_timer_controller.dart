import 'package:flutter/foundation.dart';
import 'package:iot_manager/core/error/app_exception.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';

class DeviceTimerController extends ChangeNotifier {
  DeviceTimerController({
    required this.deviceId,
    required this.remoteDatasource,
  });

  final String deviceId;
  final DevicesRemoteDatasource remoteDatasource;

  bool loading = false;
  bool busy = false;
  List<Map<String, dynamic>> timers = [];
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      timers = await remoteDatasource.fetchAutomations(
        deviceId: deviceId,
        type: 'timer',
      );
    } catch (err) {
      final failure = ErrorMapper.mapFailure(err);
      error = failure.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> create({
    required int hours,
    required int minutes,
    required int seconds,
    required String action,
  }) async {
    final totalSeconds = hours * 3600 + minutes * 60 + seconds;

    if (totalSeconds <= 0) {
      throw const ValidationAppException('El temporizador debe ser mayor que 0.');
    }

    busy = true;
    error = null;
    notifyListeners();

    try {
      await remoteDatasource.upsertAutomation(
        deviceId: deviceId,
        type: 'timer',
        enabled: false,
        config: {
          'duration_seconds': totalSeconds,
          'action': action,
          'started_at': null,
          'completed_at': null,
        },
      );

      await load();
    } catch (err) {
      final failure = ErrorMapper.mapFailure(err);
      error = failure.message;
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> delete(String automationId) async {
    if (automationId.trim().isEmpty) return;

    busy = true;
    error = null;
    notifyListeners();

    try {
      await remoteDatasource.deleteAutomation(automationId);
      await load();
    } catch (err) {
      final failure = ErrorMapper.mapFailure(err);
      error = failure.message;
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> toggle(Map<String, dynamic> row, bool enabled) async {
    final id = (row['id'] ?? '').toString();
    if (id.isEmpty) return;

    final cfg = (row['config'] is Map) ? Map<String, dynamic>.from(row['config'] as Map) : <String, dynamic>{};

    final updatedConfig = <String, dynamic>{
      ...cfg,
      if (enabled) 'started_at': DateTime.now().toUtc().toIso8601String(),
      if (enabled) 'completed_at': null,
      if (!enabled) 'started_at': null,
    };

    busy = true;
    error = null;
    notifyListeners();

    try {
      await remoteDatasource.upsertAutomation(
        id: id,
        deviceId: deviceId,
        type: 'timer',
        enabled: enabled,
        config: updatedConfig,
      );

      await load();
    } catch (err) {
      final failure = ErrorMapper.mapFailure(err);
      error = failure.message;
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> processExpiredTimers({required Future<void> Function(bool on) onExecute,}) async {
    if (loading || busy) return;
    if (timers.isEmpty) return;

    for (final row in timers) {
      final enabled = row['enabled'] == true;
      if (!enabled) continue;

      final cfg = (row['config'] is Map) ? Map<String, dynamic>.from(row['config'] as Map) : <String, dynamic>{};

      final durationSeconds = intFrom(cfg['duration_seconds']) ?? 0;
      final startedAt = parseDateTime(cfg['started_at']);
      final action = (cfg['action']?.toString() ?? 'off').toLowerCase();
      final completedAt = cfg['completed_at'];

      if (completedAt != null) continue;

      final remaining = remainingDuration(
        durationSeconds: durationSeconds,
        startedAt: startedAt,
        enabled: enabled,
      );

      if (remaining > Duration.zero) continue;

      try {
        await onExecute(action == 'on');

        final id = (row['id'] ?? '').toString();
        if (id.isEmpty) continue;

        final updatedConfig = <String, dynamic>{
          ...cfg,
          'completed_at': DateTime.now().toUtc().toIso8601String(),
          'started_at': null,
        };

        await remoteDatasource.upsertAutomation(
          id: id,
          deviceId: deviceId,
          type: 'timer',
          enabled: false,
          config: updatedConfig,
        );

        await load();
      } catch (err) {
        final failure = ErrorMapper.mapFailure(err);
        error = failure.message;
        notifyListeners();
      }

      break;
    }
  }

  static int? intFrom(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static DateTime? parseDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  static Duration remainingDuration({
    required int durationSeconds,
    required DateTime? startedAt,
    required bool enabled,
  }) {
    if (!enabled || startedAt == null || durationSeconds <= 0) {
      return Duration(seconds: durationSeconds.clamp(0, 999999));
    }

    final end = startedAt.add(Duration(seconds: durationSeconds));
    final diff = end.difference(DateTime.now());

    return diff.isNegative ? Duration.zero : diff;
  }

  static String formatDurationCompact(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00';

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}