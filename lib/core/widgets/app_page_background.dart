import 'package:flutter/material.dart';

enum AppPageBackgroundVariant {
  defaultStyle,
  homeSoft,
}

class AppPageBackground extends StatelessWidget {
  const AppPageBackground({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.variant = AppPageBackgroundVariant.defaultStyle,
  });

  final Widget child;
  final EdgeInsets padding;
  final AppPageBackgroundVariant variant;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final config = resolveVariant(cs);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: config.gradientColors,
          stops: const [0.0, 0.22, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: config.topOrbTop,
            left: config.topOrbLeft,
            child: BlurCircle(
              size: config.topOrbSize,
              color: config.topOrbColor,
            ),
          ),
          Positioned(
            top: config.rightOrbTop,
            right: config.rightOrbRight,
            child: BlurCircle(
              size: config.rightOrbSize,
              color: config.rightOrbColor,
            ),
          ),
          Positioned(
            bottom: config.bottomOrbBottom,
            left: config.bottomOrbLeft,
            child: BlurCircle(
              size: config.bottomOrbSize,
              color: config.bottomOrbColor,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: config.topGlowHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [config.topGlowColor, Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }

  BackgroundConfig resolveVariant(ColorScheme cs) {
    switch (variant) {
      case AppPageBackgroundVariant.homeSoft:
        return BackgroundConfig(
          gradientColors: [
            Color.alphaBlend(
              cs.primary.withValues(alpha: 0.035),
              cs.surface,
            ),
            Color.alphaBlend(
              cs.secondary.withValues(alpha: 0.025),
              cs.surfaceContainerLowest,
            ), cs.surface,
          ],
          topOrbColor: cs.primary.withValues(alpha: 0.085),
          rightOrbColor: cs.tertiary.withValues(alpha: 0.055),
          bottomOrbColor: cs.secondary.withValues(alpha: 0.045),
          topOrbSize: 230,
          rightOrbSize: 170,
          bottomOrbSize: 150,
          topOrbTop: -70,
          topOrbLeft: -55,
          rightOrbTop: 250,
          rightOrbRight: -45,
          bottomOrbBottom: -45,
          bottomOrbLeft: 40,
          topGlowHeight: 170,
          topGlowColor: cs.primary.withValues(alpha: 0.06),
        );

      case AppPageBackgroundVariant.defaultStyle:
        return BackgroundConfig(
          gradientColors: [
            cs.surface,
            cs.surfaceContainerLowest.withValues(alpha: 0.97),
            cs.surface,
          ],
          topOrbColor: cs.primary.withValues(alpha: 0.10),
          rightOrbColor: cs.secondary.withValues(alpha: 0.08),
          bottomOrbColor: cs.tertiary.withValues(alpha: 0.07),
          topOrbSize: 190,
          rightOrbSize: 170,
          bottomOrbSize: 160,
          topOrbTop: -80,
          topOrbLeft: -40,
          rightOrbTop: 110,
          rightOrbRight: -55,
          bottomOrbBottom: -70,
          bottomOrbLeft: 20,
          topGlowHeight: 120,
          topGlowColor: cs.primary.withValues(alpha: 0.035),
        );
    }
  }
}

class BlurCircle extends StatelessWidget {
  const BlurCircle({
    super.key,
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: 80,
              spreadRadius: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class BackgroundConfig {
  const BackgroundConfig({
    required this.gradientColors,
    required this.topOrbColor,
    required this.rightOrbColor,
    required this.bottomOrbColor,
    required this.topOrbSize,
    required this.rightOrbSize,
    required this.bottomOrbSize,
    required this.topOrbTop,
    required this.topOrbLeft,
    required this.rightOrbTop,
    required this.rightOrbRight,
    required this.bottomOrbBottom,
    required this.bottomOrbLeft,
    required this.topGlowHeight,
    required this.topGlowColor,
  });

  final List<Color> gradientColors;
  final Color topOrbColor;
  final Color rightOrbColor;
  final Color bottomOrbColor;

  final double topOrbSize;
  final double rightOrbSize;
  final double bottomOrbSize;

  final double topOrbTop;
  final double topOrbLeft;
  final double rightOrbTop;
  final double rightOrbRight;
  final double bottomOrbBottom;
  final double bottomOrbLeft;

  final double topGlowHeight;
  final Color topGlowColor;
}