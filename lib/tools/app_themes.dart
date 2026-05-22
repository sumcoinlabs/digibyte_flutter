import 'package:flutter/material.dart';

class MyTheme {
  static Map<ThemeMode, ThemeData> appThemes = {
    ThemeMode.light: ThemeData(
      useMaterial3: false,
      brightness: Brightness.light,
      scaffoldBackgroundColor: LightColors.background,
      cardColor: LightColors.card,
      dialogBackgroundColor: LightColors.card,
      disabledColor: LightColors.lightGrey,
      dividerColor: LightColors.primaryBlue,
      focusColor: LightColors.primaryBlue,
      hintColor: LightColors.secondaryText,
      primaryColor: LightColors.primaryBlue,
      shadowColor: LightColors.background,
      unselectedWidgetColor: LightColors.secondaryText,
      iconTheme: IconThemeData(color: LightColors.primaryBlue),
      appBarTheme: AppBarTheme(
        color: LightColors.primaryBlue,
        foregroundColor: LightColors.onPrimary,
        iconTheme: IconThemeData(color: LightColors.onPrimary),
        titleTextStyle: TextStyle(
          color: LightColors.onPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      textTheme: TextTheme(
        titleLarge: TextStyle(color: LightColors.primaryText),
        titleMedium: TextStyle(color: LightColors.primaryText),
        titleSmall: TextStyle(color: LightColors.primaryText),
        bodyLarge: TextStyle(color: LightColors.primaryText),
        bodyMedium: TextStyle(color: LightColors.primaryText),
        bodySmall: TextStyle(color: LightColors.secondaryText),
        labelLarge: TextStyle(
          letterSpacing: 1.4,
          fontSize: 16,
          color: LightColors.onPrimary,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: LightColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: LightColors.lightGrey,
        color: LightColors.card,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: LightColors.primaryBlue,
        contentTextStyle: TextStyle(color: LightColors.onPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: LightColors.onPrimary,
          backgroundColor: LightColors.primaryBlue,
          disabledForegroundColor: LightColors.secondaryText,
          disabledBackgroundColor: LightColors.lightGrey,
          textStyle: const TextStyle(
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: LightColors.primaryBlue,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: LightColors.primaryBlue,
        thumbColor: LightColors.primaryBlue,
        valueIndicatorTextStyle: TextStyle(
          color: LightColors.onPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return LightColors.onPrimary;
          }
          return LightColors.primaryBlue;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return LightColors.primaryBlue;
          }
          return LightColors.lightGrey;
        }),
        trackOutlineColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return LightColors.primaryBlue;
          }
          return LightColors.secondaryText;
        }),
      ),
      colorScheme: ColorScheme(
        primary: LightColors.primaryBlue,
        primaryContainer: LightColors.primaryBlueDark,
        secondary: LightColors.secondaryText,
        secondaryContainer: LightColors.lightGrey,
        surface: LightColors.card,
        background: LightColors.background,
        onPrimary: LightColors.onPrimary,
        onSecondary: LightColors.primaryText,
        onSurface: LightColors.primaryText,
        onBackground: LightColors.primaryText,
        error: LightColors.danger,
        onError: LightColors.onPrimary,
        brightness: Brightness.light,
        tertiary: LightColors.warning,
      ),
      bottomAppBarTheme: BottomAppBarTheme(color: LightColors.background),
    ),
    ThemeMode.dark: ThemeData.dark().copyWith(
      useMaterial3: false,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: DarkColors.background,
      cardColor: DarkColors.card,
      dialogBackgroundColor: DarkColors.card,
      disabledColor: DarkColors.disabled,
      dividerColor: DarkColors.primaryBlue,
      focusColor: DarkColors.primaryBlue,
      hintColor: DarkColors.secondaryText,
      primaryColor: DarkColors.primaryBlue,
      shadowColor: DarkColors.background,
      unselectedWidgetColor: DarkColors.secondaryText,
      iconTheme: IconThemeData(color: DarkColors.primaryText),
      appBarTheme: AppBarTheme(
        color: DarkColors.primaryBlue,
        foregroundColor: DarkColors.onPrimary,
        iconTheme: IconThemeData(color: DarkColors.onPrimary),
        titleTextStyle: TextStyle(
          color: DarkColors.onPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      textTheme: TextTheme(
        titleLarge: TextStyle(color: DarkColors.primaryText),
        headlineSmall: TextStyle(color: DarkColors.primaryText),
        headlineMedium: TextStyle(color: DarkColors.primaryText),
        displaySmall: TextStyle(color: DarkColors.primaryText),
        displayMedium: TextStyle(color: DarkColors.primaryText),
        displayLarge: TextStyle(color: DarkColors.primaryText),
        titleMedium: TextStyle(color: DarkColors.primaryText),
        titleSmall: TextStyle(color: DarkColors.primaryText),
        bodyLarge: TextStyle(color: DarkColors.primaryText),
        bodyMedium: TextStyle(color: DarkColors.primaryText),
        bodySmall: TextStyle(color: DarkColors.secondaryText),
        labelLarge: TextStyle(
          letterSpacing: 1.4,
          fontSize: 16,
          color: DarkColors.onPrimary,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: DarkColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: DarkColors.card,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: DarkColors.card,
        contentTextStyle: TextStyle(color: DarkColors.primaryText),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: DarkColors.onPrimary,
          backgroundColor: DarkColors.primaryBlue,
          disabledForegroundColor: DarkColors.secondaryText,
          disabledBackgroundColor: DarkColors.disabled,
          textStyle: const TextStyle(
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DarkColors.primaryText,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: TextStyle(color: DarkColors.primaryText),
        hintStyle: TextStyle(color: DarkColors.secondaryText),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: DarkColors.primaryBlue),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: DarkColors.secondaryText),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: DarkColors.primaryText,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: DarkColors.primaryBlue,
        thumbColor: DarkColors.primaryBlue,
        valueIndicatorColor: DarkColors.primaryBlue,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return DarkColors.onPrimary;
          }
          return DarkColors.secondaryText;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return DarkColors.primaryBlue;
          }
          return DarkColors.disabled;
        }),
        trackOutlineColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return DarkColors.primaryBlue;
          }
          return DarkColors.secondaryText;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.all(DarkColors.primaryBlue),
        checkColor: MaterialStateProperty.all(DarkColors.onPrimary),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: DarkColors.primaryText,
        collapsedIconColor: DarkColors.primaryText,
      ),
      colorScheme: ColorScheme(
        primary: DarkColors.primaryBlue,
        primaryContainer: DarkColors.primaryText,
        secondary: DarkColors.primaryText,
        secondaryContainer: DarkColors.secondaryText,
        surface: DarkColors.card,
        background: DarkColors.background,
        onPrimary: DarkColors.onPrimary,
        onSecondary: DarkColors.background,
        onSurface: DarkColors.primaryText,
        onBackground: DarkColors.primaryText,
        error: DarkColors.danger,
        onError: DarkColors.onPrimary,
        brightness: Brightness.dark,
        tertiary: DarkColors.warning,
      ),
      bottomAppBarTheme: BottomAppBarTheme(color: DarkColors.background),
    ),
  };

  static ThemeData getTheme(ThemeMode mode) {
    return appThemes[mode] ?? appThemes[ThemeMode.light]!;
  }

  static MaterialColor materialColor(Color color) {
    return MaterialColor(
      color.value,
      <int, Color>{
        50: color,
        100: color,
        200: color,
        300: color,
        400: color,
        500: color,
        600: color,
        700: color,
        800: color,
        900: color,
      },
    );
  }
}

abstract class LightColors {
  static Color get black => const Color(0xFF000000);
  static Color get white => const Color(0xFFFAFAFA);

  static Color get primaryBlue => const Color(0xFF2057A8);
  static Color get primaryBlueDark => const Color(0xFF17457F);
  static Color get background => const Color(0xFFFAFAFA);
  static Color get card => const Color(0xFFFFFFFF);
  static Color get primaryText => const Color(0xFF111827);
  static Color get secondaryText => const Color(0xFF5F6B7A);
  static Color get lightGrey => const Color(0xFFE6EAF0);
  static Color get danger => const Color(0xFFD9534F);
  static Color get success => const Color(0xFF2EAD4F);
  static Color get warning => const Color(0xFFFFBF46);
  static Color get onPrimary => const Color(0xFFFFFFFF);

  // Backward-compatible names used throughout the app.
  static Color get blackGreen => primaryText;
  static Color get darkGreen => primaryBlueDark;
  static Color get green => primaryBlue;
  static Color get lightGreen => background;
  static Color get grey => secondaryText;
  static Color get red => danger;
  static Color get yellow => warning;
}

abstract class DarkColors {
  static Color get black => const Color(0xFF0D1821);
  static Color get white => const Color(0xFFFAFAFA);

  static Color get primaryBlue => const Color(0xFF2057A8);
  static Color get background => const Color(0xFF0D1821);
  static Color get card => const Color(0xFF183042);
  static Color get disabled => const Color(0xFF243447);
  static Color get primaryText => const Color(0xFFF5F7FA);
  static Color get secondaryText => const Color(0xFFB7C0CC);
  static Color get danger => const Color(0xFFD9534F);
  static Color get success => const Color(0xFF2EAD4F);
  static Color get warning => const Color(0xFFFFBF46);
  static Color get onPrimary => const Color(0xFFFFFFFF);

  // Backward-compatible names used throughout the app.
  static Color get darkGreen => const Color(0xFF102E44);
  static Color get green => primaryBlue;
  static Color get lightGreen => const Color(0xFFB7C0CC);
  static Color get darkBlue => card;
  static Color get grey => secondaryText;
  static Color get red => danger;
}
