// The KnowYourRights design system.
//
// Semantic colour is the core rule: pine green carries calm authority, brass is
// used for one thing only (the Verified seal on lawyer-reviewed law), and red is
// used for one thing only (danger/emergency). Nothing decorative borrows them.
//
// Type pairs a bookish serif for titles (the voice of the law) with the platform
// sans for UI, and a monospace face for constitutional locators like "s.35(2)"
// so citations read as precise legal references.

import 'package:flutter/material.dart';

/// Font stacks. These are platform faces, so nothing is bundled: the first name
/// that exists on the device wins, ending in a generic family that always does.
const String kSerifFamily = 'Iowan Old Style';
const List<String> kSerifFallback = <String>[
  'Palatino',
  'Palatino Linotype',
  'Book Antiqua',
  'Georgia',
  'Times New Roman',
  'serif',
];
const String kMonoFamily = 'Menlo';
const List<String> kMonoFallback = <String>[
  'SF Mono',
  'Consolas',
  'Roboto Mono',
  'monospace',
];

/// Every colour in the system, themed light and dark.
@immutable
class KyrPalette extends ThemeExtension<KyrPalette> {
  final Color paper, canvas, card, card2;
  final Color ink, muted, faint, line;
  final Color green, greenDeep, greenTint, onGreen;
  final Color gold, goldTint, goldInk;
  final Color sos, sosDeep, sosTint, sosInk, onSos;

  const KyrPalette({
    required this.paper,
    required this.canvas,
    required this.card,
    required this.card2,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.line,
    required this.green,
    required this.greenDeep,
    required this.greenTint,
    required this.onGreen,
    required this.gold,
    required this.goldTint,
    required this.goldInk,
    required this.sos,
    required this.sosDeep,
    required this.sosTint,
    required this.sosInk,
    required this.onSos,
  });

  static const KyrPalette light = KyrPalette(
    paper: Color(0xFFF3EFE6),
    canvas: Color(0xFFEBE6D9),
    card: Color(0xFFFFFFFF),
    card2: Color(0xFFFBF8F1),
    ink: Color(0xFF17211B),
    muted: Color(0xFF5E6A61),
    faint: Color(0xFF8A938B),
    line: Color(0xFFE5DFD1),
    green: Color(0xFF124A34),
    greenDeep: Color(0xFF0E3B2A),
    greenTint: Color(0xFFE7F0EA),
    onGreen: Color(0xFFF6F3EA),
    gold: Color(0xFFA9792F),
    goldTint: Color(0xFFF2E8CF),
    goldInk: Color(0xFF7C561E),
    sos: Color(0xFFC23B2E),
    sosDeep: Color(0xFF9E2C21),
    sosTint: Color(0xFFFBEAE6),
    sosInk: Color(0xFF8E271D),
    onSos: Color(0xFFFDF3F0),
  );

  static const KyrPalette dark = KyrPalette(
    paper: Color(0xFF1B231E),
    canvas: Color(0xFF161D19),
    card: Color(0xFF242E28),
    card2: Color(0xFF2B352E),
    ink: Color(0xFFEEE9DD),
    muted: Color(0xFFA6B2A8),
    faint: Color(0xFF849388),
    line: Color(0xFF37423A),
    green: Color(0xFF4FA97B),
    greenDeep: Color(0xFF3D8A63),
    greenTint: Color(0xFF16241D),
    onGreen: Color(0xFF08110C),
    gold: Color(0xFFD8B65E),
    goldTint: Color(0xFF241E10),
    goldInk: Color(0xFFE6C979),
    sos: Color(0xFFE5695A),
    sosDeep: Color(0xFFC6483A),
    sosTint: Color(0xFF2A1613),
    sosInk: Color(0xFFF0A99E),
    onSos: Color(0xFF1A0C09),
  );

  @override
  KyrPalette copyWith() => this;

  // Themes switch discretely rather than cross-fading; a mid-point swap keeps the
  // semantic colours readable at every frame of the transition.
  @override
  KyrPalette lerp(ThemeExtension<KyrPalette>? other, double t) {
    if (other is! KyrPalette) return this;
    return t < 0.5 ? this : other;
  }
}

/// Read the palette from anywhere: `context.kyr.green`.
extension KyrTheme on BuildContext {
  KyrPalette get kyr => Theme.of(this).extension<KyrPalette>()!;
}

TextStyle serifStyle({
  double? size,
  FontWeight? weight,
  Color? color,
  double? height,
}) => TextStyle(
  fontFamily: kSerifFamily,
  fontFamilyFallback: kSerifFallback,
  fontSize: size,
  fontWeight: weight ?? FontWeight.w600,
  color: color,
  height: height,
  letterSpacing: -0.2,
);

TextStyle monoStyle({double? size, Color? color, FontWeight? weight}) =>
    TextStyle(
      fontFamily: kMonoFamily,
      fontFamilyFallback: kMonoFallback,
      fontSize: size ?? 12,
      fontWeight: weight,
      color: color,
    );

ThemeData buildKyrTheme(Brightness brightness) {
  final bool isDark = brightness == Brightness.dark;
  final KyrPalette p = isDark ? KyrPalette.dark : KyrPalette.light;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: p.paper,
    colorScheme: ColorScheme.fromSeed(
      seedColor: p.green,
      brightness: brightness,
      primary: p.green,
      onPrimary: p.onGreen,
      surface: p.card,
      onSurface: p.ink,
      error: p.sos,
      onError: p.onSos,
    ),
    extensions: <ThemeExtension<dynamic>>[p],
    textTheme: Typography.material2021(
      platform: TargetPlatform.iOS,
    ).black.apply(bodyColor: p.ink, displayColor: p.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: p.paper.withValues(alpha: 0.88),
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: p.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.line),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.card.withValues(alpha: 0.9),
      indicatorColor: p.greenTint,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected) ? p.green : p.faint,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? p.green : p.faint,
          size: 24,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.card,
      hintStyle: TextStyle(color: p.faint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.green, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.green,
        foregroundColor: p.onGreen,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.ink,
        side: BorderSide(color: p.line),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    dividerColor: p.line,
  );
}
