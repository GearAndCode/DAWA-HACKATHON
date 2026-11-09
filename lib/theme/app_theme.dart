import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class C {
  static const indigo = Color(0xFF312E81);
  static const purple = Color(0xFF6D28D9);
  static const violet = Color(0xFF8B5CF6);
  static const lavender = Color(0xFFA78BFA);
  static const white = Color(0xFFFFFFFF);
  static const bg = Color(0xFFF8F7FC);
  static const light = Color(0xFFF1EDFF);
  static const text = Color(0xFF211E3B);
  static const sub = Color(0xFF77758A);
  static const border = Color(0xFFE9E6F0);
  static const green = Color(0xFF24845A);

  static Color a(Color c, double o) => c.withAlpha((o * 255).round());
}

TextStyle t(double size,
        {FontWeight w = FontWeight.w400,
        Color c = C.text,
        double h = 1.4,
        double? ls}) =>
    GoogleFonts.inter(
        fontSize: size, fontWeight: w, color: c, height: h, letterSpacing: ls);

TextStyle ar(double size,
        {FontWeight w = FontWeight.w500, Color c = C.text, double h = 1.6}) =>
    GoogleFonts.notoSansArabic(
        fontSize: size, fontWeight: w, color: c, height: h);

const List<BoxShadow> softShadow = [
  BoxShadow(color: Color(0x14312E81), blurRadius: 24, offset: Offset(0, 8)),
];

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
        seedColor: C.purple, primary: C.purple, surface: C.white),
    scaffoldBackgroundColor: C.bg,
  );
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme)
        .apply(bodyColor: C.text, displayColor: C.text),
    appBarTheme: AppBarTheme(
      backgroundColor: C.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: C.text),
      titleTextStyle: t(20, w: FontWeight.w700),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.purple,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: C.purple,
        minimumSize: const Size(0, 52),
        side: const BorderSide(color: C.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
