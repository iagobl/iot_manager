import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: 0.10),
            cs.secondary.withValues(alpha: 0.07),
            cs.tertiary.withValues(alpha: 0.05),
            cs.surface,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            left: -50,
            child: _SoftCircle(size: 180, color: cs.primary.withValues(alpha: 0.12),),
          ),
          Positioned(
            top: 120,
            right: -30,
            child: _SoftCircle(size: 110, color: cs.tertiary.withValues(alpha: 0.08),),
          ),
          Positioned(
            bottom: -90,
            right: -40,
            child: _SoftCircle(size: 220, color: cs.secondary.withValues(alpha: 0.10),),
          ),
          Positioned(
            bottom: 140,
            left: -20,
            child: _SoftCircle(size: 90, color: cs.primary.withValues(alpha: 0.06),),
          ),
          Positioned.fill(child: SafeArea(child: child),),
        ],
      ),
    );
  }
}

class _SoftCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _SoftCircle({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}