import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/devices_strings.dart';
import '../../../../core/iot/models/discovered_iot_device.dart';
import '../controllers/devices_controller.dart';
import '../widgets/device_card.dart';
import 'shelly_ble_provision_page.dart';

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  late final DevicesController controller;

  @override
  void initState() {
    super.initState();
    controller = DevicesController.create();
    controller.addListener(_onControllerChanged);
    controller.load();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    controller.dispose();
    super.dispose();
  }

  Future<void> _openAddOptions() async {
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
                    await _openBleProvisionFlow();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.wifi_find_rounded),
                  title: const Text(DevicesStrings.scanningLan),
                  subtitle: const Text(DevicesStrings.scanningLanSubtitle,),
                  onTap: () async {
                    Navigator.of(bottomSheetContext).pop();
                    await _scanNetwork();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.add_circle_outline_rounded),
                  title: const Text(DevicesStrings.configurationManual),
                  subtitle: const Text(DevicesStrings.configurationManualSubtitle,),
                  onTap: () async {
                    Navigator.of(bottomSheetContext).pop();
                    await _showManualAddDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openBleProvisionFlow() async {
    final result = await Navigator.of(context).push<ShellyBleProvisionResult>(
      MaterialPageRoute(
        builder: (_) => const ShellyBleProvisionPage(),
      ),
    );

    if (!mounted || result == null) return;

    final model = (result.deviceInfo['model'] ?? '').toString().trim();
    final suggestedName = model.isNotEmpty ? model : 'Shelly';
    final type = _inferTypeFromModel(model);

    await controller.addManualDevice(
      name: suggestedName,
      deviceType: type,
      identifier: result.ip,
    );

    _showControllerMessageIfNeeded(successMessage: DevicesStrings.addDeviceSucesful,);
  }

  String _inferTypeFromModel(String model) {
    final raw = model.toLowerCase();
    if (raw.contains('bulb') ||
        raw.contains('duo') ||
        raw.contains('rgbw') ||
        raw.contains('light')) {
      return 'light';
    }
    return 'plug';
  }

  Future<void> _showManualAddDialog() async {
    final nameController = TextEditingController();
    final identifierController = TextEditingController();
    String selectedType = 'plug';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> save() async {
              final name = nameController.text.trim();
              final identifier = identifierController.text.trim();

              if (name.isEmpty || identifier.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text(DevicesStrings.completeConfiguration),
                  ),
                );
                return;
              }

              setLocalState(() => saving = true);

              await controller.addManualDevice(
                name: name,
                deviceType: selectedType,
                identifier: identifier,
              );

              if (!mounted) return;

              setLocalState(() => saving = false);

              if (controller.errorMessage == null) {
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text(DevicesStrings.addDeviceSucesful),
                  ),
                );
              } else {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text(controller.errorMessage!)),
                );
              }
            }

            return AlertDialog(
              title: const Text(DevicesStrings.addDevice),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: AppStrings.name,
                        hintText: DevicesStrings.ejTipesDevices,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: DevicesStrings.tipesDevices,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'plug',
                          child: Text(DevicesStrings.plug),
                        ),
                        DropdownMenuItem(
                          value: 'light',
                          child: Text(DevicesStrings.light),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setLocalState(() => selectedType = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: identifierController,
                      decoration: const InputDecoration(
                        labelText: AppStrings.IPHOST,
                        hintText: DevicesStrings.ejIP,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text(AppStrings.cancel),
                ),
                FilledButton(
                  onPressed: saving ? null : save,
                  child: saving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text(AppStrings.save),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    identifierController.dispose();
  }

  Future<void> _scanNetwork() async {
    await controller.discoverDevicesInLan();

    if (!mounted) return;

    if (controller.scannedDevices.isNotEmpty) {
      await _showDiscoveredDevicesDialog(controller.scannedDevices);
    } else {
      _showControllerMessageIfNeeded();
    }
  }

  Future<void> _showDiscoveredDevicesDialog(
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
                      await controller.addDiscoveredDevice(
                        name: device.name,
                        deviceType: device.type,
                        host: device.ip,
                      );

                      if (!mounted) return;

                      if (controller.errorMessage == null) {
                        Navigator.of(dialogContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(DevicesStrings.addDeviceSucesful),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(controller.errorMessage!)),
                        );
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

  void _showControllerMessageIfNeeded({String? successMessage}) {
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
        onPressed: controller.loading ? null : _openAddOptions,
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
            onToggle: (value) async {
              await controller.toggleDevice(
                controller.devices[index],
                value,
              );
              _showControllerMessageIfNeeded();
            },
          ),
        ),
      ),
    );
  }
}