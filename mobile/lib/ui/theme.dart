import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';
import 'typography.dart';

/// Thèmes clair et sombre de Naatal Agro (direction « Apple »).
abstract final class NaatalTheme {
  static ThemeData get light => _build(NaatalColors.light, Brightness.light);
  static ThemeData get dark => _build(NaatalColors.dark, Brightness.dark);

  static ThemeData _build(NaatalColors c, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      secondary: c.slate,
      onSecondary: c.onAccent,
      error: c.clay,
      onError: c.onAccent,
      surface: c.surface,
      onSurface: c.ink,
    );

    final text = TextTheme(
      displayLarge: T.largeTitle(color: c.ink),
      headlineMedium: T.largeTitle(color: c.ink),
      titleLarge: T.title(color: c.ink),
      titleMedium: T.body(color: c.ink, weight: 700),
      bodyLarge: T.body(color: c.ink),
      bodyMedium: T.body(color: c.ink2),
      bodySmall: T.caption(color: c.ink2),
      labelLarge: T.body(color: c.ink, weight: 700),
      labelMedium: T.caption(color: c.ink2),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      fontFamily: T.family,
      textTheme: text,
      primaryTextTheme: text,
      extensions: [c],
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerColor: c.line,
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      }),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: Space.l, vertical: 18),
        hintStyle: T.body(color: c.ink2),
        labelStyle: T.caption(color: c.ink2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.m),
          borderSide: BorderSide(color: c.line, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.m),
          borderSide: BorderSide(color: c.line, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.m),
          borderSide: BorderSide(color: c.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.m),
          borderSide: BorderSide(color: c.clay, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.m),
          borderSide: BorderSide(color: c.clay, width: 2),
        ),
        errorStyle: T.caption(color: c.clay),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.isDark ? c.surfaceAlt : c.ink,
        contentTextStyle:
            T.body(color: c.isDark ? c.ink : c.bg, weight: 600),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.m)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.bg,
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.xl)),
        titleTextStyle: T.title(color: c.ink),
        contentTextStyle: T.body(color: c.ink2),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.surfaceAlt,
      ),
    );
  }
}
