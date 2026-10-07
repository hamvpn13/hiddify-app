import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:hiddify/hamvpn/hamvpn_theme.dart';

// Кнопка подключения: красная — выключено, зелёная — подключено.
const _hamConnectionDark = ConnectionButtonTheme(idleColor: Color(0xFFE5484D), connectedColor: Color(0xFF2FB463));
const _hamConnectionLight = ConnectionButtonTheme(idleColor: Color(0xFFD93A3F), connectedColor: Color(0xFF1E9E52));

class AppTheme {
  AppTheme(this.mode, this.fontFamily);
  final AppThemeMode mode;
  final String fontFamily;

  // ХамВПН: стандартный Material 3 — цвета от обоев телефона (Material You),
  // если их нет — из фирменного цвета иконки.
  ThemeData lightTheme(ColorScheme? lightColorScheme) => _build(
    lightColorScheme?.harmonized() ?? ColorScheme.fromSeed(seedColor: HamTokens.seed),
    _hamConnectionLight,
  );

  ThemeData darkTheme(ColorScheme? darkColorScheme) => _build(
    darkColorScheme?.harmonized() ??
        ColorScheme.fromSeed(seedColor: HamTokens.seed, brightness: Brightness.dark),
    _hamConnectionDark,
  );

  ThemeData _build(ColorScheme scheme, ConnectionButtonTheme connection) => ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: mode.trueBlack && scheme.brightness == Brightness.dark ? Colors.black : scheme.surface,
    extensions: <ThemeExtension<dynamic>>{connection},
    navigationBarTheme: const NavigationBarThemeData(height: 72),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(48, 48), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    ),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
  );

  CupertinoThemeData cupertinoThemeData(bool sysDark, ColorScheme? lightColorScheme, ColorScheme? darkColorScheme) {
    final bool isDark = switch (mode) {
      AppThemeMode.system => sysDark,
      AppThemeMode.light => false,
      AppThemeMode.dark => true,
      AppThemeMode.black => true,
    };
    final def = CupertinoThemeData(brightness: isDark ? Brightness.dark : Brightness.light);
    // final def = CupertinoThemeData(brightness: Brightness.dark);

    // return def;
    final defaultMaterialTheme = isDark ? darkTheme(darkColorScheme) : lightTheme(lightColorScheme);
    return MaterialBasedCupertinoThemeData(
      materialTheme: defaultMaterialTheme.copyWith(
        cupertinoOverrideTheme: def.copyWith(
          textTheme: CupertinoTextThemeData(
            textStyle: def.textTheme.textStyle.copyWith(fontFamily: fontFamily),
            actionTextStyle: def.textTheme.actionTextStyle.copyWith(fontFamily: fontFamily),
            navActionTextStyle: def.textTheme.navActionTextStyle.copyWith(fontFamily: fontFamily),
            navTitleTextStyle: def.textTheme.navTitleTextStyle.copyWith(fontFamily: fontFamily),
            navLargeTitleTextStyle: def.textTheme.navLargeTitleTextStyle.copyWith(fontFamily: fontFamily),
            pickerTextStyle: def.textTheme.pickerTextStyle.copyWith(fontFamily: fontFamily),
            dateTimePickerTextStyle: def.textTheme.dateTimePickerTextStyle.copyWith(fontFamily: fontFamily),
            tabLabelTextStyle: def.textTheme.tabLabelTextStyle.copyWith(fontFamily: fontFamily),
          ).copyWith(),
          barBackgroundColor: def.barBackgroundColor,
          scaffoldBackgroundColor: def.scaffoldBackgroundColor,
        ),
      ),
    );
  }
}
