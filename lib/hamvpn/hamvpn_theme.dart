import 'package:flutter/material.dart';

/// Цвета бренда ХамВПН — те же, что на иконке и заставке.
abstract class HamColors {
  static const night = Color(0xFF2E1636); // фон заставки, низ иконки
  static const dusk = Color(0xFF3B1D5C); // верх неба
  static const rose = Color(0xFFC2446A); // закат
  static const gold = Color(0xFFFFD18A); // надпись «VPN»
  static const cream = Color(0xFFFFF8EE); // мечеть
  static const ok = Color(0xFF4CAF7A);
  static const warn = Color(0xFFE5A23A);
  static const bad = Color(0xFFE5484D);

  static const skyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [dusk, Color(0xFF6E2A63), night],
  );

  static const cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4A2160), Color(0xFF8E3567)],
  );
}

String hamDays(int n) {
  final mod10 = n % 10, mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return '$n день';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return '$n дня';
  return '$n дней';
}

String hamRub(double v) {
  final whole = v.truncateToDouble() == v;
  return '${whole ? v.toStringAsFixed(0) : v.toStringAsFixed(2)} ₽';
}
