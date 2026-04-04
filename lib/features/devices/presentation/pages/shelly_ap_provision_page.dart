import 'package:flutter/material.dart';

import 'package:iot_manager/core/constants/devices_strings.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/core/iot/shelly/shelly_ap_provision_service.dart';
import 'package:iot_manager/core/iot/wifi/shelly_ap_wifi_service.dart';
import 'package:iot_manager/core/iot/wifi/wifi_info_service.dart';
import 'package:iot_manager/core/widgets/app_text_field.dart';
import 'package:iot_manager/core/widgets/primary_button.dart';

class ShellyApProvisionPageResult {
  const ShellyApProvisionPageResult({
    required this.ip,
    required this.deviceInfo,
  });

  final String ip;
  final Map<String, dynamic> deviceInfo;
}

class ShellyApProvisionPage extends StatefulWidget {
  const ShellyApProvisionPage({super.key});

  @override
  State<ShellyApProvisionPage> createState() => _ShellyApProvisionPageState();
}

class _ShellyApProvisionPageState extends State<ShellyApProvisionPage> {
  final homeSsidCtrl = TextEditingController();
  final homePassCtrl = TextEditingController();

  final ShellyApWifiService apWifiService = ShellyApWifiService();
  final ShellyApProvisionService provisionService = ShellyApProvisionService();
  final WifiInfoService wifiInfoService = WifiInfoService();

  List<ShellyApAccessPoint> accessPoints = [];
  ShellyApAccessPoint? selectedAccessPoint;
  ShellyApDeviceSession? connectedSession;

  bool loadingInitialWifi = true;
  bool scanningAps = false;
  bool connectingToAp = false;
  bool sendingCredentials = false;
  bool discoveringOnLan = false;

  String? errorMessage;
  String statusMessage = DevicesStrings.apInitialStatus;

  @override
  void initState() {
    super.initState();
    prefillHomeWifi();
  }

  @override
  void dispose() {
    homeSsidCtrl.dispose();
    homePassCtrl.dispose();
    super.dispose();
  }

  Future<void> prefillHomeWifi() async {
    setState(() {
      loadingInitialWifi = true;
      errorMessage = null;
    });

    try {
      final ssid = await wifiInfoService.getCurrentSsid();
      if (ssid != null && ssid.isNotEmpty) {
        homeSsidCtrl.text = ssid;
      }
      statusMessage = DevicesStrings.apReadyToStart;
    } catch (e) {
      errorMessage = mapError(e);
    } finally {
      if (mounted) {
        setState(() {loadingInitialWifi = false;});
      }
    }
  }

  Future<void> scanShellyNetworks() async {
    setState(() {
      scanningAps = true;
      errorMessage = null;
      statusMessage = DevicesStrings.searchShellyApDevices;
    });

    try {
      final results = await apWifiService.scanShellyAccessPoints();

      setState(() {
        accessPoints = results;
        if (results.isNotEmpty) {
          selectedAccessPoint = results.first;
          statusMessage = DevicesStrings.selectShellyApNetwork;
        } else {
          statusMessage = DevicesStrings.notFoundShellyApNetworks;
        }
      });
    } catch (e) {
      setState(() {errorMessage = mapError(e);});
    } finally {
      if (mounted) {
        setState(() {scanningAps = false;});
      }
    }
  }

  Future<void> runAutomaticApProvision() async {
    final ap = selectedAccessPoint;
    if (ap == null) {
      setState(() {errorMessage = DevicesStrings.selectShellyApFirst;});
      return;
    }

    if (homeSsidCtrl.text.trim().isEmpty) {
      setState(() {errorMessage = 'Debes indicar el SSID de tu Wi-Fi';});
      return;
    }

    if (homePassCtrl.text.isEmpty) {
      setState(() {errorMessage = 'Debes indicar la contraseña de tu Wi-Fi';});
      return;
    }

    setState(() {
      connectingToAp = true;
      sendingCredentials = true;
      discoveringOnLan = true;
      errorMessage = null;
      statusMessage = DevicesStrings.connectingShellyAp;
    });

    try {
      final session = await provisionService.connectAndReadDeviceInfo(ap);

      if (!mounted) return;
      setState(() {
        connectedSession = session;
        statusMessage = DevicesStrings.credentialsDevices;
      });

      await provisionService.sendWifiCredentials(
        ssid: homeSsidCtrl.text.trim(),
        password: homePassCtrl.text,
      );

      if (!mounted) return;
      setState(() {statusMessage = DevicesStrings.runDevice;});

      await Future.delayed(const Duration(seconds: 15));

      ShellyApProvisionResult? result;

      for (int attempt = 1; attempt <= 5; attempt++) {
        if (!mounted) return;

        setState(() {statusMessage = 'Buscando dispositivo en tu red... (intento $attempt/5)';});

        try {
          result = await provisionService.discoverProvisionedDevice(expectedMac: session.mac);
          break;
        } catch (_) {
          if (attempt < 5) {
            await Future.delayed(const Duration(seconds: 4));
          }
        }
      }

      if (result == null) {
        throw Exception('El Shelly recibió la configuración, pero todavía no apareció en la red.');
      }

      if (!mounted) return;

      Navigator.of(context).pop(
        ShellyApProvisionPageResult(ip: result.ip, deviceInfo: result.deviceInfo),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = mapError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          connectingToAp = false;
          sendingCredentials = false;
          discoveringOnLan = false;
        });
      }
    }
  }

  Future<void> continueWithManualApConnection() async {
    final ap = selectedAccessPoint;
    if (ap == null) {
      setState(() {errorMessage = DevicesStrings.selectShellyApFirst;});
      return;
    }

    if (homeSsidCtrl.text.trim().isEmpty) {
      setState(() {errorMessage = 'Debes indicar el SSID de tu Wi-Fi';});
      return;
    }

    if (homePassCtrl.text.isEmpty) {
      setState(() {errorMessage = 'Debes indicar la contraseña de tu Wi-Fi';});
      return;
    }

    setState(() {
      connectingToAp = true;
      sendingCredentials = true;
      discoveringOnLan = true;
      errorMessage = null;
      statusMessage = DevicesStrings.validatingManualShellyApConnection;
    });

    try {
      final session = await provisionService.readDeviceInfoFromCurrentAp(ap);

      if (!mounted) return;
      setState(() {
        connectedSession = session;
        statusMessage = DevicesStrings.credentialsDevices;
      });

      await provisionService.sendWifiCredentials(
        ssid: homeSsidCtrl.text.trim(),
        password: homePassCtrl.text,
      );

      if (!mounted) return;
      setState(() {statusMessage = DevicesStrings.runDevice;});

      await Future.delayed(const Duration(seconds: 15));

      ShellyApProvisionResult? result;

      for (int attempt = 1; attempt <= 5; attempt++) {
        if (!mounted) return;

        setState(() {statusMessage = 'Buscando dispositivo en tu red... (intento $attempt/5)';});

        try {
          result = await provisionService.discoverProvisionedDevice(
            expectedMac: session.mac,
          );
          break;
        } catch (_) {
          if (attempt < 5) {
            await Future.delayed(const Duration(seconds: 4));
          }
        }
      }

      if (result == null) {
        throw Exception('El Shelly recibió la configuración, pero todavía no apareció en la red.');
      }

      if (!mounted) return;

      Navigator.of(context).pop(
        ShellyApProvisionPageResult(ip: result.ip, deviceInfo: result.deviceInfo),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {errorMessage = mapError(e);});
    } finally {
      if (mounted) {
        setState(() {
          connectingToAp = false;
          sendingCredentials = false;
          discoveringOnLan = false;
        });
      }
    }
  }

  String mapError(Object error) {
    final mapped = ErrorMapper.mapException(error);
    return mapped.message;
  }

  bool get isProcessing => scanningAps || connectingToAp || sendingCredentials || discoveringOnLan;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(DevicesStrings.configurationAp)),
      body: SafeArea(
        child: loadingInitialWifi ? const Center(child: CircularProgressIndicator())
            : ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            buildStatusCard(),
            const SizedBox(height: 16),
            buildHomeWifiCard(),
            const SizedBox(height: 16),
            buildShellyApScanCard(),
            const SizedBox(height: 16),
            buildConnectCard(),
          ],
        ),
      ),
    );
  }

  Widget buildStatusCard() {
    final hasError = errorMessage != null && errorMessage!.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DevicesStrings.apModeTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(DevicesStrings.apModeDescription),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(hasError
                    ? Icons.error_outline_rounded
                    : isProcessing
                    ? Icons.sync_rounded
                    : Icons.info_outline_rounded,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(hasError ? errorMessage! : statusMessage)),
              ],
            ),
            if (isProcessing) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildHomeWifiCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            buildSectionTitle(
              icon: Icons.wifi_rounded,
              title: DevicesStrings.homeWifiConfiguration,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: homeSsidCtrl,
              label: DevicesStrings.ssid,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: homePassCtrl,
              label: DevicesStrings.password,
              obscureText: true,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 12),
            Text(DevicesStrings.apModeHomeWifiHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildShellyApScanCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            buildSectionTitle(
              icon: Icons.wifi_find_rounded,
              title: DevicesStrings.searchShellyApTitle,
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              text: DevicesStrings.searchShellyApButton,
              icon: Icons.search_rounded,
              loading: scanningAps,
              onPressed: isProcessing ? null : scanShellyNetworks,
            ),
            const SizedBox(height: 12),
            if (accessPoints.isEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(DevicesStrings.notFoundShellyApNetworks),
              )
            else
              RadioGroup<ShellyApAccessPoint>(
                groupValue: selectedAccessPoint,
                onChanged: (value) {
                  if (value == null || isProcessing) return;
                  setState(() {selectedAccessPoint = value;});
                },
                child: Column(
                  children: accessPoints.map((ap) => RadioListTile<ShellyApAccessPoint>(
                      value: ap,
                      contentPadding: EdgeInsets.zero,
                      title: Text(ap.ssid),
                      subtitle: Text(ap.bssid == null || ap.bssid!.isEmpty
                            ? DevicesStrings.shellyApDetected
                            : ap.bssid!,
                      ), secondary: const Icon(Icons.router_rounded),
                    ),
                  ).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget buildConnectCard() {
    final selectedName = selectedAccessPoint?.ssid;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            buildSectionTitle(
              icon: Icons.link_rounded,
              title: DevicesStrings.connectShellyApTitle,
            ),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft,
              child: Text(selectedName == null ? DevicesStrings.noShellyApSelected
                    : '${DevicesStrings.selectedShellyAp}: $selectedName',
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              text: DevicesStrings.connectShellyApAutomaticallyButton,
              icon: Icons.wifi_tethering_rounded,
              loading: connectingToAp || sendingCredentials || discoveringOnLan,
              onPressed: selectedAccessPoint == null || scanningAps ? null
                  : runAutomaticApProvision,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: selectedAccessPoint == null || isProcessing ? null
                  : continueWithManualApConnection,
              icon: const Icon(Icons.settings_ethernet_rounded),
              label: const Text(DevicesStrings.iAmAlreadyConnectedToShellyAp),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(DevicesStrings.apManualFallbackHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSectionTitle({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}