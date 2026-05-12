import 'package:flutter/material.dart';
import 'package:iot_manager/core/widgets/glass_card.dart';
import 'package:iot_manager/features/home/domain/entities/home_summary.dart';

import 'package:iot_manager/features/home/presentation/controllers/home_settings_controller.dart';

class HomeSettingsPage extends StatefulWidget {

  const HomeSettingsPage({
    super.key,
    required this.home,
  });
  final HomeSummary home;

  @override
  State<HomeSettingsPage> createState() => HomeSettingsPageState();
}

class HomeSettingsPageState extends State<HomeSettingsPage> {
  late final HomeSettingsController controller;

  late final TextEditingController nameController;
  late final TextEditingController emailController;
  late final TextEditingController maxTotalConsumptionController;

  HomeSettingsSection? expandedSection;

  @override
  void initState() {
    super.initState();
    controller = HomeSettingsController(home: widget.home);

    nameController = TextEditingController(text: widget.home.name);
    emailController = TextEditingController();
    maxTotalConsumptionController = TextEditingController();

    Future.microtask(() async {
      try {
        await controller.init(onUpdate: safeSetState);

        final settings = controller.securitySettings;
        if (settings != null) {
          maxTotalConsumptionController.text = settings['max_total_consumption_wh']?.toString() ?? '';
        }

        safeSetState();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando ajustes del hogar: $e')),
        );
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    maxTotalConsumptionController.dispose();
    super.dispose();
  }

  void safeSetState() {
    if (mounted) {
      setState(() {});
    }
  }

  void toggleSection(HomeSettingsSection section) {
    setState(() {
      if (expandedSection == section) {
        expandedSection = null;
      } else {
        expandedSection = section;
      }
    });
  }

  Future<void> saveHomeName() async {
    try {
      await controller.updateHomeName(nameController.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre del hogar actualizado.')),
      );
      setState(() {expandedSection = null;});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar el nombre: $e')),
      );
    }
  }

  Future<void> saveSafetySettings() async {
    try {
      await controller.saveSafetySettings(
        maxTotalConsumptionWh: double.tryParse(maxTotalConsumptionController.text.trim()),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Límite de consumo diario del hogar actualizado.'),
        ),
      );
      setState(() {expandedSection = null;});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el límite: $e')),
      );
    }
  }

  Future<void> shareHome() async {
    try {
      await controller.shareHomeByEmail(emailController.text.trim());
      emailController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitación enviada correctamente.')),
      );
      setState(() {expandedSection = null;});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo compartir el hogar: $e')),
      );
    }
  }

  Future<void> leaveSharedHome() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Salir del hogar'),
          content: const Text('¿Seguro que quieres quitar este hogar de tu cuenta compartida?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Salir'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await controller.leaveSharedHome();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Has salido del hogar compartido.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo salir del hogar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = controller.isOwner;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes del hogar'),
      ),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          ExpandableSectionCard(
            title: 'Nombre del hogar',
            subtitle: 'Cambia el nombre que se muestra en la aplicación.',
            isExpanded: expandedSection == HomeSettingsSection.name,
            onTap: () => toggleSection(HomeSettingsSection.name),
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: isOwner ? saveHomeName : null,
                    child: const Text('Guardar nombre'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ExpandableSectionCard(
            title: 'Consumo máximo diario del hogar',
            subtitle: 'Define el consumo total máximo en Wh que puede alcanzar este hogar en un día.',
            isExpanded: expandedSection == HomeSettingsSection.consumption,
            onTap: () => toggleSection(HomeSettingsSection.consumption),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Si se supera, los dispositivos del hogar no podrán seguir funcionando hasta que se reinicie el cómputo diario o ajustes el límite.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: maxTotalConsumptionController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Consumo máximo diario (Wh)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: isOwner ? saveSafetySettings : null,
                    child: const Text('Guardar límite'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ExpandableSectionCard(
            title: 'Compartir hogar',
            subtitle: 'Invita a otro usuario por correo electrónico para que tenga acceso al hogar y a sus dispositivos.',
            isExpanded: expandedSection == HomeSettingsSection.share,
            onTap: () => toggleSection(HomeSettingsSection.share),
            child: Column(
              children: [
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo del usuario',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isOwner ? shareHome : null,
                    icon: const Icon(Icons.mail_outline),
                    label: const Text('Enviar invitación'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ExpandableSectionCard(
            title: 'Acceso compartido',
            subtitle: isOwner ? 'Eres el propietario de este hogar.' : 'Este hogar ha sido compartido contigo.',
            isExpanded: expandedSection == HomeSettingsSection.access,
            onTap: () => toggleSection(HomeSettingsSection.access),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isOwner ? null : leaveSharedHome,
                icon: const Icon(Icons.logout),
                label: Text(isOwner ? 'Propietario del hogar' : 'Salir del hogar'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum HomeSettingsSection {
  name,
  consumption,
  share,
  access,
}

class ExpandableSectionCard extends StatelessWidget {

  const ExpandableSectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isExpanded,
    required this.onTap,
    required this.child,
  });
  final String title;
  final String subtitle;
  final bool isExpanded;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return RepaintBoundary(
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.zero,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(subtitle,
                            style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: cs.onSurfaceVariant,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: child,
              ),
              crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 220),
              sizeCurve: Curves.easeInOut,
            ),
          ],
        ),
      ),
    );
  }
}
