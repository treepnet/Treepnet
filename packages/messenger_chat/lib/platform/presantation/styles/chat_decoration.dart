part of messenger_chat;

class ChatDecoration {
  ChatDecoration({
    required this.backgroundColor,
    this.backgroundImagePng,
    this.backgroundImageSvg,
    this.backgroundSvgColor,
  });

  final Color backgroundColor;
  final String? backgroundImagePng;
  final String? backgroundImageSvg;
  final Color? backgroundSvgColor;

  ChatDecoration copyWith({
    Color? backgroundColor,
    String? backgroundImagePng,
    String? backgroundImageSvg,
    Color? backgroundSvgColor,
  }) => ChatDecoration(
    backgroundColor: backgroundColor ?? this.backgroundColor,
    backgroundImagePng: backgroundImagePng ?? this.backgroundImagePng,
    backgroundImageSvg: backgroundImageSvg ?? this.backgroundImageSvg,
    backgroundSvgColor: backgroundSvgColor ?? this.backgroundSvgColor,
  );
}
