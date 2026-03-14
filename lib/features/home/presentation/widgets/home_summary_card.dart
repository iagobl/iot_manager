import 'package:flutter/material.dart';

import '../../../../core/constants/home_strings.dart';
import '../../../../core/widgets/glass_card.dart';

class HomeSummaryCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onDelete;
  final bool deleting;

  const HomeSummaryCard({
    super.key,
    required this.name,
    required this.subtitle,
    required this.icon,
    this.onDelete,
    this.deleting = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: cs.primary.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: cs.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (deleting)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: HomeStrings.deleteHome,
            ),
        ],
      ),
    );
  }
}