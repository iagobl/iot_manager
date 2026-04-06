import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:iot_manager/features/home/data/repositories/home_safety_repository_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeDetailController {

  HomeDetailController({
    required this.homeId,
  });
  final String homeId;
  final SupabaseClient _client = Supabase.instance.client;
  final HomeSafetyRepositoryImpl safetyRepository = HomeSafetyRepositoryImpl();

  List<Map<String, dynamic>> devices = [];
  List<Map<String, dynamic>> availableDevices = [];
  Map<String, dynamic>? securitySettings;

  bool isLoading = false;
  bool isLoadingAvailableDevices = false;

  int activeDevices = 0;
  int unresolvedIncidents = 0;
  double todayConsumptionWh = 0;

  final Set<String> selectedAvailableDeviceIds = {};

  Timer? refreshTimer;
  Function()? onUpdate;

  Future<void> init({
    required Function() onUpdate,
  }) async {
    this.onUpdate = onUpdate;
    await load();
    startAutoRefresh();
  }

  Future<void> load() async {
    isLoading = true;
    notify();

    try {
      final devicesResponse = await _client
          .from('devices')
          .select()
          .eq('home_id', homeId)
          .order('created_at');

      devices = List<Map<String, dynamic>>.from(devicesResponse);
      await loadIncidentsCount();
      securitySettings = await safetyRepository.getSafetySettings(homeId);

      await refreshLiveDeviceStates();
      recalculateStats();
    } finally {
      isLoading = false;
      notify();
    }
  }

  Future<void> loadIncidentsCount() async {
    final devicesResponse = await _client
        .from('devices')
        .select('id')
        .eq('home_id', homeId);

    final deviceIds = devicesResponse.map((e) => e['id'] as String).toList();

    if (deviceIds.isEmpty) {
      unresolvedIncidents = 0;
      return;
    }

    final incidentsResponse = await _client
        .from('incidents')
        .select('id')
        .inFilter('device_id', deviceIds)
        .eq('is_resolved', false);

    unresolvedIncidents = incidentsResponse.length;
  }

  Future<void> loadAvailableDevices() async {
    isLoadingAvailableDevices = true;
    notify();

    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('No hay una sesión activa.');
      }

      final response = await _client
          .from('devices')
          .select()
          .isFilter('home_id', null)
          .eq('owner_id', currentUserId)
          .order('created_at');

      availableDevices = List<Map<String, dynamic>>.from(response);
    } finally {
      isLoadingAvailableDevices = false;
      notify();
    }
  }

  void toggleAvailableDeviceSelection(String deviceId) {
    if (selectedAvailableDeviceIds.contains(deviceId)) {
      selectedAvailableDeviceIds.remove(deviceId);
    } else {
      selectedAvailableDeviceIds.add(deviceId);
    }
    notify();
  }

  Future<void> assignSelectedDevicesToHome() async {
    if (selectedAvailableDeviceIds.isEmpty) return;

    for (final deviceId in selectedAvailableDeviceIds) {
      await _client
          .from('devices')
          .update({'home_id': homeId})
          .eq('id', deviceId);
    }

    selectedAvailableDeviceIds.clear();
    await load();
    await loadAvailableDevices();
  }

  Future<void> removeDeviceFromHome(String deviceId) async {
    await _client.from('devices').update({'home_id': null}).eq('id', deviceId);
    await load();
  }

  Future<void> refreshLiveDeviceStates() async {
    final updatedDevices = <Map<String, dynamic>>[];

    for (final device in devices) {
      final enriched = Map<String, dynamic>.from(device);
      final identifier = (device['identifier'] ?? '').toString().trim();

      bool liveIsActive = (device['is_active'] ?? false) == true;
      double livePower = 0;

      if (identifier.isNotEmpty) {
        try {
          final uri = Uri.parse('http://$identifier/rpc/Switch.GetStatus?id=0');
          final response = await http.get(uri).timeout(const Duration(seconds: 3));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            liveIsActive = (data['output'] ?? false) == true;
            livePower = ((data['apower'] as num?) ?? 0).toDouble();
          }
        } catch (_) {}
      }

      enriched['live_is_active'] = liveIsActive;
      enriched['power_w'] = livePower;
      updatedDevices.add(enriched);
    }
    devices = updatedDevices;
  }

  void recalculateStats() {
    activeDevices = 0;
    todayConsumptionWh = 0;

    for (final device in devices) {
      if ((device['live_is_active'] ?? false) == true) {
        activeDevices++;
      }
      todayConsumptionWh += ((device['energy_today_wh'] as num?) ?? 0).toDouble();
    }
  }

  void startAutoRefresh() {
    refreshTimer?.cancel();
    refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) async {
      try {
        await refreshLiveDeviceStates();
        await loadIncidentsCount();
        recalculateStats();
        notify();
      } catch (_) {}
    });
  }

  void notify() {
    onUpdate?.call();
  }

  void dispose() {
    refreshTimer?.cancel();
  }
}