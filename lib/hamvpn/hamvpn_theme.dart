import 'package:flutter/material.dart';

/// Оформление ХамВПН — один в один с сайтом hamvpn.net (app/static/style.css):
/// тёмная тема по умолчанию, светлая — если светлая тема у телефона;
/// бирюзовый — действие, зелёный — работает, красный — остановлено, жёлтый — внимание.
@immutable
class HamTokens extends ThemeExtension<HamTokens> {
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

  static const radius = 12.0;
  static const radiusSm = 9.0;

  static const dark = HamTokens(
    bg: Color(0xFF0D1117),
    bgElev: Color(0xFF161D26),
    bgSunken: Color(0xFF0A0E14),
    border: Color(0xFF232C38),
    borderStrong: Color(0xFF35414F),
    text: Color(0xFFE8EEF5),
    textDim: Color(0xFF9FADBD),
    accent: Color(0xFF23C493),
    accentFill: Color(0xFF2EE0A6),
    accentInk: Color(0xFF04251B),
    accentSoft: Color(0x242EE0A6),
    green: Color(0xFF3FD67F),
    greenSoft: Color(0x263FD67F),
    red: Color(0xFFFF6B6F),
    redSoft: Color(0x26FF6B6F),
    amber: Color(0xFFFFC84A),
    amberSoft: Color(0x26FFC84A),
  );

  static const light = HamTokens(
    bg: Color(0xFFF5F8FA),
    bgElev: Color(0xFFFFFFFF),
    bgSunken: Color(0xFFEEF3F7),
    border: Color(0xFFDBE3EA),
    borderStrong: Color(0xFFC3CFDA),
    text: Color(0xFF16212D),
    textDim: Color(0xFF5A6A7A),
    accent: Color(0xFF0A7F5F),
    accentFill: Color(0xFF0A8F6A),
    accentInk: Color(0xFFFFFFFF),
    accentSoft: Color(0x1A0A8F6A),
    green: Color(0xFF0F8A48),
    greenSoft: Color(0x1F0F8A48),
    red: Color(0xFFC0392F),
    redSoft: Color(0x1FC0392F),
    amber: Color(0xFF9A6B06),
    amberSoft: Color(0x249A6B06),
  );

  static HamTokens of(BuildContext context) =>
      Theme.of(context).extension<HamTokens>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  HamTokens copyWith() => this;

  @override
  HamTokens lerp(covariant ThemeExtension<HamTokens>? other, double t) => t < .5 ? this : (other as HamTokens? ?? this);
}

/// Тема всего приложения на токенах сайта.
ThemeData buildHamTheme(HamTokens k, Brightness brightness, String fontFamily, List<ThemeExtension<dynamic>> extra) {
  final scheme = ColorScheme(
    brightness: brightness,
    primary: k.accentFill,
    onPrimary: k.accentInk,
    primaryContainer: k.accentSoft,
    onPrimaryContainer: k.accent,
    secondary: k.accent,
    onSecondary: k.accentInk,
    secondaryContainer: k.accentSoft,
    onSecondaryContainer: k.accent,
    tertiary: k.amber,
    onTertiary: k.bg,
    error: k.red,
    onError: Colors.white,
    errorContainer: k.redSoft,
    onErrorContainer: k.red,
    surface: k.bg,
    onSurface: k.text,
    onSurfaceVariant: k.textDim,
    surfaceContainerLowest: k.bgSunken,
    surfaceContainerLow: k.bgElev,
    surfaceContainer: k.bgElev,
    surfaceContainerHigh: k.bgElev,
    surfaceContainerHighest: k.bgSunken,
    outline: k.borderStrong,
    outlineVariant: k.border,
    shadow: Colors.black,
    inverseSurface: k.text,
    onInverseSurface: k.bg,
    inversePrimary: k.accent,
  );

  final smallShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(HamTokens.radiusSm));
  const buttonText = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: k.bg,
    canvasColor: k.bg,
    dividerColor: k.border,
    extensions: [k, ...extra],
    appBarTheme: AppBarTheme(
      backgroundColor: k.bgElev,
      surfaceTintColor: Colors.transparent,
      foregroundColor: k.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      shape: Border(bottom: BorderSide(color: k.border)),
      titleTextStyle: TextStyle(color: k.text, fontSize: 19, fontWeight: FontWeight.w700, fontFamily: fontFamily),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: k.bgElev,
      surfaceTintColor: Colors.transparent,
      indicatorColor: k.accentSoft,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12.5,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? k.accent : k.textDim,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? k.accent : k.textDim),
      ),
    ),
    cardTheme: CardThemeData(
      color: k.bgElev,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HamTokens.radius),
        side: BorderSide(color: k.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: k.accentFill,
        foregroundColor: k.accentInk,
        disabledBackgroundColor: k.accentFill.withValues(alpha: .5),
        disabledForegroundColor: k.accentInk.withValues(alpha: .7),
        minimumSize: const Size(44, 46),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: smallShape,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: k.text,
        backgroundColor: k.bgSunken,
        side: BorderSide(color: k.borderStrong),
        minimumSize: const Size(44, 46),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: smallShape,
        textStyle: buttonText.copyWith(fontWeight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: k.accent, textStyle: const TextStyle(fontWeight: FontWeight.w600)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: k.bgSunken,
      labelStyle: TextStyle(color: k.textDim),
      hintStyle: TextStyle(color: k.textDim),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HamTokens.radiusSm),
        borderSide: BorderSide(color: k.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HamTokens.radiusSm),
        borderSide: BorderSide(color: k.accent, width: 1.5),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HamTokens.radiusSm),
        borderSide: BorderSide(color: k.border),
      ),
    ),
    listTileTheme: ListTileThemeData(iconColor: k.textDim, textColor: k.text, subtitleTextStyle: TextStyle(color: k.textDim)),
    dividerTheme: DividerThemeData(color: k.border, space: 1, thickness: 1),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? k.accentInk : k.textDim),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? k.accentFill : k.bgSunken),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? k.accentFill : k.borderStrong,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: k.bgElev,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HamTokens.radius),
        side: BorderSide(color: k.border),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: k.bgElev, surfaceTintColor: Colors.transparent),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: k.bgElev,
      contentTextStyle: TextStyle(color: k.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HamTokens.radiusSm),
        side: BorderSide(color: k.border),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: k.accent),
    radioTheme: RadioThemeData(fillColor: WidgetStatePropertyAll(k.accentFill)),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? k.accentFill : null),
      checkColor: WidgetStatePropertyAll(k.accentInk),
    ),
  );
}

/// Карточка как .card на сайте: поверхность, рамка, скругление 12, отступ 20.
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
      margin: margin ?? const EdgeInsets.only(bottom: 16),
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: k.bgElev,
        borderRadius: BorderRadius.circular(HamTokens.radius),
        border: Border.all(color: borderColor ?? k.border),
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

/// Плашка-сообщение как .flash на сайте.
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
      border: Border.all(color: color),
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
