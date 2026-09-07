import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: Colors.blue,
      fontFamily: 'NomNaTong',
    );
  }

  static ThemeData get midnight {
    // Keep midnight comfortably dark without using pure black.
    // The slightly lifted neutral surfaces reduce eye strain and make
    // cards, sheets, inputs and navigation easier to distinguish.
    const background = Color(0xFF121212);
    const surface = Color(0xFF181818);
    const surfaceLow = Color(0xFF1A1A1A);
    const surfaceContainer = Color(0xFF1D1D1D);
    const surfaceHigh = Color(0xFF212121);
    const raisedSurface = Color(0xFF262626);
    const border = Color(0xFF343434);

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B8CFF),
          brightness: Brightness.dark,
        ).copyWith(
          surface: surface,
          surfaceContainerLowest: background,
          surfaceContainerLow: surfaceLow,
          surfaceContainer: surfaceContainer,
          surfaceContainerHigh: surfaceHigh,
          surfaceContainerHighest: raisedSurface,
          onSurface: const Color(0xFFF2F2F2),
          onSurfaceVariant: const Color(0xFFC2C2C2),
          outline: const Color(0xFF666666),
          outlineVariant: border,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      fontFamily: 'NomNaTong',
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: Color(0xFFF2F2F2),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: const Color(0xFFA8A8A8),
        type: BottomNavigationBarType.fixed,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: raisedSurface,
        hintStyle: const TextStyle(color: Color(0xFF969696)),
        labelStyle: const TextStyle(color: Color(0xFFC2C2C2)),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: border),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF262626),
        contentTextStyle: TextStyle(color: Color(0xFFF2F2F2)),
      ),
    );
  }
}
