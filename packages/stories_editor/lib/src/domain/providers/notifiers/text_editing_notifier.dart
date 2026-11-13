import 'package:flutter/material.dart';

/// The design's chip fill (#191919 at 50%), behind typed text and the time
/// and place stamps alike.
const storyChipBackground = Color(0x80191919);

/// The size typed text is set in.
const storyTextSize = 25.0;

class TextEditingNotifier extends ChangeNotifier {
  String _text = '';
  int _textColor = 0;
  double _textSize = storyTextSize;
  int _fontFamilyIndex = 0;
  TextAlign _textAlign = TextAlign.center;
  // Typed text carries the same chip as the time and place stamps.
  Color _backGroundColor = storyChipBackground;
  bool _isFontFamily = true;

  PageController _fontFamilyController = PageController(viewportFraction: .125);
  TextEditingController _textController = TextEditingController();

  String get text => _text;
  int get textColor => _textColor;
  double get textSize => _textSize;
  int get fontFamilyIndex => _fontFamilyIndex;
  TextAlign get textAlign => _textAlign;
  Color get backGroundColor => _backGroundColor;
  bool get isFontFamily => _isFontFamily;
  PageController get fontFamilyController => _fontFamilyController;
  TextEditingController get textController => _textController;

  set text(String text) {
    _text = text;
    notifyListeners();
  }

  set textColor(int color) {
    if (_backGroundColor == Colors.white && color == 0) {
      _textColor = 1;
      notifyListeners();
    } else if (_backGroundColor == Colors.black && color == 1) {
      _textColor = 0;
      notifyListeners();
    } else {
      _textColor = color;
      notifyListeners();
    }
  }

  set textSize(double size) {
    _textSize = size;
    notifyListeners();
  }

  set fontFamilyIndex(int fontIndex) {
    _fontFamilyIndex = fontIndex;
    notifyListeners();
  }

  set isFontFamily(bool isFamily) {
    _isFontFamily = isFamily;
    notifyListeners();
  }

  set fontFamilyController(PageController controller) {
    _fontFamilyController = controller;
    notifyListeners();
  }

  set textController(TextEditingController textController) {
    _textController = textController;
    notifyListeners();
  }

  set backGroundColor(Color backGround) {
    _backGroundColor = backGround;
    notifyListeners();
  }

  set textAlign(TextAlign align) {
    _textAlign = align;
    notifyListeners();
  }

  /// Back to how the first text starts (also after a text is added or the
  /// tool cancelled): it used to reset to 20 and no chip, so every text after
  /// the first came out smaller and bare, with no buttons left to fix it.
  setDefaults() {
    _text = '';
    _textController.text = '';
    _textColor = 0;
    _textSize = storyTextSize;
    _fontFamilyIndex = 0;
    _textAlign = TextAlign.center;
    _backGroundColor = storyChipBackground;
    _fontFamilyController = PageController(viewportFraction: .125);
    _isFontFamily = true;
  }
}
