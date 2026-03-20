import 'package:flutter/material.dart';
import 'package:iot_manager/core/constants/devices_panel_strings.dart';
import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';
import 'package:iot_manager/features/devices/domain/entities/device_item.dart';
import 'package:iot_manager/features/devices/presentation/controllers/device_panel_controller.dart';
import 'package:iot_manager/features/devices/presentation/widgets/sections/device_incidents_section.dart';
import 'package:iot_manager/features/devices/presentation/widgets/sections/device_info_section.dart';
import 'package:iot_manager/features/devices/presentation/widgets/sections/device_power_panel.dart';
import 'package:iot_manager/features/devices/presentation/widgets/sections/device_safety_section.dart';
import 'package:iot_manager/features/devices/presentation/widgets/sections/device_settings_section.dart';
import 'package:iot_manager/features/devices/presentation/widgets/sections/device_timer_section.dart';
import 'package:iot_manager/features/devices/presentation/widgets/shared/device_detail_sidebar.dart';
import 'package:iot_manager/features/devices/presentation/widgets/shared/device_metric_card.dart';
import 'package:iot_manager/features/devices/presentation/widgets/shared/device_panel_styles.dart';
import 'package:iot_manager/features/devices/presentation/widgets/shared/device_panel_top_bar.dart';
import 'package:iot_manager/features/devices/presentation/widgets/shared/device_placeholder_section.dart';
import 'package:iot_manager/features/devices/presentation/widgets/sections/device_light_section.dart';

enum DevicePanelSection {
  overview,
  charts,
  incidents,
  info,
  light,
  safety,
  schedules,
  settings,
  share,
  timer,
}

class DevicePanelPage extends StatefulWidget {
  const DevicePanelPage({
    super.key,
    required this.device,
  });

  final DeviceItem device;

  @override
  State<DevicePanelPage> createState() => DevicePanelPageState();
}

class DevicePanelPageState extends State<DevicePanelPage> {
  late final DevicePanelController controller;
  late final DevicesRemoteDatasource remoteDatasource;
  late String currentDeviceName;

  DevicePanelSection selectedSection = DevicePanelSection.overview;

  @override
  void initState() {
    super.initState();
    currentDeviceName = widget.device.name;
    remoteDatasource = DevicesRemoteDatasource();
    controller = DevicePanelController(
      device: widget.device,
      remoteDatasource: remoteDatasource,
    );
    controller.addListener(onControllerChanged);
    controller.initialize();
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: DevicePanelTopBar(
                deviceName: currentDeviceName.length > 18
                    ? '${currentDeviceName.substring(0, 18)}…'
                    : currentDeviceName,
                deviceIdentifier: widget.device.identifier,
                isLoading: controller.loading,
                onBack: () => Navigator.of(context).pop(),
                onRefresh: controller.loading ? null : controller.refresh,
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 10, 12),
                    child: DeviceDetailSidebar(
                      selectedSection: selectedSection,
                      onSectionSelected: (section) {
                        setState(() {
                          selectedSection = section;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Padding(
                        key: ValueKey(selectedSection),
                        padding: const EdgeInsets.fromLTRB(0, 0, 12, 12),
                        child: buildSection(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSection(BuildContext context) {
    if (selectedSection == DevicePanelSection.overview) {
      return buildOverview(context);
    }

    if (selectedSection == DevicePanelSection.info) {
      return DeviceInfoSection(
        host: controller.deviceHost,
        ipAddress: controller.deviceIp,
        macAddress: controller.macAddress,
        firmwareVersion: controller.firmwareVersion,
        model: controller.deviceModel,
        deviceType: widget.device.deviceType,
        hasPendingUpdate: controller.hasPendingUpdate,
        needsReboot: controller.needsReboot,
        errorMessage: controller.errorMessage,
        ssid: controller.ssid,
        rssi: controller.rssi,
        signalQuality: controller.signalQuality,
        uptimeLabel: controller.uptimeLabel,
      );
    }

    if (selectedSection == DevicePanelSection.safety) {
      return DeviceSafetySection(
        host: widget.device.identifier,
      );
    }

    if (selectedSection == DevicePanelSection.light) {
      return DeviceLightSection(
        host: widget.device.identifier,
      );
    }

    if (selectedSection == DevicePanelSection.timer) {
      return DeviceTimerSection(
        deviceId: widget.device.id,
        remoteDatasource: remoteDatasource,
        onExecute: (on) async {
          if (controller.isOn != on) {
            await controller.togglePower();
          }
        },
      );
    }

    if (selectedSection == DevicePanelSection.incidents) {
      return DeviceIncidentsSection(
        deviceId: widget.device.id,
        remoteDatasource: remoteDatasource,
      );
    }

    if (selectedSection == DevicePanelSection.settings) {
      return DeviceSettingsSection(
        deviceId: widget.device.id,
        deviceName: currentDeviceName,
        host: widget.device.identifier,
        remoteDatasource: remoteDatasource,
        onNameChanged: (newName) {
          setState(() {
            currentDeviceName = newName;
          });
        },
        onUpdateStarted: () {
          if (!mounted) return;
          Navigator.of(context).pop(true);
        },
        onDeviceRemoved: () {
          if (!mounted) return;
          Navigator.of(context).pop(true);
        },
      );
    }

    return DevicePlaceholderSection(section: selectedSection);
  }

  Widget buildOverview(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          DevicePowerPanel(
            isOn: controller.isOn,
            deviceType: widget.device.deviceType,
            busyPowerAction: controller.busyPowerAction,
            errorMessage: controller.errorMessage,
            onTogglePower: controller.togglePower,
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.22,
            children: [
              DeviceMetricCard(
                title: DevicesPanelStrings.voltage,
                value: formatNumber(controller.voltageV),
                unit: 'V',
                icon: Icons.electric_bolt_rounded,
              ),
              DeviceMetricCard(
                title: DevicesPanelStrings.currentConsumption,
                value: formatNumber(controller.powerW),
                unit: 'W',
                icon: Icons.flash_on_rounded,
                accentOverride: consumptionAccent(controller.powerW),
                gradientOverride: consumptionGradient(controller.powerW),
              ),
              DeviceMetricCard(
                title: DevicesPanelStrings.current,
                value: formatNumber(controller.currentA),
                unit: 'A',
                icon: Icons.tune_rounded,
              ),
              DeviceMetricCard(
                title: DevicesPanelStrings.temperature,
                value: formatNumber(controller.temperatureC),
                unit: '°C',
                icon: Icons.thermostat_rounded,
              ),
              DeviceMetricCard(
                title: DevicesPanelStrings.energyToday,
                value: formatNumber(controller.energyTodayWh),
                unit: 'Wh',
                icon: Icons.bar_chart_rounded,
              ),
              DeviceMetricCard(
                title: DevicesPanelStrings.hz,
                value: formatNumber(controller.frequencyHz),
                unit: 'Hz',
                icon: Icons.graphic_eq_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}