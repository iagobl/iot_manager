import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:iot_manager/core/constants/iot_strings.dart';

import '../../../../core/constants/devices_strings.dart';
import '../../../../core/iot/ble/ble_permissions.dart';
import '../../../../core/iot/shelly/shelly_ble_rpc_client.dart';
import '../../../../core/iot/shelly/shelly_lan_discovery.dart';
import '../../../../core/iot/wifi/wifi_info_service.dart';

class ShellyBleProvisionResult {
  final String ip;
  final Map<String, dynamic> deviceInfo;

  ShellyBleProvisionResult({
    required this.ip,
    required this.deviceInfo,
  });
}

class ShellyBleProvisionPage extends StatefulWidget {
  const ShellyBleProvisionPage({super.key});

  @override
  State<ShellyBleProvisionPage> createState() => _ShellyBleProvisionPageState();
}

class _ShellyBleProvisionPageState extends State<ShellyBleProvisionPage> {
  final _ssidCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _scanning = false;
  bool _provisioning = false;
  String _status = '';

  ScanResult? _selected;
  StreamSubscription<bool>? _scanSub;
  StreamSubscription<List<ScanResult>>? _scanResultsSub;
  List<ScanResult> _scanResults = [];

  @override
  void initState() {
    super.initState();
    _prefillSsid();
  }

  @override
  void dispose() {
    _ssidCtrl.dispose();
    _passCtrl.dispose();
    _scanSub?.cancel();
    _scanResultsSub?.cancel();
    super.dispose();
  }

  Future<void> _prefillSsid() async {
    final wifi = WifiInfoService();
    final ssid = await wifi.getCurrentSsid();
    if (!mounted || ssid == null || ssid.isEmpty) return;
    _ssidCtrl.text = ssid;
  }

  bool _looksLikeShelly(ScanResult r) {
    final name = _displayName(r).toLowerCase();
    return name.contains('addshelly') || name.contains('shelly');
  }

  List<ScanResult> _filterAndDedup(List<ScanResult> results) {
    final byId = <String, ScanResult>{};
    for (final r in results) {
      if (!_looksLikeShelly(r)) continue;
      final existing = byId[r.device.remoteId.str];
      if (existing == null || r.rssi > existing.rssi) {
        byId[r.device.remoteId.str] = r;
      }
    }
    final list = byId.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    return list;
  }

  Future<void> _startScan() async {
    setState(() {
      _selected = null;
      _scanning = true;
      _status = '';
      _scanResults = [];
    });

    try {
      await BlePermissions.ensure();

      final state = await FlutterBluePlus.adapterState.first;

      if (state != BluetoothAdapterState.on) {
        if (mounted) {
          setState(() => _scanning = false);
        }
        _snack(DevicesStrings.notBluetoothActivated);
        return;
      }

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 12),
        androidScanMode: AndroidScanMode.lowLatency,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _scanning = false);
      }
      _snack(DevicesStrings.errorConnectingBLE);
      return;
    }

    await _scanResultsSub?.cancel();
    _scanResultsSub = FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      setState(() {
        _scanResults = _filterAndDedup(results);
      });
    });

    await _scanSub?.cancel();
    _scanSub = FlutterBluePlus.isScanning.listen((scanning) {
      if (!mounted) return;
      if (!scanning) {
        setState(() => _scanning = false);
      }
    });
  }

  Future<void> _stopScan() async {
    await _scanResultsSub?.cancel();
    _scanResultsSub = null;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _provision() async {
    final ssid = _ssidCtrl.text.trim();
    final pass = _passCtrl.text;

    if (_selected == null) {
      _snack(DevicesStrings.selectDevice);
      return;
    }
    if (ssid.isEmpty) {
      _snack(IoTStrings.SSIDRequiredWIFI);
      return;
    }
    if (pass.isEmpty) {
      _snack(IoTStrings.passwordRequiredWIFI);
      return;
    }

    setState(() {
      _provisioning = true;
      _status = DevicesStrings.connectionBLE;
    });

    final device = _selected!.device;
    final client = ShellyBleRpcClient(device);

    try {
      await _stopScan();
      await client.connect();

      _setStatus(DevicesStrings.MACDevice);
      final realMac = await client.getRealMac();

      _setStatus(DevicesStrings.credentialsDevices);
      await client.setWifiSta(ssid: ssid, pass: pass);

      _setStatus(DevicesStrings.rebootDevice);
      await client.reboot(delayMs: 3000);
      await client.disconnect();

      _setStatus(DevicesStrings.runDevice);
      await Future.delayed(const Duration(seconds: 25));

      ShellyLanDiscoveryResult? found;
      final discovery = ShellyLanDiscovery();

      for (int attempt = 1; attempt <= 4; attempt++) {
        _setStatus(DevicesStrings.searchShellyDevices + '($attempt/4)');
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
        _snack(DevicesStrings.notFoundDevice);
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
      _snack(DevicesStrings.errorProvisioningBLE);
    } finally {
      try {
        await client.disconnect();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _provisioning = false;
          _status = '';
        });
      }
    }
  }

  void _setStatus(String msg) {
    if (mounted) setState(() => _status = msg);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  String _displayName(ScanResult r) {
    final adv = r.advertisementData.advName.trim();
    final platform = r.device.platformName.trim();
    if (adv.isNotEmpty) return adv;
    if (platform.isNotEmpty) return platform;
    return DevicesStrings.notNameBLE;
  }

  @override
  Widget build(BuildContext context) {
    final canProvision = !_provisioning && _selected != null;

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
                    onPressed: _scanning ? _stopScan : _startScan,
                    icon: Icon(
                      _scanning ? Icons.stop : Icons.bluetooth_searching,
                    ),
                    label: Text(
                      _scanning ? DevicesStrings.stopEscanning : DevicesStrings.scanningBle,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(DevicesStrings.foundDevices,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_scanning && _scanResults.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(DevicesStrings.searchShellyDevices),
                    )
                  else if (_scanResults.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(DevicesStrings.notFoundBluetoothDevices),
                    )
                  else
                    Column(
                      children: _scanResults.map((r) {
                        final name = _displayName(r);
                        final selected = _selected?.device.remoteId == r.device.remoteId;

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
                            onTap: () => setState(() => _selected = r),
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
                    controller: _ssidCtrl,
                    decoration: const InputDecoration(
                      labelText: DevicesStrings.SSID,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: DevicesStrings.password,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_status.isNotEmpty) ...[
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
                    Expanded(child: Text(_status)),
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
          onPressed: canProvision ? _provision : null,
          icon: const Icon(Icons.link),
          label: Text(
            _provisioning ? DevicesStrings.connectingDevice : DevicesStrings.vindicatingDevice,
          ),
        ),
      ),
    );
  }
}