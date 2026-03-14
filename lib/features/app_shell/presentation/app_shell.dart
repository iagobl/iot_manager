import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/app_background.dart';
import '../../analytics/presentation/pages/analytics_page.dart';
import '../../devices/presentation/pages/devices_page.dart';
import '../../home/presentation/pages/home_page.dart';
import 'widgets/shell_top_bar.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int currentIndex = 0;

  static const _pages = [
    HomePage(),
    AnalyticsPage(),
    DevicesPage(),
  ];

  static const _titles = [
    ('Inicio', 'Resumen general de tu instalación'),
    ('Gráficas', 'Visualización de consumos y actividad'),
    ('Dispositivos', 'Listado de dispositivos asociados'),
  ];

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.authGate,
          (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = _titles[currentIndex].$1;
    final subtitle = _titles[currentIndex].$2;

    return Scaffold(
      extendBody: true,
      body: AppBackground(
        child: Column(
          children: [
            ShellTopBar(
              title: title,
              subtitle: subtitle,
              onLogout: _logout,
            ),
            Expanded(
              child: IndexedStack(
                index: currentIndex,
                children: _pages,
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
            labelBehavior:
            NavigationDestinationLabelBehavior.onlyShowSelected,
            onDestinationSelected: (index) {
              setState(() => currentIndex = index);
            },
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
