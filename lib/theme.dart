import "package:flutter/material.dart";

class MaterialTheme {
  final TextTheme textTheme;

  const MaterialTheme(this.textTheme);

  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff8e4958),
      surfaceTint: Color(0xff8e4958),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xffffd9de),
      onPrimaryContainer: Color(0xff713341),
      secondary: Color(0xff4d5c92),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xffdce1ff),
      onSecondaryContainer: Color(0xff354479),
      tertiary: Color(0xff7a5832),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xffffdcbb),
      onTertiaryContainer: Color(0xff5f401d),
      error: Color(0xffba1a1a),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffffdad6),
      onErrorContainer: Color(0xff93000a),
      surface: Color(0xfffff8f7),
      onSurface: Color(0xff22191b),
      onSurfaceVariant: Color(0xff524345),
      outline: Color(0xff847375),
      outlineVariant: Color(0xffd6c2c4),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff382e2f),
      inversePrimary: Color(0xffffb2bf),
      primaryFixed: Color(0xffffd9de),
      onPrimaryFixed: Color(0xff3a0717),
      primaryFixedDim: Color(0xffffb2bf),
      onPrimaryFixedVariant: Color(0xff713341),
      secondaryFixed: Color(0xffdce1ff),
      onSecondaryFixed: Color(0xff04164b),
      secondaryFixedDim: Color(0xffb6c4ff),
      onSecondaryFixedVariant: Color(0xff354479),
      tertiaryFixed: Color(0xffffdcbb),
      onTertiaryFixed: Color(0xff2c1700),
      tertiaryFixedDim: Color(0xffebbe90),
      onTertiaryFixedVariant: Color(0xff5f401d),
      surfaceDim: Color(0xffe7d6d7),
      surfaceBright: Color(0xfffff8f7),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfffff0f1),
      surfaceContainer: Color(0xfffbeaeb),
      surfaceContainerHigh: Color(0xfff5e4e6),
      surfaceContainerHighest: Color(0xfff0dee0),
    );
  }

  ThemeData light() {
    return theme(lightScheme());
  }

  static ColorScheme lightMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff5d2231),
      surfaceTint: Color(0xff8e4958),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff9f5867),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff243367),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff5c6aa2),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff4c300e),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff8a663f),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff740006),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffcf2c27),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfffff8f7),
      onSurface: Color(0xff170f10),
      onSurfaceVariant: Color(0xff403335),
      outline: Color(0xff5e4f51),
      outlineVariant: Color(0xff7a696b),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff382e2f),
      inversePrimary: Color(0xffffb2bf),
      primaryFixed: Color(0xff9f5867),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff82404f),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff5c6aa2),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff445288),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff8a663f),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff6f4e29),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffd3c3c4),
      surfaceBright: Color(0xfffff8f7),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfffff0f1),
      surfaceContainer: Color(0xfff5e4e6),
      surfaceContainerHigh: Color(0xffead9da),
      surfaceContainerHighest: Color(0xffdececf),
    );
  }

  ThemeData lightMediumContrast() {
    return theme(lightMediumContrastScheme());
  }

  static ColorScheme lightHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff501827),
      surfaceTint: Color(0xff8e4958),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff743543),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff19285c),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff38467b),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff412605),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff62431f),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff600004),
      onError: Color(0xffffffff),
      errorContainer: Color(0xff98000a),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfffff8f7),
      onSurface: Color(0xff000000),
      onSurfaceVariant: Color(0xff000000),
      outline: Color(0xff36292b),
      outlineVariant: Color(0xff544548),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff382e2f),
      inversePrimary: Color(0xffffb2bf),
      primaryFixed: Color(0xff743543),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff581f2d),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff38467b),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff202f63),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff62431f),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff482d0a),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffc5b5b6),
      surfaceBright: Color(0xfffff8f7),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfffeedee),
      surfaceContainer: Color(0xfff0dee0),
      surfaceContainerHigh: Color(0xffe1d0d2),
      surfaceContainerHighest: Color(0xffd3c3c4),
    );
  }

  ThemeData lightHighContrast() {
    return theme(lightHighContrastScheme());
  }

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffffb2bf),
      surfaceTint: Color(0xffffb2bf),
      onPrimary: Color(0xff561d2b),
      primaryContainer: Color(0xff713341),
      onPrimaryContainer: Color(0xffffd9de),
      secondary: Color(0xffb6c4ff),
      onSecondary: Color(0xff1e2d61),
      secondaryContainer: Color(0xff354479),
      onSecondaryContainer: Color(0xffdce1ff),
      tertiary: Color(0xffebbe90),
      onTertiary: Color(0xff462a08),
      tertiaryContainer: Color(0xff5f401d),
      onTertiaryContainer: Color(0xffffdcbb),
      error: Color(0xffffb4ab),
      onError: Color(0xff690005),
      errorContainer: Color(0xff93000a),
      onErrorContainer: Color(0xffffdad6),
      surface: Color(0xff191113),
      onSurface: Color(0xfff0dee0),
      onSurfaceVariant: Color(0xffd6c2c4),
      outline: Color(0xff9f8c8e),
      outlineVariant: Color(0xff524345),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xfff0dee0),
      inversePrimary: Color(0xff8e4958),
      primaryFixed: Color(0xffffd9de),
      onPrimaryFixed: Color(0xff3a0717),
      primaryFixedDim: Color(0xffffb2bf),
      onPrimaryFixedVariant: Color(0xff713341),
      secondaryFixed: Color(0xffdce1ff),
      onSecondaryFixed: Color(0xff04164b),
      secondaryFixedDim: Color(0xffb6c4ff),
      onSecondaryFixedVariant: Color(0xff354479),
      tertiaryFixed: Color(0xffffdcbb),
      onTertiaryFixed: Color(0xff2c1700),
      tertiaryFixedDim: Color(0xffebbe90),
      onTertiaryFixedVariant: Color(0xff5f401d),
      surfaceDim: Color(0xff191113),
      surfaceBright: Color(0xff413738),
      surfaceContainerLowest: Color(0xff140c0d),
      surfaceContainerLow: Color(0xff22191b),
      surfaceContainer: Color(0xff261d1f),
      surfaceContainerHigh: Color(0xff312829),
      surfaceContainerHighest: Color(0xff3c3234),
    );
  }

  ThemeData dark() {
    return theme(darkScheme());
  }

  static ColorScheme darkMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffffd1d8),
      surfaceTint: Color(0xffffb2bf),
      onPrimary: Color(0xff481221),
      primaryContainer: Color(0xffc87a8a),
      onPrimaryContainer: Color(0xff000000),
      secondary: Color(0xffd4dbff),
      onSecondary: Color(0xff112255),
      secondaryContainer: Color(0xff808ec8),
      onSecondaryContainer: Color(0xff000000),
      tertiary: Color(0xffffd5ab),
      onTertiary: Color(0xff392001),
      tertiaryContainer: Color(0xffb1895f),
      onTertiaryContainer: Color(0xff000000),
      error: Color(0xffffd2cc),
      onError: Color(0xff540003),
      errorContainer: Color(0xffff5449),
      onErrorContainer: Color(0xff000000),
      surface: Color(0xff191113),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffedd7d9),
      outline: Color(0xffc1adaf),
      outlineVariant: Color(0xff9e8c8e),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xfff0dee0),
      inversePrimary: Color(0xff733442),
      primaryFixed: Color(0xffffd9de),
      onPrimaryFixed: Color(0xff2c000d),
      primaryFixedDim: Color(0xffffb2bf),
      onPrimaryFixedVariant: Color(0xff5d2231),
      secondaryFixed: Color(0xffdce1ff),
      onSecondaryFixed: Color(0xff000c39),
      secondaryFixedDim: Color(0xffb6c4ff),
      onSecondaryFixedVariant: Color(0xff243367),
      tertiaryFixed: Color(0xffffdcbb),
      onTertiaryFixed: Color(0xff1d0d00),
      tertiaryFixedDim: Color(0xffebbe90),
      onTertiaryFixedVariant: Color(0xff4c300e),
      surfaceDim: Color(0xff191113),
      surfaceBright: Color(0xff4d4243),
      surfaceContainerLowest: Color(0xff0c0607),
      surfaceContainerLow: Color(0xff241b1d),
      surfaceContainer: Color(0xff2f2527),
      surfaceContainerHigh: Color(0xff3a3031),
      surfaceContainerHighest: Color(0xff463b3c),
    );
  }

  ThemeData darkMediumContrast() {
    return theme(darkMediumContrastScheme());
  }

  static ColorScheme darkHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffffebed),
      surfaceTint: Color(0xffffb2bf),
      onPrimary: Color(0xff000000),
      primaryContainer: Color(0xffffacbb),
      onPrimaryContainer: Color(0xff210008),
      secondary: Color(0xffeeefff),
      onSecondary: Color(0xff000000),
      secondaryContainer: Color(0xffb2c0fd),
      onSecondaryContainer: Color(0xff00082b),
      tertiary: Color(0xffffedde),
      onTertiary: Color(0xff000000),
      tertiaryContainer: Color(0xffe7ba8d),
      onTertiaryContainer: Color(0xff150800),
      error: Color(0xffffece9),
      onError: Color(0xff000000),
      errorContainer: Color(0xffffaea4),
      onErrorContainer: Color(0xff220001),
      surface: Color(0xff191113),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffffffff),
      outline: Color(0xffffebed),
      outlineVariant: Color(0xffd2bec0),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xfff0dee0),
      inversePrimary: Color(0xff733442),
      primaryFixed: Color(0xffffd9de),
      onPrimaryFixed: Color(0xff000000),
      primaryFixedDim: Color(0xffffb2bf),
      onPrimaryFixedVariant: Color(0xff2c000d),
      secondaryFixed: Color(0xffdce1ff),
      onSecondaryFixed: Color(0xff000000),
      secondaryFixedDim: Color(0xffb6c4ff),
      onSecondaryFixedVariant: Color(0xff000c39),
      tertiaryFixed: Color(0xffffdcbb),
      onTertiaryFixed: Color(0xff000000),
      tertiaryFixedDim: Color(0xffebbe90),
      onTertiaryFixedVariant: Color(0xff1d0d00),
      surfaceDim: Color(0xff191113),
      surfaceBright: Color(0xff594d4f),
      surfaceContainerLowest: Color(0xff000000),
      surfaceContainerLow: Color(0xff261d1f),
      surfaceContainer: Color(0xff382e2f),
      surfaceContainerHigh: Color(0xff43393a),
      surfaceContainerHighest: Color(0xff4f4445),
    );
  }

  ThemeData darkHighContrast() {
    return theme(darkHighContrastScheme());
  }


  ThemeData theme(ColorScheme colorScheme) => ThemeData(
     useMaterial3: true,
     brightness: colorScheme.brightness,
     colorScheme: colorScheme,
     textTheme: textTheme.apply(
       bodyColor: colorScheme.onSurface,
       displayColor: colorScheme.onSurface,
     ),
     scaffoldBackgroundColor: colorScheme.background,
     canvasColor: colorScheme.surface,
  );


  List<ExtendedColor> get extendedColors => [
  ];
}

class ExtendedColor {
  final Color seed, value;
  final ColorFamily light;
  final ColorFamily lightHighContrast;
  final ColorFamily lightMediumContrast;
  final ColorFamily dark;
  final ColorFamily darkHighContrast;
  final ColorFamily darkMediumContrast;

  const ExtendedColor({
    required this.seed,
    required this.value,
    required this.light,
    required this.lightHighContrast,
    required this.lightMediumContrast,
    required this.dark,
    required this.darkHighContrast,
    required this.darkMediumContrast,
  });
}

class ColorFamily {
  const ColorFamily({
    required this.color,
    required this.onColor,
    required this.colorContainer,
    required this.onColorContainer,
  });

  final Color color;
  final Color onColor;
  final Color colorContainer;
  final Color onColorContainer;
}
