import 'package:flutter/material.dart';

class AppColors {
  static const blue = Color(0xFF1558D6);
  static const blueDark = Color(0xFF0B2F7A);
  static const blueSoft = Color(0xFFE8F0FE);
  static const red = Color(0xFFE02B3C);
  static const redSoft = Color(0xFFFDE9EB);
  // fondul e vizibil mai inchis decat cardurile albe, ca sectiunile sa se
  // desprinda clar de el
  static const background = Color(0xFFD9E3F2);
  static const ink = Color(0xFF14213D);
  static const muted = Color(0xFF6B7890);
  static const line = Color(0xFFC6D2E6);

  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blue, blueDark],
  );
}

ThemeData buildAppTheme({FontWeight grosime = FontWeight.w400}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.blue,
    primary: AppColors.blue,
    secondary: AppColors.red,
    error: AppColors.red,
    surface: Colors.white,
  );
  final baza = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.blue,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      // umbra usoara ridica cardul de pe fond
      elevation: 2,
      shadowColor: AppColors.blueDark.withValues(alpha: 0.35),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    // bara de jos: fond albastru, text si iconite albe; sectiunea curenta se
    // distinge prin pastila mai deschisa si eticheta ingrosata
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.blue,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.white.withValues(alpha: 0.24),
      elevation: 8,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(fontSize: 11, color: Colors.white),
      ),
      iconTheme: const WidgetStatePropertyAll(
        IconThemeData(color: Colors.white),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 14),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      space: 1,
      thickness: 1,
    ),
  );
  // Doar titlurile de ecran si numele din carduri sunt ingrosate, iar ele isi
  // dau singure stilul. Textul obisnuit, etichetele si butoanele sunt cu
  // litera normala si cu un punct mai mici decat valorile implicite Material.
  TextStyle? normal(TextStyle? stil, double marime) =>
      stil?.copyWith(fontSize: marime, fontWeight: grosime);
  final t = baza.textTheme;
  return baza.copyWith(
    textTheme: t.copyWith(
      bodyLarge: normal(t.bodyLarge, 15),
      bodyMedium: normal(t.bodyMedium, 13),
      bodySmall: normal(t.bodySmall, 11.5),
      titleMedium: normal(t.titleMedium, 15),
      titleSmall: normal(t.titleSmall, 13),
      labelLarge: normal(t.labelLarge, 13),
      labelMedium: normal(t.labelMedium, 11.5),
      labelSmall: normal(t.labelSmall, 11),
      // titlul din bara paginilor urmeaza si el grosimea aleasa
      titleLarge: t.titleLarge?.copyWith(fontWeight: grosime),
    ),
  );
}

/// Paleta paginilor de lectura din Sinteză: hartie calda, cerneala moale si
/// accente stinse, ca textul lung sa nu oboseasca ochii.
class SintezaColors {
  static const hartie = Color(0xFFF4EFE6);
  static const card = Color(0xFFFBF8F2);
  static const cerneala = Color(0xFF2E2B27);
  static const estompat = Color(0xFF7A7268);
  static const linie = Color(0xFFE3DACB);
  static const legatura = Color(0xFF3F6B7D);

  static const psihiatrie = Color(0xFF7A5C86);
  static const siguranta = Color(0xFF9A4F5A);
  static const medicina = Color(0xFF5E8068);
  static const stiinta = Color(0xFF4F7190);
  static const arta = Color(0xFFB0694F);
  static const arhitectura = Color(0xFF857650);
  static const altele = Color(0xFF6F7A80);
}

/// Litera cu serife a textelor de citit; fiecare platforma o are pe a ei.
const fontLectura = 'Georgia';
const fontLecturaRezerve = ['Noto Serif', 'Times New Roman', 'serif'];
