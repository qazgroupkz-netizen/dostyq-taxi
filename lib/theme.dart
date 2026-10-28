import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Цвета из прототипа ────────────────────────────────────────────────────
class C {
  // Светлая тема
  static const bg        = Color(0xFFF3F4F1);
  static const paper     = Color(0xFFFFFFFF);
  static const surface   = Color(0xFFECEEEA);
  static const line      = Color(0xFFE1E4DE);
  static const line2     = Color(0xFFCDD2CA);
  static const ink       = Color(0xFF14171F);
  static const ink2      = Color(0xFF2B303A);
  static const muted     = Color(0xFF5E6571);
  static const hint      = Color(0xFF7A818C);
  static const taxi      = Color(0xFF0E7C66);
  static const onTaxi    = Color(0xFFFFFFFF);
  static const taxiPress = Color(0xFF0B6A57);
  static const taxiSoft  = Color(0xFFE3F2EE);
  static const jadeLine  = Color(0xFF9FD3C5);
  static const okInk     = Color(0xFF0A5C4C);
  static const gold      = Color(0xFFC99A2E);
  static const danger    = Color(0xFFD93F44);
  static const dangerSoft= Color(0xFFFBE9EA);

  // Тёмная тема
  static const bgDk      = Color(0xFF0F1115);
  static const paperDk   = Color(0xFF181B21);
  static const surfDk    = Color(0xFF1F232A);
  static const lineDk    = Color(0xFF2A2F37);
  static const line2Dk   = Color(0xFF39404A);
  static const inkDk     = Color(0xFFF2F4F7);
  static const ink2Dk    = Color(0xFFD5DAE1);
  static const mutedDk   = Color(0xFFA3ABB6);
  static const hintDk    = Color(0xFF8A93A0);
  static const taxiDk    = Color(0xFF2DB896);
  static const onTaxiDk  = Color(0xFF06231C);
  static const taxiSftDk = Color(0xFF12302A);
  static const jadeLineDk= Color(0xFF24614F);
  static const okInkDk   = Color(0xFF7FDCC4);
  static const goldDk    = Color(0xFFE2B04A);
  static const dangerDk  = Color(0xFFF2555A);
  static const dangerSftDk= Color(0xFF3A1C1E);
}

// ─── Расширение темы для доступа к кастомным цветам ────────────────────────
extension ThemeExtX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get taxi    => isDark ? C.taxiDk    : C.taxi;
  Color get onTaxi  => isDark ? C.onTaxiDk  : C.onTaxi;
  Color get taxiSft => isDark ? C.taxiSftDk : C.taxiSoft;
  Color get jLine   => isDark ? C.jadeLineDk: C.jadeLine;
  Color get okInk   => isDark ? C.okInkDk   : C.okInk;
  Color get paper   => isDark ? C.paperDk   : C.paper;
  Color get surface => isDark ? C.surfDk    : C.surface;
  Color get lineC   => isDark ? C.lineDk    : C.line;
  Color get line2C  => isDark ? C.line2Dk   : C.line2;
  Color get ink     => isDark ? C.inkDk     : C.ink;
  Color get ink2    => isDark ? C.ink2Dk    : C.ink2;
  Color get muted   => isDark ? C.mutedDk   : C.muted;
  Color get hint    => isDark ? C.hintDk    : C.hint;
  Color get danger  => isDark ? C.dangerDk  : C.danger;
  Color get dSoft   => isDark ? C.dangerSftDk: C.dangerSoft;
  Color get gold    => isDark ? C.goldDk    : C.gold;
  Color get bg      => isDark ? C.bgDk      : C.bg;
}

// ─── Темы приложения ────────────────────────────────────────────────────────
class AppTheme {
  static TextTheme _text(TextTheme base) =>
      GoogleFonts.onestTextTheme(base).copyWith(
        bodyLarge:  GoogleFonts.onest(fontSize: 16, fontWeight: FontWeight.w400),
        bodyMedium: GoogleFonts.onest(fontSize: 14, fontWeight: FontWeight.w400),
        labelLarge: GoogleFonts.onest(fontSize: 16, fontWeight: FontWeight.w700),
      );

  static ThemeData light() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: C.bg,
    colorScheme: const ColorScheme.light(
      primary: C.taxi, onPrimary: C.onTaxi,
      surface: C.paper,
      secondary: C.taxi,
    ),
    textTheme: _text(ThemeData.light().textTheme),
    appBarTheme: const AppBarTheme(backgroundColor: C.paper, foregroundColor: C.ink),
  );

  static ThemeData dark() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: C.bgDk,
    colorScheme: const ColorScheme.dark(
      primary: C.taxiDk, onPrimary: C.onTaxiDk,
      surface: C.paperDk,
      secondary: C.taxiDk,
    ),
    textTheme: _text(ThemeData.dark().textTheme),
    appBarTheme: const AppBarTheme(backgroundColor: C.paperDk, foregroundColor: C.inkDk),
  );
}
