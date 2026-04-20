import 'package:flutter/material.dart';

import 'package:iot_manager/core/constants/app_strings.dart';
import 'package:iot_manager/core/constants/auth_strings.dart';
import 'package:iot_manager/core/constants/home_strings.dart';
import 'package:iot_manager/core/widgets/glass_card.dart';

import 'package:iot_manager/features/home/presentation/controllers/home_controller.dart';
import 'package:iot_manager/features/home/presentation/pages/home_detail_page.dart';
import 'package:iot_manager/features/home/presentation/widgets/devices_overview_card.dart';
import 'package:iot_manager/features/home/presentation/widgets/home_summary_card.dart';
import 'package:iot_manager/features/home/presentation/widgets/quick_stat_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  late final HomeController controller;

  Future<void> refreshFromTabReselect() async {
    await controller.refresh(showOverlay: true);
  }

  @override
  void initState() {
    super.initState();
    controller = HomeController.create();
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

  String get welcomeName {
    final name = controller.firstName.trim();
    if (name.isNotEmpty) return name;
    return AuthStrings.againUser;
  }

  Future<void> showCreateHomeDialog() async {
    final textController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(HomeStrings.newHome),
          content: TextField(
            controller: textController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: HomeStrings.ejHome,
              labelText: HomeStrings.nameHome,
            ),
            onSubmitted: (_) => Navigator.of(context).pop(true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(AppStrings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(AppStrings.create),
            ),
          ],
        );
      },
    );

    if (created != true) return;

    final ok = await controller.createHome(textController.text);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
              ? HomeStrings.confirmationCreateHome
              : (controller.errorMessage ?? HomeStrings.notConfirmationCreateHome),
        ),
      ),
    );
  }

  Future<void> confirmDeleteHome({
    required String homeId,
    required String homeName,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(HomeStrings.deleteHome),
          content: Text(
            '¿Quieres eliminar "$homeName"?\n\n${HomeStrings.deleteHomeDescription}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(AppStrings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(AppStrings.delete),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final ok = await controller.deleteHome(homeId);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
              ? HomeStrings.confirmationDeleteHome
              : (controller.errorMessage ?? HomeStrings.notConfirmationDeleteHome),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (controller.loading && controller.overview == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.errorMessage != null && controller.overview == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: RepaintBoundary(
            child: GlassCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 40),
                  const SizedBox(height: 14),
                  Text(
                    controller.errorMessage!,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: controller.load,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text(AppStrings.retry),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => controller.refresh(showOverlay: false),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
            children: [
              RepaintBoundary(
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AuthStrings.helloUser + welcomeName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(HomeStrings.descriptionHome,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              RepaintBoundary(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = (constraints.maxWidth - 12) / 2;

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: itemWidth,
                          height: 160,
                          child: DevicesOverviewCard(
                            totalDevices: controller.totalDevices,
                            activeDevices: controller.activeDevices,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          height: 160,
                          child: QuickStatCard(
                            label: HomeStrings.consumptionToday,
                            value:
                            '${controller.totalTodayWh.toStringAsFixed(0)} Wh',
                            icon: Icons.energy_savings_leaf_outlined,
                            valueFontSize: 24,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(
                    child: SectionHeader(
                      title: HomeStrings.yourHomes,
                      subtitle: '',
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: controller.creatingHome ? null : showCreateHomeDialog,
                    icon: controller.creatingHome
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.add_home_outlined),
                    label: const Text(AppStrings.create),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              RepaintBoundary(
                child: controller.homes.isEmpty
                    ? _EmptyBlock(
                  title: HomeStrings.descriptionNewHome,
                  subtitle: HomeStrings.warningNewHome,
                  icon: Icons.home_outlined,
                  actionLabel: HomeStrings.newHome,
                  onAction: controller.creatingHome ? null : showCreateHomeDialog,
                ) : Column(
                  children: controller.homes.map((home) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(context,
                            MaterialPageRoute(builder: (_) => HomeDetailPage(home: home)),
                          );
                        },
                        child: HomeSummaryCard(
                          name: home.name,
                          subtitle:
                          '${controller.getDeviceCountForHome(home.id)} dispositivos',
                          icon: Icons.house_siding_rounded,
                          deleting: controller.deletingId == home.id,
                          onDelete: controller.deletingId != null ? null : () => confirmDeleteHome(
                            homeId: home.id,
                            homeName: home.name,
                          ),
                        ),
                      ),
                    ),
                  )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        if (controller.refreshing)
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                      color: Colors.black.withValues(alpha: 0.08),
                    ),
                  ],
                ),
                child: const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return RepaintBoundary(
      child: GlassCard(
        child: Column(
          children: [
            Icon(icon, size: 42, color: cs.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_home_outlined),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
