import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';
import 'package:iot_manager/features/devices/presentation/controllers/device_timer_controller.dart';

class DeviceTimerSection extends StatefulWidget {
  const DeviceTimerSection({
    super.key,
    required this.deviceId,
    required this.remoteDatasource,
    required this.onExecute,
  });

  final String deviceId;
  final DevicesRemoteDatasource remoteDatasource;
  final Future<void> Function(bool on) onExecute;

  @override
  State<DeviceTimerSection> createState() => DeviceTimerSectionState();
}

class DeviceTimerSectionState extends State<DeviceTimerSection> {
  late final DeviceTimerController controller;
  Timer? ticker;
  bool processingTimers = false;

  @override
  void initState() {
    super.initState();
    controller = DeviceTimerController(
      deviceId: widget.deviceId,
      remoteDatasource: widget.remoteDatasource,
    )..addListener(onControllerChanged);

    controller.load();

    ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;

      await processTimers();

      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> processTimers() async {
    if (processingTimers) return;

    processingTimers = true;
    try {
      await controller.processExpiredTimers(
        onExecute: (on) async {await widget.onExecute(on);},
      );
    } finally {
      processingTimers = false;
    }
  }

  void onControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    ticker?.cancel();
    controller.removeListener(onControllerChanged);
    controller.dispose();
    super.dispose();
  }

  void showSnack(String message, {bool isError = false}) {
    if (!mounted) return;

    final colorScheme = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? colorScheme.errorContainer : null,
      ),
    );
  }

  void showControllerError({
    String fallback = 'Ha ocurrido un error inesperado.',
  }) {
    showSnack(controller.error ?? fallback, isError: true);
  }

  Future<void> openCreateTimerDialog() async {
    int hours = 0;
    int minutes = 1;
    int seconds = 0;
    String selectedAction = 'off';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        final theme = Theme.of(dialogContext);

        return StatefulBuilder(
          builder: (context, setLocalState) {
            final totalSeconds = hours * 3600 + minutes * 60 + seconds;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text('Nuevo temporizador',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Define una cuenta atrás y la acción que se ejecutará cuando termine.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: buildNumberPickerField(
                            context,
                            label: 'Horas',
                            value: hours,
                            max: 23,
                            onChanged: (value) {
                              setLocalState(() {
                                hours = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: buildNumberPickerField(
                            context,
                            label: 'Min',
                            value: minutes,
                            max: 59,
                            onChanged: (value) {
                              setLocalState(() {
                                minutes = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: buildNumberPickerField(
                            context,
                            label: 'Seg',
                            value: seconds,
                            max: 59,
                            onChanged: (value) {
                              setLocalState(() {
                                seconds = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colorScheme.outlineVariant),
                        color: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.45),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text('Duración total',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(DeviceTimerController.formatDurationCompact(
                              totalSeconds,
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Acción al finalizar',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: buildActionChoice(
                            context,
                            icon: Icons.power_settings_new,
                            label: 'Encender',
                            selected: selectedAction == 'on',
                            onTap: () {
                              setLocalState(() {
                                selectedAction = 'on';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: buildActionChoice(
                            context,
                            icon: Icons.power_off_outlined,
                            label: 'Apagar',
                            selected: selectedAction == 'off',
                            onTap: () {
                              setLocalState(() {
                                selectedAction = 'off';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    if (totalSeconds <= 0) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('El temporizador debe ser mayor que 0.')),
                      );
                      return;
                    }

                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    try {
      await controller.create(
        hours: hours,
        minutes: minutes,
        seconds: seconds,
        action: selectedAction,
      );

      showSnack('Temporizador guardado correctamente.');
    } catch (_) {
      showControllerError(
        fallback: 'No se pudo guardar el temporizador.',
      );
    }
  }

  Widget buildActionChoice(
      BuildContext context, {
        required IconData icon,
        required String label,
        required bool selected,
        required VoidCallback onTap,
      }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.12)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildNumberPickerField(
      BuildContext context, {
        required String label,
        required int value,
        required int max,
        required ValueChanged<int> onChanged,
      }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(16),
          items: List.generate(
            max + 1,
                (index) => DropdownMenuItem<int>(
              value: index,
              child: Text('${index.toString().padLeft(2, '0')} $label'),
            ),
          ),
          onChanged: (newValue) {
            if (newValue != null) {
              onChanged(newValue);
            }
          },
        ),
      ),
    );
  }

  Widget sectionCard(
      BuildContext context, {
        required Widget child,
      }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: child,
    );
  }

  Widget buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return sectionCard(
      context,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.timer_outlined,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text('Aún no hay temporizadores',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text('Crea una cuenta atrás para encender o apagar el dispositivo automáticamente.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: controller.busy ? null : openCreateTimerDialog,
            icon: const Icon(Icons.add),
            label: const Text('Crear temporizador'),
          ),
        ],
      ),
    );
  }

  Widget buildTimerCard(BuildContext context, Map<String, dynamic> row) {
    final colorScheme = Theme.of(context).colorScheme;

    final id = (row['id'] ?? '').toString();
    final enabled = row['enabled'] == true;
    final config = (row['config'] is Map) ? Map<String, dynamic>.from(row['config'] as Map) : <String, dynamic>{};

    final durationSeconds = DeviceTimerController.intFrom(config['duration_seconds']) ?? 0;

    final action = (config['action']?.toString() ?? 'off').toLowerCase();
    final startedAt = DeviceTimerController.parseDateTime(config['started_at']);

    final remaining = DeviceTimerController.remainingDuration(
      durationSeconds: durationSeconds,
      startedAt: startedAt,
      enabled: enabled,
    );

    final displaySeconds = enabled ? remaining.inSeconds.clamp(0, 999999) : durationSeconds;

    final actionLabel = action == 'on' ? 'Encender' : 'Apagar';
    final actionColor = action == 'on' ? const Color(0xFF3D6EA8) : colorScheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.timer_outlined,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DeviceTimerController.formatDurationCompact(displaySeconds),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  actionLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: actionColor,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.88,
            child: Switch(
              value: enabled,
              onChanged: controller.busy
                  ? null
                  : (value) async {
                try {
                  await controller.toggle(row, value);
                } catch (_) {
                  showControllerError(
                    fallback: 'No se pudo actualizar el temporizador.',
                  );
                }
              },
            ),
          ),
          IconButton(
            tooltip: 'Eliminar',
            onPressed: controller.busy
                ? null
                : () async {
              try {
                await controller.delete(id);
                showSnack('Temporizador eliminado.');
              } catch (_) {
                showControllerError(
                  fallback: 'No se pudo eliminar el temporizador.',
                );
              }
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (controller.loading) {
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
        sectionCard(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.timer_outlined, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Temporizadores',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: controller.busy ? null : openCreateTimerDialog,
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(14),
                      backgroundColor:
                      colorScheme.primary.withValues(alpha: 0.14),
                      foregroundColor: colorScheme.primary,
                      elevation: 0,
                    ),
                    child: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Cuenta atrás para encender o apagar el dispositivo automáticamente.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (controller.error != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: 0.70),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    controller.error!,
                    style: TextStyle(
                      color: colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (controller.timers.isEmpty)
          buildEmptyState(context)
        else
          ...controller.timers.map(
                (row) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: buildTimerCard(context, row),
            ),
          ),
      ],
    );
  }
}