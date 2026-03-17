import 'package:flutter/material.dart';

import 'package:iot_manager/core/constants/app_strings.dart';
import 'package:iot_manager/core/constants/devices_panel_strings.dart';
import 'package:iot_manager/core/constants/devices_strings.dart';

class DeviceInfoSection extends StatelessWidget {
  const DeviceInfoSection({
    super.key,
    required this.host,
    required this.ipAddress,
    required this.macAddress,
    required this.firmwareVersion,
    required this.model,
    required this.deviceType,
    required this.hasPendingUpdate,
    required this.needsReboot,
    required this.errorMessage,
    required this.ssid,
    required this.rssi,
    required this.signalQuality,
    required this.uptimeLabel,
  });

  final String host;
  final String ipAddress;
  final String macAddress;
  final String firmwareVersion;
  final String model;
  final String deviceType;
  final bool hasPendingUpdate;
  final bool needsReboot;
  final String? errorMessage;
  final String ssid;
  final int rssi;
  final String signalQuality;
  final String uptimeLabel;

  static const Color accentBlue = Color(0xFF3D6EA8);
  static const Color borderBlue = Color(0xFFD7E1F0);

  String get effectiveIp {
    final ip = ipAddress.trim();
    if (ip.isNotEmpty && ip != '-') return ip;

    final fallbackHost = host.trim();
    if (fallbackHost.isNotEmpty && fallbackHost != '-') return fallbackHost;

    return '-';
  }

  String get systemStatus {
    if (needsReboot) return DevicesPanelStrings.nedAttention;
    return DevicesPanelStrings.operative;
  }

  String get systemStatusDetail {
    if (needsReboot) return AppStrings.recomendedReboot;
    if (hasPendingUpdate) return DevicesPanelStrings.updateAvailable;
    return DevicesPanelStrings.normalOperation;
  }

  String get connectionStatus {
    if (effectiveIp == '-' || ssid == DevicesPanelStrings.notData) {
      return AppStrings.offline;
    }
    return AppStrings.connected;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        TopMiniCards(
          effectiveIp: effectiveIp,
          uptimeLabel: uptimeLabel,
          systemStatus: systemStatus,
          systemStatusDetail: systemStatusDetail,
          firmwareVersion: firmwareVersion,
          hasPendingUpdate: hasPendingUpdate,
        ),
        const SizedBox(height: 16),
        LargeInfoCard(
          title: DevicesPanelStrings.generalState,
          icon: Icons.memory_rounded,
          iconAccent: accentBlue,
          borderColor: borderBlue,
          rows: [
            InfoRowData(label: DevicesPanelStrings.macAddress, value: safeValue(macAddress)),
            InfoRowData(label: DevicesPanelStrings.model, value: safeValue(model)),
            InfoRowData(
              label: DevicesStrings.tipesDevices,
              value: safeValue(deviceType),
            ),
            InfoRowData(
              label: AppStrings.necesaryReboot,
              value: needsReboot ? AppStrings.yes : AppStrings.no,
            ),
            InfoRowData(
              label: DevicesPanelStrings.pedingUpdate,
              value: hasPendingUpdate ? AppStrings.yes : AppStrings.no,
            ),
          ],
        ),
        const SizedBox(height: 14),
        WifiInfoCard(
          ssid: safeValue(ssid),
          assignedIp: effectiveIp,
          status: connectionStatus,
          rssi: rssi,
          signalQuality: signalQuality,
        ),
        const SizedBox(height: 14),
        LargeInfoCard(
          title: DevicesPanelStrings.firmwareSystem,
          icon: Icons.system_update_alt_rounded,
          iconAccent: accentBlue,
          borderColor: borderBlue,
          rows: [
            InfoRowData(
              label: DevicesPanelStrings.firmwareVersion,
              value: safeValue(firmwareVersion),
            ),
            InfoRowData(label: DevicesPanelStrings.systemState, value: systemStatus),
            InfoRowData(label: DevicesPanelStrings.details, value: systemStatusDetail),
            InfoRowData(
              label: DevicesPanelStrings.recomendatedAction,
              value: needsReboot
                  ? AppStrings.reboot
                  : hasPendingUpdate
                  ? DevicesPanelStrings.checkUpdate
                  : AppStrings.none,
            ),
          ],
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    errorMessage!,
                    style: TextStyle(
                      color: colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static String safeValue(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '-';
    return trimmed;
  }
}

class TopMiniCards extends StatelessWidget {
  const TopMiniCards({super.key,
    required this.effectiveIp,
    required this.uptimeLabel,
    required this.systemStatus,
    required this.systemStatusDetail,
    required this.firmwareVersion,
    required this.hasPendingUpdate,
  });

  final String effectiveIp;
  final String uptimeLabel;
  final String systemStatus;
  final String systemStatusDetail;
  final String firmwareVersion;
  final bool hasPendingUpdate;

  static const Color accentBlue = Color(0xFF3D6EA8);
  static const Color borderBlue = Color(0xFFD7E1F0);
  static const Color bgBlue = Color(0xFFF3F7FF);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: MiniInfoCard(
                icon: Icons.lan_rounded,
                title: DevicesPanelStrings.localIP,
                value: valueOrDash(effectiveIp),
                accent: accentBlue,
                borderColor: borderBlue,
                backgroundColor: bgBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MiniInfoCard(
                icon: Icons.schedule_rounded,
                title: DevicesPanelStrings.timeActivate,
                value: valueOrDash(uptimeLabel),
                accent: accentBlue,
                borderColor: borderBlue,
                backgroundColor: bgBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MiniInfoCard(
                icon: Icons.monitor_heart_rounded,
                title: DevicesPanelStrings.systemState,
                value: systemStatus,
                subtitle: systemStatusDetail,
                accent: accentBlue,
                borderColor: borderBlue,
                backgroundColor: bgBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MiniInfoCard(
                icon: hasPendingUpdate
                    ? Icons.system_update_alt_rounded
                    : Icons.verified_rounded,
                title: DevicesPanelStrings.firmware,
                value: valueOrDash(firmwareVersion),
                subtitle: hasPendingUpdate
                    ? DevicesPanelStrings.updateAvailable
                    : DevicesPanelStrings.notUpdateAvailable,
                accent: accentBlue,
                borderColor: borderBlue,
                backgroundColor: bgBlue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String valueOrDash(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '-';
    return trimmed;
  }
}

class MiniInfoCard extends StatelessWidget {
  const MiniInfoCard({super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.accent,
    required this.borderColor,
    required this.backgroundColor,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;
  final Color accent;
  final Color borderColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 156,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(colors: [Colors.white, backgroundColor]),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: icon, accent: accent),
          const Spacer(),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              height: 1.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: accent,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class LargeInfoCard extends StatelessWidget {
  const LargeInfoCard({super.key,
    required this.title,
    required this.icon,
    required this.iconAccent,
    required this.borderColor,
    required this.rows,
  });

  final String title;
  final IconData icon;
  final Color iconAccent;
  final Color borderColor;
  final List<InfoRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white,
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconBadge(icon: icon, accent: iconAccent),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...buildRows(),
        ],
      ),
    );
  }

  List<Widget> buildRows() {
    final widgets = <Widget>[];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];

      widgets.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Text(
                row.label,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF4B5563),
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 7,
              child: Text(
                row.value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      );

      if (i != rows.length - 1) {
        widgets.add(const SizedBox(height: 8));
        widgets.add(const Divider(height: 1, color: Color(0xFFDCE4F0)));
        widgets.add(const SizedBox(height: 8));
      }
    }
    return widgets;
  }
}

class WifiInfoCard extends StatelessWidget {
  const WifiInfoCard({super.key,
    required this.ssid,
    required this.assignedIp,
    required this.status,
    required this.rssi,
    required this.signalQuality,
  });

  final String ssid;
  final String assignedIp;
  final String status;
  final int rssi;
  final String signalQuality;

  static const Color accentBlue = Color(0xFF3D6EA8);
  static const Color borderBlue = Color(0xFFD7E1F0);

  String get signalLabel {
    if (rssi == 0) return DevicesPanelStrings.notData;
    return '$rssi dBm · $signalQuality';
  }

  Color get signalColor {
    if (rssi == 0) return const Color(0xFF4B5563);
    return accentBlue;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white,
        border: Border.all(color: borderBlue),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              IconBadge(icon: Icons.wifi_rounded, accent: accentBlue),
              SizedBox(width: 12),
              Text(DevicesPanelStrings.wifiAddress,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          WifiRow(
            label: DevicesStrings.ssid,
            value: ssid == '-' ? DevicesPanelStrings.notData : ssid,
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFDCE4F0)),
          const SizedBox(height: 8),
          WifiRow(label: DevicesPanelStrings.asignedIP, value: assignedIp),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFDCE4F0)),
          const SizedBox(height: 8),
          WifiRow(label: DevicesPanelStrings.estate, value: status),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFDCE4F0)),
          const SizedBox(height: 8),
          WifiRow(
            label: DevicesPanelStrings.signalQuality,
            value: signalLabel,
            valueColor: signalColor,
          ),
        ],
      ),
    );
  }
}

class WifiRow extends StatelessWidget {
  const WifiRow({super.key,
    required this.label,
    required this.value,
    this.valueColor = const Color(0xFF1F2937),
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF4B5563),
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              color: valueColor,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class IconBadge extends StatelessWidget {
  const IconBadge({super.key,
    required this.icon,
    required this.accent,
  });

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: accent, size: 20),
    );
  }
}

class InfoRowData {
  const InfoRowData({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}