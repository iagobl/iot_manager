import 'package:flutter/material.dart';

import '../../../../core/widgets/glass_card.dart';
import '../controllers/devices_controller.dart';
import '../widgets/device_card.dart';

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => DevicesPageState();
}

class DevicesPageState extends State<DevicesPage> {
  late final DevicesController controller;

  @override
  void initState() {
    super.initState();
    controller = DevicesController.create();
    controller.addListener(onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.load();
    });
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
    if (controller.loading && controller.devices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.errorMessage != null && controller.devices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_tethering_error_rounded, size: 42),
                const SizedBox(height: 14),
                Text(
                  controller.errorMessage!,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: controller.load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
        children: [
          GlassCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Panel de dispositivos',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Aquí verás todos los dispositivos asociados a tu cuenta.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.12),
                  ),
                  child: const Icon(Icons.devices_other_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (controller.devices.isEmpty)
            const _EmptyDevicesBlock()
          else
            ...controller.devices.map(
              (device) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DeviceCard(device: device),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyDevicesBlock extends StatelessWidget {
  const _EmptyDevicesBlock();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GlassCard(
      child: Column(
        children: [
          Icon(
            Icons.devices_fold_rounded,
            size: 42,
            color: cs.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'Todavía no hay dispositivos',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Cuando vincules el primero, aparecerá aquí con su estado y su información básica.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
