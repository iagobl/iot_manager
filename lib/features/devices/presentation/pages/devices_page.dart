import 'package:flutter/material.dart';

import 'package:iot_manager/core/constants/app_strings.dart';
import 'package:iot_manager/core/constants/devices_strings.dart';
import 'package:iot_manager/core/iot/models/discovered_iot_device.dart';

import 'package:iot_manager/features/devices/presentation/controllers/devices_controller.dart';
import 'package:iot_manager/features/devices/presentation/pages/device_panel_page.dart';
import 'package:iot_manager/features/devices/presentation/pages/shelly_ap_provision_page.dart';
import 'package:iot_manager/features/devices/presentation/pages/shelly_ble_provision_page.dart';
import 'package:iot_manager/features/devices/presentation/widgets/device_card.dart';

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => DevicesPageState();
}

class DevicesPageState extends State<DevicesPage> {
  late final DevicesController controller;

  Future<void> refreshFromShell() async {
    await controller.load();
  }

  @override
  void initState() {
    super.initState();
    controller = DevicesController.create();
    controller.addListener(onControllerChanged);
    controller.load();
  }

  void onControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(onControllerChanged);
    controller.dispose();
    super.dispose();
  }

  Future<void> openAddOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.bluetooth_searching_rounded),
                  title: const Text(DevicesStrings.configurationBluetooth),
                  subtitle: const Text(DevicesStrings.configurationBluetoothSubtitle,),
                  onTap: () async {
                    Navigator.of(bottomSheetContext).pop();
                    await openBleProvisionFlow();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.wifi_find_rounded),
                  title: const Text(DevicesStrings.scanningLan),
                  subtitle: const Text(DevicesStrings.scanningLanSubtitle,),
                  onTap: () async {
                    Navigator.of(bottomSheetContext).pop();
                    await scanNetwork();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.router_rounded),
                  title: const Text(DevicesStrings.configurationAp),
                  subtitle: const Text(DevicesStrings.configurationApSubtitle,),
                  onTap: () async {
                    Navigator.of(bottomSheetContext).pop();
                    await openApProvisionFlow();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> openBleProvisionFlow() async {
    final result = await Navigator.of(context).push<ShellyBleProvisionResult>(
      MaterialPageRoute(
        builder: (_) => const ShellyBleProvisionPage(),
      ),
    );

    if (!mounted || result == null) return;

    final model = (result.deviceInfo['model'] ?? '').toString().trim();
    final suggestedName = model.isNotEmpty ? model : 'Shelly';
    final type = inferTypeFromModel(model);

    await controller.addManualDevice(
      name: suggestedName,
      deviceType: type,
      identifier: result.ip,
    );

    showControllerMessageIfNeeded(
      successMessage: DevicesStrings.addDeviceSucesful,
    );
  }

  Future<void> openApProvisionFlow() async {
    final result = await Navigator.of(context).push<ShellyApProvisionPageResult>(
      MaterialPageRoute(builder: (_) => const ShellyApProvisionPage()),
    );

    if (!mounted || result == null) return;

    final model = (result.deviceInfo['model'] ?? '').toString().trim();
    final suggestedName = model.isNotEmpty ? model : 'Shelly';
    final type = inferTypeFromModel(model);

    await controller.addManualDevice(
      name: suggestedName,
      deviceType: type,
      identifier: result.ip,
    );

    showControllerMessageIfNeeded(successMessage: DevicesStrings.addDeviceSucesful);
  }

  String inferTypeFromModel(String model) {
    final raw = model.toLowerCase();
    if (raw.contains('bulb') ||
        raw.contains('duo') ||
        raw.contains('rgbw') ||
        raw.contains('light')) {
      return 'light';
    }
    return 'plug';
  }

  Future<void> scanNetwork() async {
    await controller.discoverDevicesInLan();

    if (!mounted) return;

    if (controller.scannedDevices.isNotEmpty) {
      await showDiscoveredDevicesDialog(controller.scannedDevices);
    } else {
      showControllerMessageIfNeeded();
    }
  }

  Future<void> showDiscoveredDevicesDialog(
      List<DiscoveredIotDevice> devices,
      ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(DevicesStrings.foundDevices),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: devices.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final device = devices[index];

                return ListTile(
                  leading: Icon(
                    device.type == 'light'
                        ? Icons.lightbulb_outline_rounded
                        : Icons.power_rounded,
                  ),
                  title: Text(device.name),
                  subtitle: Text(device.ip),
                  trailing: TextButton(
                    onPressed: () async {
                      final navigator = Navigator.of(dialogContext);
                      final messenger = ScaffoldMessenger.of(context);

                      await controller.addDiscoveredDevice(
                        name: device.name,
                        deviceType: device.type,
                        host: device.ip,
                      );

                      if (!mounted) return;

                      if (controller.errorMessage == null) {
                        navigator.pop();
                        messenger.showSnackBar(
                          const SnackBar(content: Text(DevicesStrings.addDeviceSucesful)),
                        );
                      } else {
                        messenger.showSnackBar(SnackBar(content: Text(controller.errorMessage!)));
                      }
                    },
                    child: const Text(AppStrings.add),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(AppStrings.exit),
            ),
          ],
        );
      },
    );
  }

  void showControllerMessageIfNeeded({String? successMessage}) {
    if (!mounted) return;

    if (controller.errorMessage != null && controller.errorMessage!.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(controller.errorMessage!)),
      );
      return;
    }

    if (successMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: controller.loading ? null : openAddOptions,
        icon: const Icon(Icons.add_rounded),
        label: const Text(AppStrings.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildBody() {
    if (controller.loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (controller.errorMessage != null && controller.devices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            controller.errorMessage!,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (controller.devices.isEmpty) {
      return const Center(
        child: Text(DevicesStrings.notDevicesAdd),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: controller.devices.length,
        itemBuilder: (_, index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DeviceCard(
            device: controller.devices[index],
            onTap: () async {
              final updated = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => DevicePanelPage(
                    device: controller.devices[index],
                  ),
                ),
              );

              if (!mounted) return;

              if (updated == true) {
                await controller.load();
              }
            },
            onToggle: (value) async {
              await controller.toggleDevice(
                controller.devices[index],
                value,
              );
              showControllerMessageIfNeeded();
            },
          ),
        ),
      ),
    );
  }
}