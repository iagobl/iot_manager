import 'package:flutter/material.dart';
import 'package:iot_manager/features/devices/presentation/controllers/device_light_controller.dart';

class DeviceLightSection extends StatefulWidget {
  const DeviceLightSection({
    super.key,
    required this.host,
  });

  final String host;

  @override
  State<DeviceLightSection> createState() => DeviceLightSectionState();
}

class DeviceLightSectionState extends State<DeviceLightSection> {
  late final DeviceLightController controller;

  @override
  void initState() {
    super.initState();
    controller = DeviceLightController(host: widget.host)
      ..addListener(onControllerChanged);
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

  void showSnack(String message, {bool isError = false,}) {
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

  void showControllerError({String fallback = 'Ha ocurrido un error inesperado.'}) {
    showSnack(controller.error ?? fallback, isError: true,);
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

    if (!controller.supported) {
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
                    Icon(Icons.lightbulb_outline, color: colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Luces del dispositivo',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  controller.error ?? 'Este dispositivo no expone la configuración de luces por RPC.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
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
                  Icon(Icons.lightbulb, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Luces del dispositivo',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (controller.saving)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Configura el comportamiento del aro LED.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: SizedBox(
                  width: 340,
                  child: SegmentedButton<LightMode>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.standard,
                      padding: WidgetStatePropertyAll(
                        EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                    segments: const [
                      ButtonSegment<LightMode>(
                        value: LightMode.power,
                        label: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.tune, size: 18),
                            SizedBox(height: 4),
                            Text('Por defecto',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ButtonSegment<LightMode>(
                        value: LightMode.switchColors,
                        label: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.palette_outlined, size: 18),
                            SizedBox(height: 4),
                            Text('Colores',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ButtonSegment<LightMode>(
                        value: LightMode.off,
                        label: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lightbulb_outline, size: 18),
                            SizedBox(height: 4),
                            Text('Sin luz',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    selected: {controller.mode},
                    onSelectionChanged: controller.saving
                        ? null
                        : (value) {
                      if (value.isEmpty) return;
                      controller.saveMode(value.first).then((_) {
                        showSnack('Modo de luz actualizado.');
                      }).catchError((_) {
                        showControllerError(fallback: 'No se pudo actualizar el modo de luz.',
                        );
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (controller.mode == LightMode.power)
          sectionCard(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Modo por defecto',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text('Brillo del LED cuando el dispositivo está encendido.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                brightnessTile(
                  context,
                  title: 'Brillo del LED',
                  value: controller.powerBrightness,
                  preview: DeviceLightController.previewColor(
                    const [100, 100, 100],
                    controller.powerBrightness,
                  ),
                  onChanged: controller.setPowerBrightness,
                  onChangeEnd: (value) {
                    controller.savePowerBrightness(value).then((_) {
                      showSnack('Brillo por defecto actualizado.');
                    }).catchError((_) {
                      showControllerError(fallback: 'No se pudo actualizar el brillo.',
                      );
                    });
                  },
                ),
              ],
            ),
          )
        else if (controller.mode == LightMode.switchColors)
          Column(
            children: [
              colorModeCard(
                context,
                title: 'Color cuando está encendido',
                rgb: controller.onRgb,
                brightness: controller.onBrightness,
                presets: const [
                  [0, 100, 0],
                  [100, 100, 100],
                  [0, 70, 100],
                  [100, 80, 0],
                  [100, 0, 100],
                  [100, 0, 0],
                ],
                onPresetSelected: (rgb) {
                  controller.saveRgb(isOn: true, rgb: rgb).then((_) {
                    showSnack('Color de encendido actualizado.');
                  }).catchError((_) {
                    showControllerError(fallback: 'No se pudo actualizar el color de encendido.',
                    );
                  });
                },
                onBrightnessChanged: controller.setOnBrightness,
                onBrightnessChangeEnd: (value) {
                  controller.saveOnBrightness(value).then((_) {
                    showSnack('Brillo de encendido actualizado.');
                  }).catchError((_) {
                    showControllerError(fallback: 'No se pudo actualizar el brillo de encendido.',
                    );
                  });
                },
              ),
              const SizedBox(height: 14),
              colorModeCard(
                context,
                title: 'Color cuando está apagado',
                rgb: controller.offRgb,
                brightness: controller.offBrightness,
                presets: const [
                  [100, 0, 0],
                  [100, 50, 0],
                  [100, 100, 100],
                  [0, 0, 100],
                  [80, 0, 100],
                  [0, 100, 100],
                ],
                onPresetSelected: (rgb) {
                  controller.saveRgb(isOn: false, rgb: rgb).then((_) {
                    showSnack('Color de apagado actualizado.');
                  }).catchError((_) {
                    showControllerError(fallback: 'No se pudo actualizar el color de apagado.',
                    );
                  });
                },
                onBrightnessChanged: controller.setOffBrightness,
                onBrightnessChangeEnd: (value) {
                  controller.saveOffBrightness(value).then((_) {
                    showSnack('Brillo de apagado actualizado.');
                  }).catchError((_) {
                    showControllerError(fallback: 'No se pudo actualizar el brillo de apagado.',
                    );
                  });
                },
              ),
            ],
          )
        else
          sectionCard(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Luces desactivadas',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text('En este modo el dispositivo no mostrará luz ni cuando esté encendido ni cuando esté apagado.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.power_settings_new,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('LED completamente apagado.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget colorModeCard(
      BuildContext context, {
        required String title,
        required List<int> rgb,
        required double brightness,
        required List<List<int>> presets,
        required ValueChanged<List<int>> onPresetSelected,
        required ValueChanged<double> onBrightnessChanged,
        required ValueChanged<double> onBrightnessChangeEnd,
      }) {
    final theme = Theme.of(context);
    final preview = DeviceLightController.previewColor(rgb, brightness);

    return sectionCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: preview,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black12),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: presets
                .map((preset) => colorPresetChip(
                rgb: preset,
                selected: DeviceLightController.sameRgb(rgb, preset),
                onTap: controller.saving ? null : () => onPresetSelected(preset)
              ),
            )
                .toList(),
          ),
          const SizedBox(height: 18),
          brightnessTile(
            context,
            title: 'Brillo',
            value: brightness,
            preview: preview,
            onChanged: onBrightnessChanged,
            onChangeEnd: onBrightnessChangeEnd,
          ),
        ],
      ),
    );
  }

  Widget brightnessTile(
      BuildContext context, {
        required String title,
        required double value,
        required Color preview,
        required ValueChanged<double> onChanged,
        required ValueChanged<double> onChangeEnd,
      }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: preview,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black12),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text('${value.round()}%',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: 0,
            max: 100,
            divisions: 100,
            label: '${value.round()}%',
            onChanged: controller.saving ? null : onChanged,
            onChangeEnd: controller.saving ? null : onChangeEnd,
          ),
        ],
      ),
    );
  }

  Widget colorPresetChip({
    required List<int> rgb,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    final color = DeviceLightController.previewColor(rgb, 100);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Colors.black87 : Colors.black12,
              width: selected ? 2.4 : 1.2,
            ),
            boxShadow: selected ? [BoxShadow(
                color: color.withValues(alpha: 0.38),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ] : null,
          ),
          child: selected ? const Icon(
            Icons.check_rounded,
            color: Colors.white,
            size: 22,
          ) : null,
        ),
      ),
    );
  }

  Widget sectionCard(BuildContext context, {required Widget child}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.8)),
      ), child: child,
    );
  }
}