import 'package:flutter/material.dart';
import 'package:iot_manager/core/widgets/app_page_background.dart';
import 'package:iot_manager/core/widgets/glass_card.dart';
import 'package:iot_manager/features/devices/domain/entities/device_item.dart';
import 'package:iot_manager/features/devices/presentation/pages/device_panel_page.dart';

import 'package:iot_manager/features/home/presentation/controllers/home_detail_controller.dart';
import 'package:iot_manager/features/home/presentation/pages/home_settings_page.dart';

class HomeDetailPage extends StatefulWidget {

  const HomeDetailPage({
    super.key,
    required this.home,
  });
  final dynamic home;

  @override
  State<HomeDetailPage> createState() => _HomeDetailPageState();
}

class _HomeDetailPageState extends State<HomeDetailPage> {
  late final HomeDetailController controller;

  @override
  void initState() {
    super.initState();
    controller = HomeDetailController(homeId: widget.home.id as String);
    controller.init(onUpdate: safeSetState);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void safeSetState() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> goBackAndRefreshPrevious() async {
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> openSettings() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => HomeSettingsPage(home: widget.home)),
    );

    if (result == true) {
      await controller.load();
      safeSetState();
    }
  }

  Future<void> openAssignDevicesSheet() async {
    try {
      await controller.loadAvailableDevices();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar los dispositivos: $e')),
      );
      return;
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final availableDevices = controller.availableDevices;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Añadir dispositivos al hogar',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        availableDevices.isEmpty
                            ? 'No tienes dispositivos disponibles sin asignar a un hogar.'
                            : 'Selecciona uno o varios dispositivos disponibles para añadirlos a este hogar.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (controller.isLoadingAvailableDevices)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      )
                    else if (availableDevices.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text('No hay dispositivos disponibles para añadir.',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 420),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: availableDevices.length,
                          separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final device = availableDevices[index];
                            final deviceId = device['id'] as String;
                            final selected = controller.selectedAvailableDeviceIds
                                .contains(deviceId);

                            return InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () {
                                controller.toggleAvailableDeviceSelection(deviceId);
                                setModalState(() {});
                              },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: selected ? const Color(0xFF2563EB) : Colors.grey.shade300,
                                  ),
                                  color: selected ?
                                  const Color(0xFF2563EB).withValues(alpha: 0.08) : Colors.white,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.power_outlined),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text((device['name'] ?? 'Dispositivo') as String,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text((device['device_type'] ?? 'Sin tipo') as String,
                                            style: TextStyle(color: Colors.grey.shade700,),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Checkbox(
                                      value: selected,
                                      onChanged: (_) {
                                        controller.toggleAvailableDeviceSelection(deviceId,);
                                        setModalState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: controller.selectedAvailableDeviceIds.isEmpty
                            ? null : () async {
                          Navigator.of(context).pop();
                          await assignSelectedDevices();
                        },
                        icon: const Icon(Icons.add_link),
                        label: const Text('Añadir seleccionados'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> assignSelectedDevices() async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await controller.assignSelectedDevicesToHome();
      messenger.showSnackBar(
        const SnackBar(content: Text('Dispositivos añadidos correctamente.')),
      );
      safeSetState();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudieron añadir los dispositivos: $e')),
      );
    }
  }

  Future<void> removeDevice(String deviceId) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await controller.removeDeviceFromHome(deviceId);
      messenger.showSnackBar(
        const SnackBar(content: Text('Dispositivo eliminado del hogar.')),
      );
      safeSetState();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo eliminar el dispositivo: $e')),
      );
    }
  }

  Future<void> openDeviceDetail(Map<String, dynamic> deviceMap) async {
    final normalizedMap = Map<String, dynamic>.from(deviceMap);
    final deviceItem = DeviceItem.fromMap(normalizedMap);

    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DevicePanelPage(device: deviceItem)),
    );

    if (!mounted) return;
    if (updated == true) {
      await controller.load();
      safeSetState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeName = widget.home.name.isNotEmpty ? widget.home.name : 'Hogar';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppPageBackground(
        variant: AppPageBackgroundVariant.homeSoft,
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: controller.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              children: [
                HomeDetailHeader(
                  title: homeName,
                  onBack: goBackAndRefreshPrevious,
                  onSettings: openSettings,
                ),
                const SizedBox(height: 20),
                RepaintBoundary(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 700;
                      final itemWidth = isWide ? (constraints.maxWidth - 24) / 3
                          : (constraints.maxWidth - 12) / 2;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: itemWidth,
                            child: QuickDetailStatCard(
                              label: 'Dispositivos',
                              value: '${controller.devices.length}',
                              icon: Icons.memory_outlined,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: QuickDetailStatCard(
                              label: 'Activos',
                              value: '${controller.activeDevices}',
                              icon: Icons.bolt_rounded,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: QuickDetailStatCard(
                              label: 'Consumo hoy',
                              value:
                              '${controller.todayConsumptionWh.toStringAsFixed(0)} Wh',
                              icon: Icons.energy_savings_leaf_outlined,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: QuickDetailStatCard(
                              label: 'Incidencias',
                              value: '${controller.unresolvedIncidents}',
                              icon: Icons.warning_amber_rounded,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 22),
                RepaintBoundary(
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('Dispositivos del hogar',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: openAssignDevicesSheet,
                              icon: const Icon(Icons.add),
                              label: const Text('Añadir'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (controller.isLoading)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (controller.devices.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text('Todavía no hay dispositivos en este hogar.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        else
                          Column(
                            children: controller.devices.map((device) {
                              final isActive =
                                  (device['live_is_active'] ?? device['is_active'] ?? false) == true;
                              final power = ((device['power_w'] as num?) ?? 0).toDouble();

                              return HomeDeviceCard(
                                name: (device['name'] ?? 'Dispositivo') as String,
                                type: (device['device_type'] ?? 'Sin tipo') as String,
                                isActive: isActive,
                                power: power,
                                onTap: () => openDeviceDetail(device),
                                onRemove: () => removeDevice(device['id'] as String),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeDetailHeader extends StatelessWidget {
  const HomeDetailHeader({super.key,
    required this.title,
    required this.onBack,
    required this.onSettings,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        HeaderCircleButton(
          icon: Icons.arrow_back_rounded,
          onTap: onBack,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 14),
        HeaderCircleButton(
          icon: Icons.settings_outlined,
          onTap: onSettings,
        ),
      ],
    );
  }
}

class HeaderCircleButton extends StatelessWidget {
  const HeaderCircleButton({super.key,
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha:0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon,
            size: 22,
            color: cs.onSurface,
          ),
        ),
      ),
    );
  }
}

class QuickDetailStatCard extends StatelessWidget {

  const QuickDetailStatCard({super.key,
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: cs.primary.withValues(alpha: 0.10),
            ),
            child: Icon(icon, color: cs.primary),
          ),
          const SizedBox(height: 18),
          Text(value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class HomeDeviceCard extends StatefulWidget {
  const HomeDeviceCard({super.key,
    required this.name,
    required this.type,
    required this.isActive,
    required this.power,
    required this.onTap,
    required this.onRemove,
  });

  final String name;
  final String type;
  final bool isActive;
  final double power;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  State<HomeDeviceCard> createState() => HomeDeviceCardState();
}

class HomeDeviceCardState extends State<HomeDeviceCard> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MouseRegion(
        onEnter: (_) => setState(() => hovering = true),
        onExit: (_) => setState(() => hovering = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: Matrix4.identity()..translateByDouble(0.0, hovering ? -2.0 : 0.0, 0.0, 1.0)
            ..scaleByDouble(hovering ? 1.01 : 1.0, hovering ? 1.01 : 1.0, 1.0, 1.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: hovering ? [
              BoxShadow(
                color: cs.primary.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ] : const [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: widget.onTap,
              child: Ink(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: cs.surface.withValues(alpha: 0.58),
                  border: Border.all(
                    color: hovering ? cs.primary.withValues(alpha: 0.35)
                        : cs.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.power_outlined, color: cs.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('${widget.type} · ${widget.isActive ? 'Activo' : 'Inactivo'}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('Potencia actual: ${widget.power.toStringAsFixed(1)} W',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: hovering ? 1 : 0.75,
                      child: Icon(Icons.chevron_right_rounded,
                        color: cs.onSurfaceVariant,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(tooltip: 'Quitar del hogar',
                      onPressed: widget.onRemove,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}