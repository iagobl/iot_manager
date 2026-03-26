import 'package:flutter/material.dart';
import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';
import 'package:iot_manager/features/devices/presentation/controllers/device_schedules_controller.dart';

class DeviceSchedulesSection extends StatefulWidget {
  const DeviceSchedulesSection({
    super.key,
    required this.deviceId,
    required this.host,
    required this.remoteDatasource,
  });

  final String deviceId;
  final String host;
  final DevicesRemoteDatasource remoteDatasource;

  @override
  State<DeviceSchedulesSection> createState() => DeviceSchedulesSectionState();
}

class DeviceSchedulesSectionState extends State<DeviceSchedulesSection> {
  late final DeviceSchedulesController controller;

  static const List<WeekDayItem> weekDays = [
    WeekDayItem(1, 'L'),
    WeekDayItem(2, 'M'),
    WeekDayItem(3, 'X'),
    WeekDayItem(4, 'J'),
    WeekDayItem(5, 'V'),
    WeekDayItem(6, 'S'),
    WeekDayItem(7, 'D'),
  ];

  @override
  void initState() {
    super.initState();
    controller = DeviceSchedulesController(
      deviceId: widget.deviceId,
      host: widget.host,
      remoteDatasource: widget.remoteDatasource,
    )..addListener(onControllerChanged);

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

  Future<void> openCreateScheduleDialog() async {
    TimeOfDay selectedTime = const TimeOfDay(hour: 22, minute: 0);
    String selectedAction = 'on';
    final selectedDays = <int>{1, 2, 3, 4, 5, 6, 7};

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        final theme = Theme.of(dialogContext);

        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text('Nuevo horario',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Programa una hora, una acción y los días en los que se ejecutará.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: dialogContext,
                          initialTime: selectedTime,
                        );

                        if (picked != null) {
                          setLocalState(() {selectedTime = picked;});
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: colorScheme.outlineVariant,
                          ),
                          color: colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.45),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule_outlined,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text('Hora programada',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            Text(selectedTime.format(dialogContext),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('Acción', style: TextStyle(fontWeight: FontWeight.w700)),
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
                    const SizedBox(height: 18),
                    const Text('Días', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: weekDays.map((day) {
                        final isSelected = selectedDays.contains(day.value);

                        return FilterChip(
                          label: Text(day.shortLabel),
                          selected: isSelected,
                          onSelected: (value) {
                            setLocalState(() {
                              if (value) {
                                selectedDays.add(day.value);
                              } else {
                                selectedDays.remove(day.value);
                              }
                            });
                          },
                          selectedColor: colorScheme.primary.withValues(
                            alpha: 0.14,
                          ),
                          checkmarkColor: colorScheme.primary,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                          ),
                          side: BorderSide(
                            color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () {
                            setLocalState(() {
                              selectedDays
                                ..clear()
                                ..addAll([1, 2, 3, 4, 5]);
                            });
                          },
                          child: const Text('L-V'),
                        ),
                        TextButton(
                          onPressed: () {
                            setLocalState(() {
                              selectedDays
                                ..clear()
                                ..addAll([6, 7]);
                            });
                          },
                          child: const Text('Fin de semana'),
                        ),
                        TextButton(
                          onPressed: () {
                            setLocalState(() {
                              selectedDays
                                ..clear()
                                ..addAll([1, 2, 3, 4, 5, 6, 7]);
                            });
                          },
                          child: const Text('Todos'),
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
                    if (selectedDays.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('Selecciona al menos un día.')),
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

    final created = await controller.create(
      hour: selectedTime.hour,
      minute: selectedTime.minute,
      action: selectedAction,
      days: selectedDays.toList()..sort(),
    );

    if (!mounted) return;

    if (created) {
      showSnack('Horario guardado correctamente.');
    } else {
      showControllerError(fallback: 'No se pudo guardar el horario.',
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                color: selected ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> deleteSchedule(String id) async {
    final deleted = await controller.delete(id);

    if (!mounted) return;

    if (deleted) {
      showSnack('Horario eliminado.');
    } else {
      showControllerError(fallback: 'No se pudo eliminar el horario.',);
    }
  }

  Future<void> toggleSchedule(String id, bool value) async {
    final updated = await controller.toggleEnabled(id, value);

    if (!mounted) return;

    if (!updated) {
      showControllerError(fallback: 'No se pudo actualizar el horario.',);
    }
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
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.calendar_month_outlined,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Horarios programados',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (controller.busy)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: controller.busy ? null : openCreateScheduleDialog,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Añadir'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text('Configura encendidos y apagados automáticos por días de la semana.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (controller.error != null && controller.schedules.isEmpty)
          sectionCard(
            context,
            child: Text(
              controller.error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (controller.schedules.isEmpty)
          sectionCard(
            context,
            child: Column(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(Icons.schedule_outlined, size: 28, color: colorScheme.primary),
                ),
                const SizedBox(height: 14),
                Text('Aún no hay horarios guardados',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text('Añade un horario para que el Shelly lo ejecute automáticamente.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...controller.schedules.map((row) {
            final id = (row['id'] ?? '').toString();
            final enabled = row['enabled'] == true;

            final config = DeviceSchedulesController.mapFrom(row['config']);
            final hour = DeviceSchedulesController.intFrom(config['hour']);
            final minute = DeviceSchedulesController.intFrom(config['minute']);
            final action = (config['action'] ?? 'on').toString().toLowerCase();
            final days = DeviceSchedulesController.daysFromConfig(config['days']);

            final timeLabel = hour != null && minute != null
                ? TimeOfDay(hour: hour, minute: minute).format(context)
                : 'Hora no disponible';

            final actionLabel = action == 'off' ? 'Apagar' : 'Encender';
            final actionColor = action == 'off'
                ? colorScheme.error
                : colorScheme.primary;

            final daysLabel = DeviceSchedulesController.formatDays(days);

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: sectionCard(
                context,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: colorScheme.primary.withValues(alpha: 0.10),
                      ),
                      child: Icon(Icons.schedule_outlined, color: colorScheme.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(timeLabel,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(actionLabel,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: actionColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(daysLabel,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Transform.scale(
                          scale: 0.95,
                          child: Switch(
                            value: enabled,
                            onChanged: controller.busy ? null : (value) => toggleSchedule(id, value),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: controller.busy ? null : () => deleteSchedule(id),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(Icons.delete_outline, size: 21, color: colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget sectionCard(BuildContext context, {required Widget child}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class WeekDayItem {
  const WeekDayItem(this.value, this.shortLabel);

  final int value;
  final String shortLabel;
}