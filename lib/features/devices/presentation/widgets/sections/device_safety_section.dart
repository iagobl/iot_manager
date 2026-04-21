import 'package:flutter/material.dart';
import 'package:iot_manager/features/devices/presentation/controllers/device_safety_controller.dart';


class DeviceSafetySection extends StatefulWidget {
  const DeviceSafetySection({
    super.key,
    required this.host,
  });

  final String host;

  @override
  State<DeviceSafetySection> createState() => DeviceSafetySectionState();
}

class DeviceSafetySectionState extends State<DeviceSafetySection> {
  late final DeviceSafetyController controller;

  final powerCtrl = TextEditingController();
  final voltageCtrl = TextEditingController();
  final currentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller = DeviceSafetyController(host: widget.host);
    controller.addListener(sync);
    controller.load();
  }

  void sync() {
    if (!mounted) return;
    setState(() {
      powerCtrl.text =
          DeviceSafetyController.formatNumber(controller.powerLimit);
      voltageCtrl.text =
          DeviceSafetyController.formatNumber(controller.voltageLimit);
      currentCtrl.text =
          DeviceSafetyController.formatNumber(controller.currentLimit);
    });
  }

  @override
  void dispose() {
    controller.removeListener(sync);
    controller.dispose();
    powerCtrl.dispose();
    voltageCtrl.dispose();
    currentCtrl.dispose();
    super.dispose();
  }

  void snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget buildCard({
    required String title,
    required String desc,
    required TextEditingController controller,
    required VoidCallback onSave,
    required bool loading,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: colorScheme.surface,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(desc, style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: colorScheme.outlineVariant,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: colorScheme.primary,
                            width: 1.2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: loading ? null : onSave,
                    icon: loading ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ) : const Icon(Icons.save_outlined, size: 16),
                    label: Text(loading ? '...' : 'Guardar',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const Text(
          'Protección y seguridad',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,),
        ),
        const SizedBox(height: 18),
        buildCard(
          title: 'Potencia máxima (W)',
          desc: 'Apaga el dispositivo si supera esta potencia.',
          controller: powerCtrl,
          loading: controller.savingPower,
          onSave: () {
            final value = DeviceSafetyController.parseValue(powerCtrl.text);
            if (powerCtrl.text.trim().isNotEmpty && value == null) {
              snack('La potencia máxima no es válida.');
              return;
            }
            if (value != null && value <= 0) {
              snack('El valor debe ser mayor que 0.');
              return;
            }

            controller.savePowerLimit(value)
                .then((_) => snack('Límite de potencia guardado.'))
                .catchError((_) =>
                snack('Error guardando el límite de potencia.'));
          },
        ),
        const SizedBox(height: 12),
        buildCard(
          title: 'Tensión máxima (V)',
          desc: 'Protege frente a sobretensión.',
          controller: voltageCtrl,
          loading: controller.savingVoltage,
          onSave: () {
            final value = DeviceSafetyController.parseValue(voltageCtrl.text);
            if (voltageCtrl.text.trim().isNotEmpty && value == null) {
              snack('La tensión máxima no es válida.');
              return;
            }
            if (value != null && value <= 0) {
              snack('El valor debe ser mayor que 0.');
              return;
            }

            controller.saveVoltageLimit(value)
                .then((_) => snack('Límite de tensión guardado.'))
                .catchError((_) =>
                snack('Error guardando el límite de tensión.'));
          },
        ),
        const SizedBox(height: 12),
        buildCard(
          title: 'Corriente máxima (A)',
          desc: 'Evita sobrecargas.',
          controller: currentCtrl,
          loading: controller.savingCurrent,
          onSave: () {
            final value = DeviceSafetyController.parseValue(currentCtrl.text);
            if (currentCtrl.text.trim().isNotEmpty && value == null) {
              snack('La corriente máxima no es válida.');
              return;
            }
            if (value != null && value <= 0) {
              snack('El valor debe ser mayor que 0.');
              return;
            }

            controller.saveCurrentLimit(value)
                .then((_) => snack('Límite de corriente guardado.'))
                .catchError((_) =>
                snack('Error guardando el límite de corriente.'));
          },
        ),
      ],
    );
  }
}
