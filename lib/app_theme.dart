import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_storage_keys.dart';

/// Global so the Settings screen (pushed several routes below `MainApp`) can
/// change the app's theme without wiring a state-management dependency into
/// an app that otherwise just reads/writes SharedPreferences directly.
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);

Future<void> loadThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString(StorageKeys.themeMode);
  if (stored != null) {
    themeModeNotifier.value = ThemeMode.values.byName(stored);
  }
}

Future<void> setThemeMode(ThemeMode mode) async {
  themeModeNotifier.value = mode;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(StorageKeys.themeMode, mode.name);
}

/// The bundled fonts are under the SIL Open Font License, which requires
/// shipping its text with the fonts; this surfaces it on Flutter's licenses
/// page alongside the package licenses.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (font, file) in [('Nunito', 'OFL-Nunito.txt'), ('Baloo 2', 'OFL-Baloo2.txt')]) {
      final text = await rootBundle.loadString('assets/google_fonts/$file');
      yield LicenseEntryWithLineBreaks([font], text);
    }
  });
}

ThemeData buildLightTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF4A55C9),
    brightness: Brightness.light,
    secondary: const Color(0xFF7EC8BC),
    tertiary: const Color(0xFFD9A441),
    surface: const Color(0xFFFDF6F0),
  );
  // Soft rounded typeface for a warm, baby-friendly feel, with dark brown
  // body text tuned for the cream light background above.
  final textTheme = GoogleFonts.nunitoTextTheme(
    ThemeData.light().textTheme.apply(
          bodyColor: const Color(0xFF4A4038),
          displayColor: const Color(0xFF4A4038),
        ),
  );
  return _buildTheme(colorScheme, textTheme);
}

ThemeData buildDarkTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF4A55C9),
    brightness: Brightness.dark,
    secondary: const Color(0xFF7EC8BC),
    tertiary: const Color(0xFFD9A441),
  );
  // Unlike light mode, dark mode keeps Material 3's generated on-surface
  // color instead of a fixed override, since a single hardcoded text color
  // can't stay legible against every dark surface tone.
  final textTheme = GoogleFonts.nunitoTextTheme(ThemeData.dark().textTheme);
  return _buildTheme(colorScheme, textTheme);
}

/// Shared between light and dark mode — only the [colorScheme] and
/// [textTheme] differ; every widget-specific style below derives its colors
/// from the scheme so it adapts automatically.
ThemeData _buildTheme(ColorScheme colorScheme, TextTheme textTheme) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.baloo2(
        color: colorScheme.onPrimaryContainer,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
      ),
      elevation: 2,
      shadowColor: colorScheme.primary.withValues(alpha: 0.25),
      margin: const EdgeInsets.symmetric(vertical: 8),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: GoogleFonts.baloo2(fontSize: 17, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.primary,
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.4), width: 1.5),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: GoogleFonts.baloo2(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.primary,
        textStyle: GoogleFonts.baloo2(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.secondary,
      foregroundColor: colorScheme.onSecondary,
      extendedTextStyle: GoogleFonts.baloo2(fontSize: 16, fontWeight: FontWeight.w700),
      shape: const StadiumBorder(),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colorScheme.surfaceContainerHigh,
      indicatorColor: colorScheme.primaryContainer,
      elevation: 3,
      labelTextStyle: WidgetStatePropertyAll(
        GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      titleTextStyle: GoogleFonts.baloo2(
        color: colorScheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
