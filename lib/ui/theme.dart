import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xff4788ff),
        brightness: brightness,
      ).copyWith(
        primary: dark ? const Color(0xff91bbff) : const Color(0xff215ed4),
        onPrimary: dark ? const Color(0xff04162f) : Colors.white,
        secondary: dark ? const Color(0xff8ae1ef) : const Color(0xff126d83),
        surface: dark ? const Color(0xff0e1b33) : const Color(0xfff5f8ff),
        surfaceContainerLow: dark
            ? const Color(0xff12223e)
            : const Color(0xffeaf0fc),
        surfaceContainerHigh: dark
            ? const Color(0xff1a2d4a)
            : const Color(0xffe3ebfa),
        surfaceContainerHighest: dark
            ? const Color(0xff223651)
            : const Color(0xffdae5f8),
        onSurface: dark ? const Color(0xfff0f5ff) : const Color(0xff142541),
        onSurfaceVariant: dark
            ? const Color(0xffb0c2de)
            : const Color(0xff526680),
        outline: dark ? const Color(0xff6582aa) : const Color(0xff859bb8),
        outlineVariant: dark
            ? const Color(0xff304764)
            : const Color(0xffc3d1e8),
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    // Preserve smooth input on lower-end Android devices and avoid relying on
    // Material's extra InkSparkle shader. This is separate from glass shader.
    splashFactory: InkRipple.splashFactory,
  );
  final text = base.textTheme
      .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface)
      .copyWith(
        headlineMedium: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w600,
          letterSpacing: -.9,
          height: 1.2,
          color: scheme.onSurface,
        ),
        titleLarge: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w600,
          letterSpacing: -.45,
          color: scheme.onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.25,
          color: scheme.onSurface,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: scheme.onSurfaceVariant,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.5,
          color: scheme.onSurface,
        ),
      );
  final outline = scheme.onSurface.withValues(alpha: dark ? 0.13 : .12);
  final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(24));
  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      systemOverlayStyle:
          (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
              .copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: dark
                    ? const Color(0xff071329)
                    : const Color(0xffedf3ff),
                systemNavigationBarIconBrightness: dark
                    ? Brightness.light
                    : Brightness.dark,
              ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.onSurface.withValues(alpha: .045),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 1.4),
      ),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surface.withValues(alpha: dark ? 0.64 : .86),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: outline),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: dark ? const Color(0xff407cf0) : scheme.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: pill,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        minimumSize: const Size(48, 48),
        side: BorderSide(color: scheme.primary.withValues(alpha: .32)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: pill,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        minimumSize: const Size(44, 44),
        shape: pill,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: scheme.onSurfaceVariant,
        minimumSize: const Size(44, 44),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: scheme.primary.withValues(alpha: .09),
      side: BorderSide(color: scheme.primary.withValues(alpha: .18)),
      shape: pill,
      labelStyle: TextStyle(
        color: scheme.primary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: .8,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      height: 68,
      indicatorColor: scheme.primary.withValues(alpha: .16),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
      ),
    ),
    dividerTheme: DividerThemeData(color: outline, thickness: .6),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(
        scheme.primary.withValues(alpha: .07),
      ),
      headingTextStyle: TextStyle(
        color: scheme.onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      dataTextStyle: TextStyle(color: scheme.onSurface, fontSize: 13),
      horizontalMargin: 20,
      columnSpacing: 26,
      dataRowMinHeight: 52,
      dataRowMaxHeight: 96,
      dividerThickness: .5,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: outline),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? const Color(0xff223a60) : const Color(0xff163961),
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.primary.withValues(alpha: .1),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: outline),
      ),
      textStyle: TextStyle(color: scheme.onSurface, fontSize: 12),
    ),
  );
}
