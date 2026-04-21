import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';
import 'package:iot_manager/features/devices/data/repositories/devices_repository_impl.dart';
import 'package:iot_manager/features/devices/domain/usecases/fetch_incidents.dart';

class DeviceIncidentsController extends ChangeNotifier {
  DeviceIncidentsController({
    required this.deviceId,
    required DevicesRemoteDatasource remoteDatasource,
  }) : fetchIncidents = FetchIncidents(
    DevicesRepositoryImpl(remoteDatasource),
  );

  final String deviceId;
  final FetchIncidents fetchIncidents;

  bool loading = false;
  String? error;
  List<Map<String, dynamic>> incidents = [];

  Timer? pollTimer;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      incidents = await fetchIncidents(
        deviceId: deviceId,
        limit: 100,
      );
    } catch (err) {
      final failure = ErrorMapper.mapFailure(err);
      error = failure.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshSilently() async {
    if (loading) return;

    try {
      incidents = await fetchIncidents(
        deviceId: deviceId,
        limit: 100,
      );

      if (error != null) {
        error = null;
      }

      notifyListeners();
    } catch (err) {
      final failure = ErrorMapper.mapFailure(err);

      if (error == null) {
        error = failure.message;
        notifyListeners();
      }
    }
  }

  void startPolling() {
    pollTimer?.cancel();
    pollTimer = Timer.periodic(
      const Duration(seconds: 5),
          (_) => unawaited(refreshSilently()),
    );
  }

  Future<void> initialize() async {
    await load();
    startPolling();
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    super.dispose();
  }
}
