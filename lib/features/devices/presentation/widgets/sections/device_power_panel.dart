import 'package:flutter/material.dart';
import 'package:iot_manager/core/constants/devices_panel_strings.dart';
import 'package:iot_manager/core/constants/devices_strings.dart';

import 'package:iot_manager/features/devices/presentation/widgets/shared/device_panel_styles.dart';
import 'package:iot_manager/features/devices/presentation/widgets/shared/device_status_pill.dart';

class DevicePowerPanel extends StatelessWidget {
  const DevicePowerPanel({
    super.key,
    required this.isOn,
    required this.deviceType,
    required this.busyPowerAction,
    required this.errorMessage,
    required this.onTogglePower,
  });

  final bool isOn;
  final String deviceType;
  final bool busyPowerAction;
  final String? errorMessage;
  final Future<void> Function() onTogglePower;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            powerPanelBackground(isOn).withValues(alpha: 0.95),
            Colors.white.withValues(alpha: 0.92),
          ],
        ),
        border: Border.all(color: powerPanelAccent(isOn).withValues(alpha: 0.22),),
        boxShadow: [
          BoxShadow(
            color: powerPanelAccent(isOn).withValues(alpha: isOn ? 0.14 : 0.06),
            blurRadius: isOn ? 18 : 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: powerButtonBackground(isOn).withValues(
                    alpha: isOn ? 0.28 : 0.12,
                  ),
                  blurRadius: isOn ? 18 : 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busyPowerAction ? null : onTogglePower,
                style: FilledButton.styleFrom(
                  backgroundColor: powerButtonBackground(isOn),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                  powerButtonBackground(isOn).withValues(alpha: 0.7),
                  minimumSize: const Size.fromHeight(58),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.96,
                          end: 1,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Row(
                    key: ValueKey('$isOn-$busyPowerAction'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isOn
                            ? Icons.power_settings_new_rounded
                            : Icons.power_off_rounded,
                        size: 20
                      ),
                      const SizedBox(width: 10),
                      Text(isOn ? DevicesPanelStrings.turnOff : DevicesPanelStrings.turnOn,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DeviceStatusPill(
                  label: DevicesPanelStrings.estate,
                  value: isOn ? DevicesStrings.on : DevicesStrings.off,
                  icon: isOn ? Icons.bolt_rounded : Icons.power_off_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DeviceStatusPill(
                  label: DevicesPanelStrings.tipeDevice,
                  value: deviceType,
                  icon: deviceType == 'light'
                      ? Icons.lightbulb_outline_rounded
                      : Icons.power_rounded,
                ),
              ),
            ],
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(errorMessage!,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
          ],
        ],
      ),
    );
  }
}