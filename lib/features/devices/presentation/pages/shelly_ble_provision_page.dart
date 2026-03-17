import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:iot_manager/core/constants/devices_strings.dart';
import 'package:iot_manager/core/constants/iot_strings.dart';
import 'package:iot_manager/core/iot/ble/ble_permissions.dart';
import 'package:iot_manager/core/iot/shelly/shelly_ble_rpc_client.dart';
import 'package:iot_manager/core/iot/shelly/shelly_lan_discovery.dart';
import 'package:iot_manager/core/iot/wifi/wifi_info_service.dart';

class ShellyBleProvisionResult {

  ShellyBleProvisionResult({
    required this.ip,
    required this.deviceInfo,
  });
  final String ip;
  final Map<String, dynamic> deviceInfo;
}

class ShellyBleProvisionPage extends StatefulWidget {
  const ShellyBleProvisionPage({super.key});

  @override
  State<ShellyBleProvisionPage> createState() => ShellyBleProvisionPageState();
}

class ShellyBleProvisionPageState extends State<ShellyBleProvisionPage> {
  final ssidCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  bool scanning = false;
  bool provisioning = false;
  String status = '';

  ScanResult? selected;
  StreamSubscription<bool>? scanSub;
  StreamSubscription<List<ScanResult>>? scanResultsSub;
  List<ScanResult> scanResults = [];

  @override
  void initState() {
    super.initState();
    prefillSsid();
  }

  @override
  void dispose() {
    ssidCtrl.dispose();
    passCtrl.dispose();
    scanSub?.cancel();
    scanResultsSub?.cancel();
    super.dispose();
  }

  Future<void> prefillSsid() async {
    final wifi = WifiInfoService();
    final ssid = await wifi.getCurrentSsid();
    if (!mounted || ssid == null || ssid.isEmpty) return;
    ssidCtrl.text = ssid;
  }

  bool looksLikeShelly(ScanResult r) {
    final name = displayName(r).toLowerCase();
    return name.contains('addshelly') || name.contains('shelly');
  }

  List<ScanResult> filterAndDedup(List<ScanResult> results) {
    final byId = <String, ScanResult>{};
    for (final r in results) {
      if (!looksLikeShelly(r)) continue;
      final existing = byId[r.device.remoteId.str];
      if (existing == null || r.rssi > existing.rssi) {
        byId[r.device.remoteId.str] = r;
      }
    }
    final list = byId.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    return list;
  }

  Future<void> startScan() async {
    setState(() {
      selected = null;
      scanning = true;
      status = '';
      scanResults = [];
    });

    try {
      await BlePermissions.ensure();

      final state = await FlutterBluePlus.adapterState.first;

      if (state != BluetoothAdapterState.on) {
        if (mounted) {
          setState(() => scanning = false);
        }
        snack(DevicesStrings.notBluetoothActivated);
        return;
      }

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 12),
        androidScanMode: AndroidScanMode.lowLatency,
      );
    } catch (e) {
      if (mounted) {
        setState(() => scanning = false);
      }
      snack(DevicesStrings.errorConnectingBLE);
      return;
    }

    await scanResultsSub?.cancel();
    scanResultsSub = FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      setState(() {
        scanResults = filterAndDedup(results);
      });
    });

    await scanSub?.cancel();
    scanSub = FlutterBluePlus.isScanning.listen((scanning) {
      if (!mounted) return;
      if (!scanning) {
        setState(() => this.scanning = false);
      }
    });
  }

  Future<void> stopScan() async {
    await scanResultsSub?.cancel();
    scanResultsSub = null;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    if (mounted) setState(() => scanning = false);
  }

  Future<void> provision() async {
    final ssid = ssidCtrl.text.trim();
    final pass = passCtrl.text;

    if (selected == null) {
      snack(DevicesStrings.selectDevice);
      return;
    }
    if (ssid.isEmpty) {
      snack(IoTStrings.ssidRequiredWifi);
      return;
    }
    if (pass.isEmpty) {
      snack(IoTStrings.passwordRequiredWIFI);
      return;
    }

    setState(() {
      provisioning = true;
      status = DevicesStrings.connectionBLE;
    });

    final device = selected!.device;
    final client = ShellyBleRpcClient(device);

    try {
      await stopScan();
      await client.connect();

      setStatus(DevicesStrings.macDevice);
      final realMac = await client.getRealMac();

      setStatus(DevicesStrings.credentialsDevices);
      await client.setWifiSta(ssid: ssid, pass: pass);

      setStatus(DevicesStrings.rebootDevice);
      await client.reboot(delayMs: 3000);
      await client.disconnect();

      setStatus(DevicesStrings.runDevice);
      await Future.delayed(const Duration(seconds: 25));

      ShellyLanDiscoveryResult? found;
      final discovery = ShellyLanDiscovery();

      for (int attempt = 1; attempt <= 4; attempt++) {
        setStatus('${DevicesStrings.searchShellyDevices}($attempt/4)');
        found = await discovery.discoverFirst(
          expectedMac: realMac,
          perHostTimeout: const Duration(milliseconds: 600),
          concurrency: 40,
        );
        if (found != null) break;
        if (attempt < 4) {
          await Future.delayed(const Duration(seconds: 10));
        }
      }

      if (found == null) {
        snack(DevicesStrings.notFoundDevice);
        return;
      }

      if (!mounted) return;
      Navigator.pop(
        context,
        ShellyBleProvisionResult(
          ip: found.ip,
          deviceInfo: found.deviceInfo,
        ),
      );
    } catch (e) {
      snack(DevicesStrings.errorProvisioningBLE);
    } finally {
      try {
        await client.disconnect();
      } catch (_) {}
      if (mounted) {
        setState(() {
          provisioning = false;
          status = '';
        });
      }
    }
  }

  void setStatus(String msg) {
    if (mounted) setState(() => status = msg);
  }

  void snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  String displayName(ScanResult r) {
    final adv = r.advertisementData.advName.trim();
    final platform = r.device.platformName.trim();
    if (adv.isNotEmpty) return adv;
    if (platform.isNotEmpty) return platform;
    return DevicesStrings.notNameBLE;
  }

  @override
  Widget build(BuildContext context) {
    final canProvision = !provisioning && selected != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(DevicesStrings.addShellyDevice),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: scanning ? stopScan : startScan,
                    icon: Icon(
                      scanning ? Icons.stop : Icons.bluetooth_searching,
                    ),
                    label: Text(
                      scanning ? DevicesStrings.stopEscanning : DevicesStrings.scanningBle,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(DevicesStrings.foundDevices,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (scanning && scanResults.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(DevicesStrings.searchShellyDevices),
                    )
                  else if (scanResults.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(DevicesStrings.notFoundBluetoothDevices),
                    )
                  else
                    Column(
                      children: scanResults.map((r) {
                        final name = displayName(r);
                        final selected = this.selected?.device.remoteId == r.device.remoteId;

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                            ),
                            title: Text(name),
                            subtitle: Text('RSSI: ${r.rssi} • ${r.device.remoteId.str}',),
                            onTap: () => setState(() => this.selected = r),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    controller: ssidCtrl,
                    decoration: const InputDecoration(
                      labelText: DevicesStrings.ssid,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: DevicesStrings.password,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (status.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(status)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: canProvision ? provision : null,
          icon: const Icon(Icons.link),
          label: Text(
            provisioning ? DevicesStrings.connectingDevice : DevicesStrings.vindicatingDevice,
          ),
        ),
      ),
    );
  }
}