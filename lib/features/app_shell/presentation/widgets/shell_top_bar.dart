import 'package:flutter/material.dart';
import 'package:iot_manager/core/constants/app_strings.dart';

class ShellTopBar extends StatelessWidget {
  const ShellTopBar({
    super.key,
    required this.title,
    required this.subtitle,
    this.onLogout,
    this.notificationsCount = 0,
    this.onNotificationsTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onLogout;
  final int notificationsCount;
  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget actionShell({required Widget child}) {
      return Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: cs.surface.withValues(alpha: 0.72),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
        child: child,
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Badge(
            isLabelVisible: notificationsCount > 0,
            label: Text(notificationsCount > 99 ? '99+' : '$notificationsCount'),
            child: actionShell(
              child: IconButton(
                tooltip: 'Notificaciones',
                onPressed: onNotificationsTap,
                icon: const Icon(Icons.notifications_none_rounded),
              ),
            ),
          ),
          const SizedBox(width: 10),
          actionShell(
            child: PopupMenuButton<String>(
              tooltip: 'Perfil',
              onSelected: (value) {
                if (value == 'logout') onLogout?.call();
              },
              icon: const Icon(Icons.person_outline_rounded),
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  enabled: false,
                  value: 'app',
                  child: Text(AppStrings.appName),
                ),
                PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded),
                      SizedBox(width: 10),
                      Text('Cerrar sesión'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
