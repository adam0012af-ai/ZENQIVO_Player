import 'package:flutter/material.dart';

abstract final class ZenqivoColors {
  static const background = Color(0xFF070707);
  static const surface = Color(0xFF111111);
  static const surfaceRaised = Color(0xFF191919);
  static const gold = Color(0xFFD4AF37);
  static const goldSoft = Color(0xFFF2D77A);
  static const text = Color(0xFFF7F4EA);
  static const muted = Color(0xFFA8A8A8);
  static const danger = Color(0xFFE65A5A);
}

abstract final class ZenqivoTheme {
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: ZenqivoColors.gold,
      brightness: Brightness.dark,
      surface: ZenqivoColors.surface,
    );

    ButtonStyle focusButtonStyle({
      Color? background,
      Color? foreground,
    }) {
      return ButtonStyle(
        backgroundColor: background == null
            ? null
            : WidgetStatePropertyAll(background),
        foregroundColor: foreground == null
            ? null
            : WidgetStatePropertyAll(foreground),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return const BorderSide(
              color: ZenqivoColors.gold,
              width: 2,
            );
          }
          return BorderSide.none;
        }),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return const Color(0x22D4AF37);
          }
          return null;
        }),
      );
    }

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: scheme.copyWith(
        primary: ZenqivoColors.gold,
        secondary: ZenqivoColors.goldSoft,
        surface: ZenqivoColors.surface,
      ),
      scaffoldBackgroundColor: ZenqivoColors.background,
      focusColor: const Color(0x33D4AF37),
      hoverColor: const Color(0x1AD4AF37),
      highlightColor: const Color(0x22D4AF37),
      splashColor: const Color(0x22D4AF37),
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ZenqivoColors.surfaceRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: ZenqivoColors.gold,
            width: 2,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        selectedColor: ZenqivoColors.goldSoft,
        selectedTileColor: const Color(0xFF302812),
        iconColor: ZenqivoColors.muted,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        indicatorColor: Color(0xFF3A3214),
        selectedIconTheme: IconThemeData(
          color: ZenqivoColors.gold,
        ),
        selectedLabelTextStyle: TextStyle(
          color: ZenqivoColors.goldSoft,
          fontWeight: FontWeight.w800,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: focusButtonStyle(),
      ),
      textButtonTheme: TextButtonThemeData(
        style: focusButtonStyle(),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: focusButtonStyle(),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return const BorderSide(
                color: ZenqivoColors.gold,
                width: 2,
              );
            }
            return BorderSide.none;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return const Color(0xFF302812);
            }
            return null;
          }),
        ),
      ),
    );
  }
}
