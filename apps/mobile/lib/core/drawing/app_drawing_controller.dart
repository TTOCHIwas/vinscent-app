import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'app_drawing.dart';
import 'app_drawing_style.dart';

class AppDrawingController extends ChangeNotifier {
  List<AppDrawingStroke> _strokes = const [];
  AppDrawingStroke? _activeStroke;
  AppDrawingTool _selectedTool = AppDrawingTool.pen;
  Color _selectedColor = AppDrawingStyle.colorPalette.first;
  double _selectedStrokeWidth = AppDrawingStyle.normalStrokeWidth;

  List<AppDrawingStroke> get strokes => List.unmodifiable(_strokes);

  List<AppDrawingStroke> get visibleStrokes =>
      List.unmodifiable([..._strokes, ?_activeStroke]);

  AppDrawingData get drawingData => AppDrawingData(strokes: strokes);

  AppDrawingTool get selectedTool => _selectedTool;
  Color get selectedColor => _selectedColor;
  double get selectedStrokeWidth => _selectedStrokeWidth;
  bool get hasVisibleContent => drawingData.hasVisibleContent;
  bool get canUndo => _activeStroke == null && _strokes.isNotEmpty;
  bool get canClear => _strokes.isNotEmpty;

  void replaceStrokes(Iterable<AppDrawingStroke> strokes) {
    _strokes = List.unmodifiable(strokes);
    _activeStroke = null;
    notifyListeners();
  }

  void startStroke(AppDrawingPoint point) {
    _activeStroke = AppDrawingStroke(
      tool: _selectedTool,
      color: _selectedColor,
      width: _selectedStrokeWidth,
      points: [point],
    );
    notifyListeners();
  }

  void updateStroke(AppDrawingPoint point) {
    final activeStroke = _activeStroke;
    if (activeStroke == null) {
      return;
    }

    _activeStroke = activeStroke.copyWith(
      points: [...activeStroke.points, point],
    );
    notifyListeners();
  }

  void endStroke() {
    final activeStroke = _activeStroke;
    if (activeStroke == null) {
      return;
    }

    _strokes = List.unmodifiable([..._strokes, activeStroke]);
    _activeStroke = null;
    notifyListeners();
  }

  void undo() {
    if (!canUndo) {
      return;
    }

    _strokes = List.unmodifiable(_strokes.sublist(0, _strokes.length - 1));
    notifyListeners();
  }

  void clear() {
    if (_strokes.isEmpty && _activeStroke == null) {
      return;
    }

    _strokes = const [];
    _activeStroke = null;
    notifyListeners();
  }

  void selectTool(AppDrawingTool tool) {
    if (_selectedTool == tool) {
      return;
    }

    _selectedTool = tool;
    notifyListeners();
  }

  void selectColor(Color color) {
    if (_selectedColor == color && _selectedTool == AppDrawingTool.pen) {
      return;
    }

    _selectedColor = color;
    _selectedTool = AppDrawingTool.pen;
    notifyListeners();
  }

  void selectStrokeWidth(double width) {
    if (_selectedStrokeWidth == width) {
      return;
    }

    _selectedStrokeWidth = width;
    notifyListeners();
  }
}
