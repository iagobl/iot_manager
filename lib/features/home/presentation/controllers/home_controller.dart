import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';
import 'package:iot_manager/features/devices/data/repositories/devices_repository_impl.dart';
import 'package:iot_manager/features/home/data/datasources/home_remote_datasource.dart';
import 'package:iot_manager/features/home/data/repositories/home_repository_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeController extends ChangeNotifier {
  HomeController._(this.homeRepo, this._deviceRepo);

  factory HomeController.create() {
    final client = Supabase.instance.client;

    return HomeController._(
      HomeRepositoryImpl(HomeRemoteDatasource(client)),
      DevicesRepositoryImpl(DevicesRemoteDatasource()),
    );
  }

  final HomeRepositoryImpl homeRepo;
  final DevicesRepositoryImpl _deviceRepo;

  bool loading = false;
  String? errorMessage;
  dynamic overview;

  String firstName = '';

  int totalHomes = 0;
  int totalDevices = 0;
  int activeDevices = 0;
  double totalTodayWh = 0;
  int incidentsCount = 0;

  bool creatingHome = false;
  String? deletingId;

  List get homes => overview?.homes ?? [];

  Timer? timer;

  Future<void> load() async {
    loading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final data = await homeRepo.getOverview();
      overview = data;
      firstName = data.firstName;
      await calculateStats();
      startAutoRefresh();
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> calculateStats() async {
    final devices = overview?.devices ?? [];

    totalHomes = homes.length;
    totalDevices = devices.length;
    activeDevices = 0;
    totalTodayWh = 0;

    for (final d in devices) {
      final isActive = await _deviceRepo.isDeviceActive(d);
      if (isActive) {
        activeDevices++;
      }

      totalTodayWh += (d.energyTodayWh ?? 0);
    }
  }

  void startAutoRefresh() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        if (overview == null) return;
        await calculateStats();
        notifyListeners();
      } catch (_) {}
    });
  }

  Future<bool> createHome(String name) async {
    creatingHome = true;
    errorMessage = null;
    notifyListeners();

    try {
      await homeRepo.createHome(name: name);
      await load();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      creatingHome = false;
      notifyListeners();
    }
  }

  Future<bool> deleteHome(String homeId) async {
    deletingId = homeId;
    errorMessage = null;
    notifyListeners();

    try {
      await homeRepo.deleteHome(homeId: homeId);
      await load();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      deletingId = null;
      notifyListeners();
    }
  }

  Future<void> loadIncidents(String homeId) async {
    try {
      incidentsCount = await homeRepo.getActiveIncidentsCount(homeId);
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }
}