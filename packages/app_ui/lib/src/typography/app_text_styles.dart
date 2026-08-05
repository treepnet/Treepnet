import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

/// The app consists of two main text style definitions: UI and Content.
///
/// Content text style is primarily used for all content-based components,
/// e.g. news feed including articles and sections, while the UI text style
/// is used for the rest of UI components.
///
/// The default app's [TextTheme] is [AppTheme.uiTextTheme].
///
/// Use `ContentThemeOverrideBuilder` to override the default [TextTheme]
/// to [AppTheme.contentTextTheme].

/// UI Text Style Definitions
abstract class UITextStyle {
  static const _baseTextStyle = TextStyle(
    package: 'app_ui',
    fontWeight: AppFontWeight.semiBold,
    fontFamily: 'Source Sans 3',
    decoration: TextDecoration.none,
    textBaseline: TextBaseline.alphabetic,
  );

  /// Display 2 Text Style
  static final TextStyle display2 = _baseTextStyle.copyWith(
    fontSize: 57,
    fontWeight: AppFontWeight.bold,
    height: 1.12,
    letterSpacing: -0.25,
  );

  /// Display 3 Text Style
  static final TextStyle display3 = _baseTextStyle.copyWith(
    fontSize: 45,
    fontWeight: AppFontWeight.bold,
    height: 1.15,
  );

  /// Headline 1 Text Style
  static final TextStyle headline1 = _baseTextStyle.copyWith(
    fontSize: 40,
    fontWeight: AppFontWeight.bold,
    height: 1.12,
  );

  /// Headline 2 Text Style
  static final TextStyle headline2 = _baseTextStyle.copyWith(
    fontSize: 28,
    fontWeight: AppFontWeight.bold,
    height: 1.12,
  );

  /// Headline 3 Text Style
  static final TextStyle headline3 = _baseTextStyle.copyWith(
    fontSize: 28,
    fontWeight: AppFontWeight.semiBold,
    height: 1.12,
  );

  /// Headline 4 Text Style
  static final TextStyle headline4 = _baseTextStyle.copyWith(
    fontSize: 24,
    fontWeight: AppFontWeight.semiBold,
    height: 1.25,
  );

  /// Headline 5 Text Style
  static final TextStyle headline5 = _baseTextStyle.copyWith(
    fontSize: 24,
    fontWeight: AppFontWeight.regular,
    height: 1.25,
  );

  /// Headline 6 Text Style
  static final TextStyle headline6 = _baseTextStyle.copyWith(
    fontSize: 24,
    fontWeight: AppFontWeight.semiBold,
    height: 1.25,
  );

  /// Subtitle 1 Text Style
  static final TextStyle subtitle1 = _baseTextStyle.copyWith(
    fontSize: 20,
    height: 1.5,
    letterSpacing: 0.1,
  );

  /// Subtitle 2 Text Style
  static final TextStyle subtitle2 = _baseTextStyle.copyWith(
    fontSize: 18,
    height: 1.5,
    letterSpacing: 0.1,
  );

  /// Body Text 1 Text Style
  static final TextStyle bodyText1 = _baseTextStyle.copyWith(
    fontSize: 18,
    height: 1.5,
    letterSpacing: 0.5,
  );

  /// Body Text 2 Text Style (the default)
  static final TextStyle bodyText2 = _baseTextStyle.copyWith(
    fontSize: 16,
    height: 1.5,
    letterSpacing: 0.25,
  );

  /// Caption Text Style
  static final TextStyle caption = _baseTextStyle.copyWith(
    fontSize: 14,
    height: 1.25,
    letterSpacing: 0.4,
  );

  /// Button Text Style
  static final TextStyle button = _baseTextStyle.copyWith(
    fontSize: 16,
    height: 1.25,
    letterSpacing: 0.1,
  );

  /// Overline Text Style
  static final TextStyle overline = _baseTextStyle.copyWith(
    fontSize: 12,
    height: 1.25,
    letterSpacing: 0.5,
  );

  /// Label Small Text Style
  static final TextStyle labelSmall = _baseTextStyle.copyWith(
    fontSize: 10,
    height: 1.25,
    letterSpacing: 0.5,
  );
}

/// Content Text Style Definitions
abstract class ContentTextStyle {
  static const _baseTextStyle = TextStyle(
    package: 'app_ui',
    fontWeight: AppFontWeight.semiBold,
    fontFamily: 'Source Sans 3',
    decoration: TextDecoration.none,
    textBaseline: TextBaseline.alphabetic,
  );

  /// Display 1 Text Style
  static final TextStyle display1 = _baseTextStyle.copyWith(
    fontSize: 64,
    fontWeight: AppFontWeight.bold,
    height: 1.18,
    letterSpacing: -0.5,
  );

  /// Display 2 Text Style
  static final TextStyle display2 = _baseTextStyle.copyWith(
    fontSize: 57,
    fontWeight: AppFontWeight.bold,
    height: 1.12,
    letterSpacing: -0.25,
  );

  /// Display 3 Text Style
  static final TextStyle display3 = _baseTextStyle.copyWith(
    fontSize: 45,
    fontWeight: AppFontWeight.bold,
    height: 1.15,
  );

  /// Headline 1 Text Style
  static final TextStyle headline1 = _baseTextStyle.copyWith(
    fontSize: 40,
    fontWeight: AppFontWeight.semiBold,
    height: 1.12,
  );

  /// Headline 2 Text Style
  static final TextStyle headline2 = _baseTextStyle.copyWith(
    fontSize: 28,
    fontWeight: AppFontWeight.semiBold,
    height: 1.12,
  );

  /// Headline 3 Text Style
  static final TextStyle headline3 = _baseTextStyle.copyWith(
    fontSize: 28,
    fontWeight: AppFontWeight.semiBold,
    height: 1.12,
  );

  /// Headline 4 Text Style
  static final TextStyle headline4 = _baseTextStyle.copyWith(
    fontSize: 24,
    fontWeight: AppFontWeight.semiBold,
    height: 1.25,
  );

  /// Headline 5 Text Style
  static final TextStyle headline5 = _baseTextStyle.copyWith(
    fontSize: 24,
    fontWeight: AppFontWeight.semiBold,
    height: 1.25,
  );

  /// Headline 6 Text Style
  static final TextStyle headline6 = _baseTextStyle.copyWith(
    fontSize: 24,
    fontWeight: AppFontWeight.semiBold,
    height: 1.25,
  );

  /// Headline 7 Text Style
  static final TextStyle headline7 = _baseTextStyle.copyWith(
    fontSize: 20,
    fontWeight: AppFontWeight.semiBold,
    height: 1.25,
  );

  /// Subtitle 1 Text Style
  static final TextStyle subtitle1 = _baseTextStyle.copyWith(
    fontSize: 20,
    fontWeight: AppFontWeight.semiBold,
    height: 1.25,
  );

  /// Subtitle 2 Text Style
  static final TextStyle subtitle2 = _baseTextStyle.copyWith(
    fontSize: 18,
    fontWeight: AppFontWeight.semiBold,
    height: 1.5,
  );

  /// Body Text 1 Text Style
  static final TextStyle bodyText1 = _baseTextStyle.copyWith(
    fontSize: 18,
    fontWeight: AppFontWeight.semiBold,
    height: 1.5,
  );

  /// Body Text 2 Text Style (the default)
  static final TextStyle bodyText2 = _baseTextStyle.copyWith(
    fontSize: 16,
    fontWeight: AppFontWeight.semiBold,
    height: 1.5,
  );

  /// Button Text Style
  static final TextStyle button = _baseTextStyle.copyWith(
    fontSize: 16,
    fontWeight: AppFontWeight.semiBold,
    height: 1.25,
  );

  /// Caption Text Style
  static final TextStyle caption = _baseTextStyle.copyWith(
    fontSize: 14,
    fontWeight: AppFontWeight.semiBold,
    height: 1.25,
  );

  /// Overline Text Style
  static final TextStyle overline = _baseTextStyle.copyWith(
    fontSize: 12,
    fontWeight: AppFontWeight.semiBold,
    height: 1.25,
  );

  /// Label Small Text Style
  static final TextStyle labelSmall = _baseTextStyle.copyWith(
    fontSize: 8,
    fontWeight: AppFontWeight.semiBold,
    height: 1.25,
  );
}
