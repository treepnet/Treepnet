import 'package:flutter/material.dart';
import 'package:stories_editor/src/presentation/utils/constants/app_colors.dart';
import 'package:stories_editor/src/presentation/utils/constants/font_family.dart';

class ControlNotifier extends ChangeNotifier {
  bool _isTextEditing = false;

  /// is text editor open
  bool get isTextEditing => _isTextEditing;

  /// get bool if is text editing
  set isTextEditing(bool val) {
    /// set bool if is text editing
    _isTextEditing = val;
    notifyListeners();
  }

  List<String>? _fontList = AppFonts.fontFamilyList;

  /// here you can define your own font family list
  List<String>? get fontList => _fontList;
  set fontList(List<String>? fonts) {
    _fontList = fonts;
    notifyListeners();
  }

  bool _isCustomFontList = false;

  /// if you add your custom list is required to specify your app package
  bool get isCustomFontList => _isCustomFontList;
  set isCustomFontList(bool key) {
    _isCustomFontList = key;
    notifyListeners();
  }

  List<Color>? _colorList = AppColors.defaultColors;

  /// you can add your own color palette list
  List<Color>? get colorList => _colorList;
  set colorList(List<Color>? value) {
    _colorList = value;
    notifyListeners();
  }

  /// get image path
  String _mediaPath = '';
  String get mediaPath => _mediaPath;
  set mediaPath(String media) {
    _mediaPath = media;
    notifyListeners();
  }
}
