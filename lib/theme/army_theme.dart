import 'package:flutter/material.dart';
import 'army_colors.dart';

class ArmyTheme {
  static ThemeData get dark {
    final scheme = ColorScheme.dark(
      primary: ArmyColors.gold,
      onPrimary: ArmyColors.black,
      secondary: ArmyColors.green,
      onSecondary: ArmyColors.white,
      surface: ArmyColors.black,
      onSurface: ArmyNeutrals.gray100,
      error: const Color(0xFFCF6679),
      outline: ArmyNeutrals.gray500,
      inverseSurface: ArmyNeutrals.gray900,
      inversePrimary: ArmyColors.gold,
    );

    final baseText = Typography().white;
    final textTheme = baseText.copyWith(
      displayLarge: baseText.displayLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: ArmyColors.white,
      ),
      headlineLarge: baseText.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: ArmyColors.white,
      ),
      titleLarge: baseText.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: ArmyColors.white,
      ),
      bodyLarge: baseText.bodyLarge?.copyWith(color: ArmyNeutrals.gray100),
      bodyMedium: baseText.bodyMedium?.copyWith(color: ArmyNeutrals.gray200),
      bodySmall: baseText.bodySmall?.copyWith(color: ArmyNeutrals.gray300),
      labelLarge: baseText.labelLarge?.copyWith(color: ArmyNeutrals.gray100),
    );

    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: ArmyColors.black,
      textTheme: textTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ArmyNeutrals.gray900,
        hintStyle: const TextStyle(color: ArmyNeutrals.gray400),
        labelStyle: const TextStyle(color: ArmyNeutrals.gray300),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ArmyNeutrals.gray600, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ArmyNeutrals.gray600, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ArmyColors.gold, width: 1.5),
        ),
      ),
      cardTheme: CardTheme(
        color: ArmyColors.green.withOpacity(0.12),
        shadowColor: Colors.transparent,
        surfaceTintColor: ArmyColors.green,
        elevation: 0,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: ArmyNeutrals.gray700,
            width: 1,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ArmyColors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(
        color: ArmyNeutrals.gray700,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: ArmyColors.gold),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ArmyColors.gold,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return ArmyColors.gold;
          return ArmyNeutrals.gray600;
        }),
        checkColor: WidgetStateProperty.all(ArmyColors.black),
        side: BorderSide(color: ArmyNeutrals.gray600, width: 1),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.all(ArmyColors.gold),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? ArmyColors.gold
              : ArmyNeutrals.gray600;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? ArmyColors.gold.withOpacity(0.4)
              : ArmyNeutrals.gray700;
        }),
      ),
    );
  }
}
