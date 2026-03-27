import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:iot_manager/core/constants/app_strings.dart';
import 'package:iot_manager/core/constants/devices_panel_strings.dart';
import 'package:iot_manager/core/constants/devices_strings.dart';
import 'package:iot_manager/core/error/error_mapper.dart';

import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';
import 'package:iot_manager/features/devices/presentation/controllers/device_settings_controller.dart';

enum _SettingsPanel {
  nightMode,
  location,
  rename,
  firmware,
  actions,
}

class DeviceSettingsSection extends StatefulWidget {
  const DeviceSettingsSection({
    super.key,
    required this.deviceId,
    required this.deviceName,
    required this.host,
    required this.remoteDatasource,
    this.onNameChanged,
    this.onDeviceRemoved,
    this.onUpdateStarted,
  });

  final String deviceId;
  final String deviceName;
  final String host;
  final DevicesRemoteDatasource remoteDatasource;
  final ValueChanged<String>? onNameChanged;
  final VoidCallback? onDeviceRemoved;
  final VoidCallback? onUpdateStarted;

  @override
  State<DeviceSettingsSection> createState() => _DeviceSettingsSectionState();
}

class _DeviceSettingsSectionState extends State<DeviceSettingsSection> {
  late final DeviceSettingsController _controller;
  late final TextEditingController _nameController;

  _SettingsPanel? _expandedPanel;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.deviceName);
    _controller = DeviceSettingsController(
      deviceId: widget.deviceId,
      host: widget.host,
      remoteDatasource: widget.remoteDatasource,
    )..addListener(_onControllerChanged);

    _controller.load();
  }

  @override
  void didUpdateWidget(covariant DeviceSettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.deviceName != widget.deviceName &&
        !_controller.savingName &&
        _nameController.text != widget.deviceName) {
      _nameController.text = widget.deviceName;
      _nameController.selection = TextSelection.fromPosition(
        TextPosition(offset: _nameController.text.length),
      );
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _togglePanel(_SettingsPanel panel) {
    setState(() {
      _expandedPanel = _expandedPanel == panel ? null : panel;
    });

    if (_expandedPanel == _SettingsPanel.firmware) {
      _controller.checkUpdate().catchError((_) {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String _messageFromError(Object error) {
    return ErrorMapper.mapFailure(error).message;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required bool danger,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(AppStrings.cancel),
            ),
            FilledButton(
              style: danger
                  ? FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              )
                  : null,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickTime({required bool isStart}) async {
    final rawValue = isStart ? _controller.nightStart : _controller.nightEnd;
    final parts = rawValue.split(':');

    final initialTime = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 0,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null) return;

    final value = DeviceSettingsController.formatTimeOfDay(picked);

    if (isStart) {
      _controller.setNightStart(value);
    } else {
      _controller.setNightEnd(value);
    }

    try {
      await _controller.saveNightMode();
    } catch (error) {
      _showSnack(_messageFromError(error));
    }
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      _showSnack(DevicesStrings.notDeviceName);
      return;
    }

    try {
      await _controller.saveName(name);
      widget.onNameChanged?.call(name);
      _showSnack(DevicesPanelStrings.sucessfulUpdateName);
    } catch (error) {
      _showSnack(_messageFromError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (_controller.loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Text(
          DevicesPanelStrings.settingsDevice,
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 18),
        _SettingsCard(
          title: DevicesPanelStrings.nightMode,
          icon: Icons.dark_mode_outlined,
          isExpanded: _expandedPanel == _SettingsPanel.nightMode,
          onTap: () => _togglePanel(_SettingsPanel.nightMode),
          child: _buildNightModeCard(),
        ),
        const SizedBox(height: 12),
        _SettingsCard(
          title: DevicesPanelStrings.geolocationTimeZone,
          icon: Icons.public_outlined,
          isExpanded: _expandedPanel == _SettingsPanel.location,
          onTap: () => _togglePanel(_SettingsPanel.location),
          child: _buildLocationCard(),
        ),
        const SizedBox(height: 12),
        _SettingsCard(
          title: DevicesPanelStrings.changeName,
          icon: Icons.drive_file_rename_outline,
          isExpanded: _expandedPanel == _SettingsPanel.rename,
          onTap: () => _togglePanel(_SettingsPanel.rename),
          child: _buildRenameCard(),
        ),
        const SizedBox(height: 12),
        _SettingsCard(
          title: DevicesPanelStrings.updateFirmware,
          icon: Icons.system_update_alt_outlined,
          isExpanded: _expandedPanel == _SettingsPanel.firmware,
          onTap: () => _togglePanel(_SettingsPanel.firmware),
          child: _buildUpdateCard(),
        ),
        const SizedBox(height: 12),
        _SettingsCard(
          title: DevicesPanelStrings.actionsSystem,
          icon: Icons.settings_backup_restore_outlined,
          isExpanded: _expandedPanel == _SettingsPanel.actions,
          onTap: () => _togglePanel(_SettingsPanel.actions),
          child: _buildActionsCard(),
        ),
      ],
    );
  }

  Widget _buildNightModeCard() {
    final colorScheme = Theme.of(context).colorScheme;

    if (!_controller.nightModeSupported) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          DevicesPanelStrings.exposesConfiguration,
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text(DevicesPanelStrings.activateNightMode),
          subtitle: const Text(DevicesPanelStrings.reducesAutomaticallyLight),
          value: _controller.nightModeEnabled,
          onChanged: _controller.savingNightMode
              ? null
              : (value) async {
            final previous = _controller.nightModeEnabled;
            _controller.setNightModeEnabled(value);

            try {
              await _controller.saveNightMode();
            } catch (error) {
              _controller.setNightModeEnabled(previous);
              _showSnack(_messageFromError(error));
            }
          },
        ),
        const SizedBox(height: 8),
        Text(
          '${DevicesPanelStrings.nightGlow}: ${_controller.nightBrightness.round()}%',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Slider(
          value: _controller.nightBrightness,
          min: 1,
          max: 100,
          divisions: 99,
          label: '${_controller.nightBrightness.round()}%',
          onChanged: (value) {
            _controller.setNightBrightness(value);
          },
          onChangeEnd: _controller.savingNightMode
              ? null
              : (_) async {
            try {
              await _controller.saveNightMode();
            } catch (error) {
              _showSnack(_messageFromError(error));
            }
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _TimeSelectorCard(
                label: 'Desde',
                value: _controller.nightStart,
                onTap: _controller.savingNightMode
                    ? null
                    : () => _pickTime(isStart: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TimeSelectorCard(
                label: 'Hasta',
                value: _controller.nightEnd,
                onTap: _controller.savingNightMode
                    ? null
                    : () => _pickTime(isStart: false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(
          label: DevicesPanelStrings.timeZone,
          value: _controller.timezone ?? AppStrings.notAvaliable,
        ),
        const SizedBox(height: 10),
        _InfoRow(
          label: DevicesPanelStrings.latitude,
          value: _controller.lat?.toStringAsFixed(6) ?? AppStrings.notAvaliable,
        ),
        const SizedBox(height: 10),
        _InfoRow(
          label: DevicesPanelStrings.longitude,
          value: _controller.lon?.toStringAsFixed(6) ?? AppStrings.notAvaliable,
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _controller.loadingLocation
                ? null
                : () async {
              try {
                await _controller.detectLocation();
                _showSnack(DevicesPanelStrings.updatedLocation);
              } catch (error) {
                _showSnack(_messageFromError(error));
              }
            },
            icon: _controller.loadingLocation
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.gps_fixed),
            label: const Text(DevicesPanelStrings.detectAutomatically),
          ),
        ),
      ],
    );
  }

  Widget _buildRenameCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(DevicesStrings.deviceName,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _nameController,
          textInputAction: TextInputAction.done,
          maxLength: 18,
          inputFormatters: [
            LengthLimitingTextInputFormatter(18),
          ],
          decoration: InputDecoration(
            hintText: DevicesPanelStrings.newName,
            counterText: '',
            filled: true,
            fillColor: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.45),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 1.4,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          onSubmitted: (_) async {
            FocusScope.of(context).unfocus();
            await _saveName();
          },
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _controller.savingName
                ? null
                : () async {
              FocusScope.of(context).unfocus();
              await _saveName();
            },
            icon: _controller.savingName
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.save_outlined),
            label: const Text(AppStrings.saveName),
          ),
        ),
      ],
    );
  }

  Widget _buildUpdateCard() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha:0.45),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _controller.updateMessage ?? DevicesPanelStrings.noUpdateInformation,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (_controller.availableVersion != null) ...[
                const SizedBox(height: 6),
                Text('${DevicesPanelStrings.versionAvaliable}: ${_controller.availableVersion}'),
              ],
              if (_controller.availableBuildId != null) ...[
                const SizedBox(height: 4),
                Text('Build: ${_controller.availableBuildId}'),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _controller.checkingUpdate
                    ? null
                    : () async {
                  try {
                    await _controller.checkUpdate();
                  } catch (error) {
                    _showSnack(_messageFromError(error));
                  }
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                icon: _controller.checkingUpdate
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.search, size: 18),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(AppStrings.check,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _controller.updatingFirmware
                    ? null
                    : () async {
                  if (_controller.availableVersion == null) {
                    _showSnack(DevicesPanelStrings.notAvaliableUpdateStable);
                    return;
                  }

                  final confirmed = await _showConfirmDialog(
                    title: DevicesPanelStrings.updateFirmware,
                    message:
                    'Se instalará la versión ${_controller.availableVersion}. El dispositivo puede reiniciarse durante el proceso.',
                    confirmText: AppStrings.update,
                    danger: false,
                  );

                  if (confirmed != true) return;

                  try {
                    await _controller.runUpdate();
                    _showSnack(DevicesPanelStrings.updateIniciated);
                    widget.onUpdateStarted?.call();
                  } catch (error) {
                    _showSnack(_messageFromError(error));
                  }
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                icon: _controller.updatingFirmware
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.system_update_alt, size: 18),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    AppStrings.update,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionsCard() {
    final colorScheme = Theme.of(context).colorScheme;

    final ButtonStyle uniformOutlinedStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(double.infinity, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
    );

    final ButtonStyle uniformDangerStyle = FilledButton.styleFrom(
      minimumSize: const Size(double.infinity, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
      backgroundColor: colorScheme.error,
      foregroundColor: colorScheme.onError,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: uniformOutlinedStyle,
            onPressed: _controller.rebooting
                ? null
                : () async {
              final confirmed = await _showConfirmDialog(
                title: AppStrings.rebootDevice,
                message: DevicesPanelStrings.fewSecondsReboot,
                confirmText: AppStrings.reboot,
                danger: false,
              );

              if (confirmed != true) return;

              try {
                await _controller.rebootDevice();
                _showSnack(AppStrings.rebootSuccessful);
              } catch (error) {
                _showSnack(_messageFromError(error));
              }
            },
            icon: _controller.rebooting
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.restart_alt, size: 18),
            label: const Text(AppStrings.rebootDevice,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_controller.canManageDevice) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: uniformOutlinedStyle,
              onPressed: _controller.unlinking
                  ? null
                  : () async {
                final confirmed = await _showConfirmDialog(
                  title: AppStrings.unLinkDevice,
                  message: AppStrings.unLinkDeviceMessage,
                  confirmText: AppStrings.unLink,
                  danger: false,
                );

                if (confirmed != true) return;

                try {
                  await _controller.unlinkDevice();
                  _showSnack(AppStrings.unLinkDeviceSucessful);
                  widget.onDeviceRemoved?.call();
                } catch (error) {
                  _showSnack(_messageFromError(error));
                }
              },
              icon: _controller.unlinking
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.link_off_rounded, size: 18),
              label: const Text(
                AppStrings.unLinkDevice,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_controller.canFactoryReset)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: uniformDangerStyle,
              onPressed: _controller.factoryResetting
                  ? null
                  : () async {
                final confirmed = await _showConfirmDialog(
                  title: DevicesPanelStrings.factoryReset,
                  message: DevicesPanelStrings.factoryResetMessage,
                  confirmText: AppStrings.factory,
                  danger: true,
                );

                if (confirmed != true) return;

                try {
                  await _controller.factoryReset();
                  _showSnack(DevicesPanelStrings.factoryResetSuccessful);
                  widget.onDeviceRemoved?.call();
                } catch (error) {
                  _showSnack(_messageFromError(error));
                }
              },
              icon: _controller.factoryResetting
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.warning_amber_rounded, size: 18),
              label: const Text(DevicesPanelStrings.factoryReset,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline),
                SizedBox(width: 10),
                Expanded(
                  child: Text(DevicesPanelStrings.notAvaliableFactoryReset),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.icon,
    required this.child,
    required this.isExpanded,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: colorScheme.surface,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha:0.8),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: [
              InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha:0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: colorScheme.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: child,
                ),
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 180),
                sizeCurve: Curves.easeInOut,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeSelectorCard extends StatelessWidget {
  const _TimeSelectorCard({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outlineVariant),
          color: colorScheme.surfaceContainerHighest.withValues(alpha:0.3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(value)),
      ],
    );
  }
}