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

// ─── Фирменные цвета, если они отличаются от приложения (админка — жёлтая) ──
class Brand extends ThemeExtension<Brand> {
  /// Фон главных кнопок и активных элементов.
  final Color taxi;
  final Color onTaxi;
  final Color taxiSoft;
  final Color jadeLine;

  /// Цвет акцентного текста и иконок на светлом фоне.
  final Color accent;
  final Color bg;
  final Color surface;
  final Color line;

  const Brand({
    required this.taxi,
    required this.onTaxi,
    required this.taxiSoft,
    required this.jadeLine,
    required this.accent,
    required this.bg,
    required this.surface,
    required this.line,
  });

  @override
  Brand copyWith() => this;

  @override
  Brand lerp(ThemeExtension<Brand>? other, double t) => this;
}

// Цвета из прототипа админки (reference/admin-prototype.html).
class AdminC {
  static const yellow     = Color(0xFFFFD12E);
  static const yellowSoft = Color(0xFFFFF6D1);
  static const yellowLine = Color(0xFFE8C14A);
  static const ink        = Color(0xFF111317);
  static const bg         = Color(0xFFF2F3F5);
  static const surface    = Color(0xFFF3F4F6);
  static const line       = Color(0xFFE6E8EB);
  static const side       = Color(0xFF101216);
  static const side2      = Color(0xFF1B1E24);
  static const sideText   = Color(0xFFC9CDD4);
  static const sideMuted  = Color(0xFF6E7480);
  static const ok         = Color(0xFF13A35A);
  static const warn       = Color(0xFFC26A00);
  static const bad        = Color(0xFFD93A3F);
  static const info       = Color(0xFF2B6CF6);
}

// ─── Расширение темы для доступа к кастомным цветам ────────────────────────
extension ThemeExtX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Brand? get _brand => Theme.of(this).extension<Brand>();
  Color get taxi    => _brand?.taxi ?? (isDark ? C.taxiDk    : C.taxi);
  Color get onTaxi  => _brand?.onTaxi ?? (isDark ? C.onTaxiDk  : C.onTaxi);
  Color get taxiSft => _brand?.taxiSoft ?? (isDark ? C.taxiSftDk : C.taxiSoft);
  Color get jLine   => _brand?.jadeLine ?? (isDark ? C.jadeLineDk: C.jadeLine);
  /// Акцентный текст и иконки (в приложении — зелёный, в админке — тёмный).
  Color get accent  => _brand?.accent ?? taxi;
  Color get okInk   => isDark ? C.okInkDk   : C.okInk;
  Color get paper   => isDark ? C.paperDk   : C.paper;
  Color get surface => _brand?.surface ?? (isDark ? C.surfDk    : C.surface);
  Color get lineC   => _brand?.line ?? (isDark ? C.lineDk    : C.line);
  Color get line2C  => isDark ? C.line2Dk   : C.line2;
  Color get ink     => isDark ? C.inkDk     : C.ink;
  Color get ink2    => isDark ? C.ink2Dk    : C.ink2;
  Color get muted   => isDark ? C.mutedDk   : C.muted;
  Color get hint    => isDark ? C.hintDk    : C.hint;
  Color get danger  => isDark ? C.dangerDk  : C.danger;
  Color get dSoft   => isDark ? C.dangerSftDk: C.dangerSoft;
  Color get gold    => isDark ? C.goldDk    : C.gold;
  Color get bg      => _brand?.bg ?? (isDark ? C.bgDk      : C.bg);
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

  /// Админка: жёлтый акцент и тёмное меню, как в прототипе.
  static ThemeData admin() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AdminC.bg,
    colorScheme: const ColorScheme.light(
      primary: AdminC.ink, onPrimary: Colors.white,
      surface: C.paper,
      secondary: AdminC.yellow, onSecondary: AdminC.ink,
    ),
    textTheme: _text(ThemeData.light().textTheme),
    appBarTheme: const AppBarTheme(backgroundColor: C.paper, foregroundColor: AdminC.ink),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AdminC.yellow,
        foregroundColor: AdminC.ink,
        textStyle: GoogleFonts.onest(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    extensions: const [
      Brand(
        taxi: AdminC.yellow,
        onTaxi: AdminC.ink,
        taxiSoft: AdminC.yellowSoft,
        jadeLine: AdminC.yellowLine,
        accent: AdminC.ink,
        bg: AdminC.bg,
        surface: AdminC.surface,
        line: AdminC.line,
      ),
    ],
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
