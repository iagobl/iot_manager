import 'package:flutter/material.dart';
import 'package:iot_manager/app/routes.dart';
import 'package:iot_manager/core/widgets/app_background.dart';
import 'package:iot_manager/features/analytics/presentation/pages/analytics_page.dart';
import 'package:iot_manager/features/app_shell/presentation/controllers/notifications_controller.dart';
import 'package:iot_manager/features/app_shell/presentation/widgets/device_notifications_sheet.dart';
import 'package:iot_manager/features/app_shell/presentation/widgets/shell_top_bar.dart';
import 'package:iot_manager/features/devices/presentation/pages/devices_page.dart';
import 'package:iot_manager/features/home/presentation/pages/home_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int currentIndex = 0;
  int devicesRefreshKey = 0;

  late final NotificationsController notificationsController;

  static const _titles = [
    ('Inicio', 'Resumen general de tu instalación'),
    ('Gráficas', 'Visualización de consumos y actividad'),
    ('Dispositivos', 'Listado de dispositivos asociados'),
  ];

  @override
  void initState() {
    super.initState();
    notificationsController = NotificationsController()..addListener(rebuild);
    notificationsController.load();
  }

  @override
  void dispose() {
    notificationsController.removeListener(rebuild);
    notificationsController.dispose();
    super.dispose();
  }

  void rebuild() {
    if (mounted) setState(() {});
  }

  void refreshDevicesTab() {
    if (!mounted) return;
    setState(() {
      devicesRefreshKey++;
    });
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.authGate,
          (_) => false,
    );
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).pushNamed(Routes.profile);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> openNotifications() async {
    await notificationsController.load();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.72,
        child: DeviceNotificationsSheet(
          controller: notificationsController,
          onInvitationsChanged: () async {
            await notificationsController.load();
            refreshDevicesTab();
          },
        ),
      ),
    );
  }

  List<Widget> buildPages() {
    return [
      const HomePage(),
      const AnalyticsPage(),
      DevicesPage(
        key: ValueKey(devicesRefreshKey),
      ),
    ];
  }

  void onDestinationSelected(int index) {
    setState(() {
      currentIndex = index;

      if (index == 2) {
        devicesRefreshKey++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = _titles[currentIndex].$1;
    final subtitle = _titles[currentIndex].$2;
    final pages = buildPages();

    return Scaffold(
      extendBody: true,
      body: AppBackground(
        child: Column(
          children: [
            ShellTopBar(
              title: title,
              subtitle: subtitle,
              onLogout: _logout,
              onProfileTap: _openProfile,
              notificationsCount: notificationsController.pendingCount,
              onNotificationsTap: openNotifications,
            ),
            Expanded(
              child: IndexedStack(
                index: currentIndex,
                children: pages,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: cs.surface.withValues(alpha: 0.92),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.7),
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 24,
                offset: const Offset(0, 12),
                color: Colors.black.withValues(alpha: 0.08),
              ),
            ],
          ),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            selectedIndex: currentIndex,
            indicatorColor: cs.primary.withValues(alpha: 0.14),
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            onDestinationSelected: onDestinationSelected,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Icon(Icons.query_stats_outlined),
                selectedIcon: Icon(Icons.query_stats_rounded),
                label: 'Gráficas',
              ),
              NavigationDestination(
                icon: Icon(Icons.devices_other_outlined),
                selectedIcon: Icon(Icons.devices_other_rounded),
                label: 'Dispositivos',
              ),
            ],
          ),
        ),
      ),
    );
  }
}