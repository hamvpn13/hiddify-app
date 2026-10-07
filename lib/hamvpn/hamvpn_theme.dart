import 'package:flutter/material.dart';

/// Оформление ХамВПН — стандартный Material 3 (как в последних версиях Android):
/// цвета берутся из обоев телефона (Material You), а если телефон этого не умеет —
/// из фирменного цвета иконки. Здесь — удобные «токены» поверх ColorScheme
/// и смысловые цвета: зелёный — работает, красный — остановлено, жёлтый — внимание.
@immutable
class HamTokens {
  const HamTokens({
    required this.bg,
    required this.bgElev,
    required this.bgSunken,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textDim,
    required this.accent,
    required this.accentFill,
    required this.accentInk,
    required this.accentSoft,
    required this.green,
    required this.greenSoft,
    required this.red,
    required this.redSoft,
    required this.amber,
    required this.amberSoft,
  });

  final Color bg, bgElev, bgSunken, border, borderStrong, text, textDim;
  final Color accent, accentFill, accentInk, accentSoft;
  final Color green, greenSoft, red, redSoft, amber, amberSoft;

  static const radius = 20.0;
  static const radiusSm = 14.0;

  /// Фирменный цвет (с иконки) — основа палитры, если нет цветов от обоев.
  static const seed = Color(0xFF7A3D8C);

  static HamTokens of(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = cs.brightness == Brightness.dark;
    final green = dark ? const Color(0xFF4CD787) : const Color(0xFF1B8A4B);
    final red = dark ? const Color(0xFFFF6B6B) : const Color(0xFFC62828);
    final amber = dark ? const Color(0xFFFFC857) : const Color(0xFF9A6B06);
    return HamTokens(
      bg: cs.surface,
      bgElev: cs.surfaceContainerHigh,
      bgSunken: cs.surfaceContainerHighest,
      border: cs.outlineVariant,
      borderStrong: cs.outline,
      text: cs.onSurface,
      textDim: cs.onSurfaceVariant,
      accent: cs.primary,
      accentFill: cs.primary,
      accentInk: cs.onPrimary,
      accentSoft: cs.primaryContainer,
      green: green,
      greenSoft: green.withValues(alpha: .16),
      red: red,
      redSoft: red.withValues(alpha: .14),
      amber: amber,
      amberSoft: amber.withValues(alpha: .16),
    );
  }
}

/// Карточка Material 3 (filled): мягкий фон, скругление, без тени.
class HamCard extends StatelessWidget {
  const HamCard({super.key, required this.child, this.borderColor, this.padding, this.margin});

  final Widget child;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final k = HamTokens.of(context);
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 12),
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: borderColor != null ? Color.alphaBlend(borderColor!.withValues(alpha: .10), k.bgElev) : k.bgElev,
        borderRadius: BorderRadius.circular(HamTokens.radius),
      ),
      child: child,
    );
  }
}

/// Точка статуса как .status-dot: цвет с мягким ореолом.
class HamStatusDot extends StatelessWidget {
  const HamStatusDot({super.key, required this.color, required this.soft});

  final Color color;
  final Color soft;

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: soft, spreadRadius: 3)],
    ),
  );
}

/// Плашка-сообщение (ошибка, успех).
class HamFlash extends StatelessWidget {
  const HamFlash({super.key, required this.text, required this.color, required this.soft});

  final String text;
  final Color color;
  final Color soft;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: soft,
      borderRadius: BorderRadius.circular(HamTokens.radiusSm),
    ),
    child: Text(text, style: TextStyle(color: color, fontSize: 15)),
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
