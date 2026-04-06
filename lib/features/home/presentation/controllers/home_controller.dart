import 'package:flutter/foundation.dart';
import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';
import 'package:iot_manager/features/devices/data/repositories/devices_repository_impl.dart';
import 'package:iot_manager/features/devices/domain/entities/device_item.dart';
import 'package:iot_manager/features/home/data/datasources/home_remote_datasource.dart';
import 'package:iot_manager/features/home/data/repositories/home_repository_impl.dart';
import 'package:iot_manager/features/home/domain/entities/home_overview.dart';
import 'package:iot_manager/features/home/domain/entities/home_summary.dart';
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
  bool refreshing = false;
  String? errorMessage;
  HomeOverview? overview;

  String firstName = '';

  int totalHomes = 0;
  int totalDevices = 0;
  int activeDevices = 0;
  double totalTodayWh = 0;
  int incidentsCount = 0;

  bool creatingHome = false;
  String? deletingId;

  List<HomeSummary> get homes => overview?.homes ?? <HomeSummary>[];
  List<DeviceItem> get devices => overview?.devices ?? <DeviceItem>[];

  Future<void> load({bool silent = false}) async {
    final hasData = overview != null;

    if (silent && hasData) {
      refreshing = true;
    } else {
      loading = true;
    }

    errorMessage = null;
    notifyListeners();

    try {
      final data = await homeRepo.getOverview();
      overview = data;
      firstName = data.firstName;
      await calculateStats(data);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      loading = false;
      refreshing = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await load(silent: true);
  }

  Future<void> calculateStats(HomeOverview data) async {
    totalHomes = data.homes.length;
    totalDevices = data.devices.length;
    activeDevices = 0;
    totalTodayWh = 0;

    for (final device in data.devices) {
      totalTodayWh += device.energyTodayWh;

      try {
        final isActive = await _deviceRepo.isDeviceActive(device);
        if (isActive) {
          activeDevices++;
        }
      } catch (_) {}
    }
  }

  int getDeviceCountForHome(String homeId) {
    return devices.where((device) => device.homeId == homeId).length;
  }

  Future<bool> createHome(String name) async {
    creatingHome = true;
    errorMessage = null;
    notifyListeners();

    try {
      await homeRepo.createHome(name: name);
      await load(silent: true);
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
      await load(silent: true);
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
}