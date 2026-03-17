import 'package:flutter/material.dart';

Color powerPanelAccent(bool isOn) {
  return isOn ? const Color(0xFF3D6EA8) : const Color(0xFF7E8A9A);
}

Color powerPanelBackground(bool isOn) {
  return isOn ? const Color(0xFFEAF2FF) : const Color(0xFFF3F5F8);
}

Color powerButtonBackground(bool isOn) {
  return isOn ? const Color(0xFF3D6EA8) : const Color(0xFF6F7E91);
}

Color consumptionAccent(double watts) {
  if (watts >= 1000) return const Color(0xFFD05C47);
  if (watts >= 300) return const Color(0xFFE58E26);
  if (watts > 0) return const Color(0xFFB89A2E);
  return const Color(0xFF3D6EA8);
}

List<Color> consumptionGradient(double watts) {
  if (watts >= 1000) {
    return [
      const Color(0xFFFFF4F1),
      const Color(0xFFFFECE7),
    ];
  }
  if (watts >= 300) {
    return [
      const Color(0xFFFFF8EE),
      const Color(0xFFFFF1E1),
    ];
  }
  if (watts > 0) {
    return [
      const Color(0xFFFFFBF1),
      const Color(0xFFFFF6E4),
    ];
  }
  return [
    Colors.white.withValues(alpha: 0.92),
    const Color(0xFFF3F5F9).withValues(alpha: 0.92),
  ];
}