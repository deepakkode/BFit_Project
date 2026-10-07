import 'package:flutter/material.dart';

@immutable
class BFitPalette extends ThemeExtension<BFitPalette> {
  const BFitPalette({
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.ink,
    required this.muted,
    required this.line,
    required this.forest,
    required this.leaf,
    required this.citrus,
    required this.coral,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceRaised;
  final Color ink;
  final Color muted;
  final Color line;
  final Color forest;
  final Color leaf;
  final Color citrus;
  final Color coral;

  static const light = BFitPalette(
    canvas: Color(0xFFF4F1EA),
    surface: Color(0xFFFFFDF9),
    surfaceRaised: Color(0xFFEEE8DD),
    ink: Color(0xFF18332A),
    muted: Color(0xFF63766D),
    line: Color(0xFFE4DDD2),
    forest: Color(0xFF173B30),
    leaf: Color(0xFF438768),
    citrus: Color(0xFFD7F36A),
    coral: Color(0xFFB75F4D),
  );

  static const dark = BFitPalette(
    canvas: Color(0xFF101816),
    surface: Color(0xFF17211E),
    surfaceRaised: Color(0xFF202D29),
    ink: Color(0xFFEAF1EC),
    muted: Color(0xFFABB9B0),
    line: Color(0xFF2D3B36),
    forest: Color(0xFF173B30),
    leaf: Color(0xFF8CC4A6),
    citrus: Color(0xFFD7F36A),
    coral: Color(0xFFE49A84),
  );

  @override
  BFitPalette copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceRaised,
    Color? ink,
    Color? muted,
    Color? line,
    Color? forest,
    Color? leaf,
    Color? citrus,
    Color? coral,
  }) =>
      BFitPalette(
        canvas: canvas ?? this.canvas,
        surface: surface ?? this.surface,
        surfaceRaised: surfaceRaised ?? this.surfaceRaised,
        ink: ink ?? this.ink,
        muted: muted ?? this.muted,
        line: line ?? this.line,
        forest: forest ?? this.forest,
        leaf: leaf ?? this.leaf,
        citrus: citrus ?? this.citrus,
        coral: coral ?? this.coral,
      );

  @override
  BFitPalette lerp(ThemeExtension<BFitPalette>? other, double t) {
    if (other is! BFitPalette) return this;
    return BFitPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      forest: Color.lerp(forest, other.forest, t)!,
      leaf: Color.lerp(leaf, other.leaf, t)!,
      citrus: Color.lerp(citrus, other.citrus, t)!,
      coral: Color.lerp(coral, other.coral, t)!,
    );
  }
}

ThemeData bfitTheme(bool dark) {
  final palette = dark ? BFitPalette.dark : BFitPalette.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: palette.forest,
    brightness: dark ? Brightness.dark : Brightness.light,
    surface: palette.surface,
  ).copyWith(primary: palette.leaf, secondary: palette.citrus);
  return ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.canvas,
    extensions: [palette],
    fontFamily: 'sans-serif',
    textTheme: TextTheme(
      displayLarge: TextStyle(
        color: palette.ink,
        fontSize: 44,
        fontWeight: FontWeight.w700,
        letterSpacing: -2.2,
        height: 1.02,
      ),
      headlineMedium: TextStyle(
        color: palette.ink,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        height: 1.12,
      ),
      titleLarge: TextStyle(
        color: palette.ink,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      bodyLarge: TextStyle(color: palette.ink, fontSize: 16, height: 1.45),
      bodyMedium: TextStyle(color: palette.muted, fontSize: 14, height: 1.45),
      labelSmall: TextStyle(
        color: palette.muted,
        fontSize: 11,
        letterSpacing: 1.3,
        fontWeight: FontWeight.w700,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.canvas,
      foregroundColor: palette.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: palette.ink,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      hintStyle: TextStyle(color: palette.muted.withOpacity(0.76)),
      labelStyle: TextStyle(color: palette.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: palette.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: palette.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: palette.leaf, width: 1.5),
      ),
    ),
    dividerColor: palette.line,
  );
}

extension BFitThemeContext on BuildContext {
  BFitPalette get palette => Theme.of(this).extension<BFitPalette>()!;
}
