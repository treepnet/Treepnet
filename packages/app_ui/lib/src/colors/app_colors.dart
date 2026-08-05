import 'package:flutter/material.dart';

/// Defines the color palette for the App UI Kit.
abstract class AppColors {
  // ---------------------------------------------------------------------
  // Figma design system — "Colors" page. These are the source of truth for
  // new screens; the older ad-hoc colours below stay until every screen is
  // migrated.
  // ---------------------------------------------------------------------

  /// Brand color 1 — periwinkle.
  static const Color brand1 = Color(0xFF728FCE);

  /// Brand color 2 — deep blue.
  static const Color brand2 = Color(0xFF2F539B);

  /// Brand color 3 — purple.
  static const Color brand3 = Color(0xFF6D35C0);

  /// Brand color 4 — magenta. Doubles as the `Danger nf` semantic colour.
  static const Color brand4 = Color(0xFFF535AA);

  /// Brand color 5 — red.
  static const Color brand5 = Color(0xFFB21807);

  /// Magenta accent (likes, badges) — alias of [brand4].
  static const Color pink = brand4;

  /// Secondary text (`Text secondary`).
  static const Color textSecondaryFigma = Color(0xFF687575);

  /// Tertiary text (`Text third`).
  static const Color textThird = Color(0xFFA0A0A0);

  /// Border colour from the design system.
  static const Color borderColor = Color(0xFF5F685B);

  /// Input field background (`Input space`).
  static const Color inputSpace = Color(0xFF414141);

  /// Icons render white — the `Icons` token, not the green used to preview
  /// them in the Figma icon table.
  static const Color icon = white;

  /// `Danger nf` — destructive states and errors.
  static const Color danger = Color(0xFFFF2EA2);

  /// `success nf`.
  static const Color success = Color(0xFF2FFFA4);

  /// `warning nf`.
  static const Color warning = Color(0xFFFFD62C);

  /// `help nf`.
  static const Color help = Color(0xFF2ED2FF);

  /// Black
  static const Color black = Color(0xFF000000);

  /// The background color.
  static const Color background = Color(0xFF191919);

  /// White
  static const Color white = Color(0xFFFFFFFF);

  /// Transparent
  static const Color transparent = Color(0x00000000);

  /// The light blue color.
  static const Color lightBlue = Color.fromARGB(255, 100, 181, 246);

  /// The blue primary color and swatch.
  static const Color blue = Color(0xFF728FCE);

  /// The deep blue color.
  static const Color deepBlue = Color(0xFF2F539B);

  /// The border outline color.
  static const Color borderOutline = Color(0xFF5F685B);

  /// Light dark.
  static const Color lightDark = Color.fromARGB(164, 120, 119, 119);

  /// Dark.
  static const Color dark = Color.fromARGB(255, 58, 58, 58);

  /// Primary dark blue color.
  static const Color primaryDarkBlue = Color(0xff1c1e22);

  /// Grey.
  static const Color grey = Color(0xFFA0A0A0);

  /// The bright grey color.
  static const Color brightGrey = Color.fromARGB(255, 224, 224, 224);

  /// The dark grey color.
  static const Color darkGrey = Color.fromARGB(255, 66, 66, 66);

  /// The emphasize grey color.
  static const Color emphasizeGrey = Color.fromARGB(255, 97, 97, 97);

  /// The emphasize dark grey color.
  static const Color emphasizeDarkGrey = Color.fromARGB(255, 40, 37, 37);

  /// Destructive accent — the red the designs use for Delete / Log out.
  /// (`Danger nf` #FF2EA2 stays available as [danger] for error states.)
  static const Color destructive = Color(0xFFEE1D23);

  /// Destructive/error accent; kept under the old name so existing call sites
  /// read unchanged.
  static const Color red = destructive;

  /// The primary Instagram gradient pallete.
  static const primaryGradient = <Color>[
    Color(0xFF833AB4), // Purple
    Color(0xFFF77737), // Orange
    Color(0xFFE1306C), // Red-pink
    Color(0xFFC13584), // Red-purple
    Color(0xFF833AB4), // Duplicate of the first color
  ];

  /// The primary Telegram gradient chat background pallete.
  static const primaryBackgroundGradient = <Color>[
    Color.fromARGB(255, 119, 69, 121),
    Color.fromARGB(255, 141, 124, 189),
    Color.fromARGB(255, 50, 94, 170),
    Color.fromARGB(255, 111, 156, 189),
  ];

  /// The primary Telegram gradient chat message bubble pallete.
  static const primaryMessageBubbleGradient = <Color>[
    Color.fromARGB(255, 226, 128, 53),
    Color.fromARGB(255, 228, 96, 182),
    Color.fromARGB(255, 107, 73, 195),
    Color.fromARGB(255, 78, 173, 195),
  ];

  /// The glass background color, usually used for cards.
  static const Color glassBackground = Color(0x1FFFFFFF);

  /// The light glass background color.
  static const Color glassBackgroundLight = Color(0x33FFFFFF);

  /// The divider color.
  static const Color divider = Color(0x0DFFFFFF);

  /// The secondary text color.
  static const Color textSecondary = Color(0xFF687575);
}
