import 'dart:convert';
import 'dart:ui';

enum CharacterDrawingTool {
  pen,
  eraser;

  factory CharacterDrawingTool.fromJson(String value) {
    return switch (value) {
      'pen' => CharacterDrawingTool.pen,
      'eraser' => CharacterDrawingTool.eraser,
      _ => throw FormatException('Unknown drawing tool: $value'),
    };
  }

  String toJson() {
    return switch (this) {
      CharacterDrawingTool.pen => 'pen',
      CharacterDrawingTool.eraser => 'eraser',
    };
  }
}

class CharacterDrawingData {
  const CharacterDrawingData({required this.strokes});

  factory CharacterDrawingData.empty() {
    return const CharacterDrawingData(strokes: []);
  }

  factory CharacterDrawingData.fromJson(Map<String, dynamic> json) {
    final strokes = json['strokes'] as List<dynamic>? ?? [];

    return CharacterDrawingData(
      strokes: strokes
          .map(
            (stroke) => CharacterDrawingStroke.fromJson(
              Map<String, dynamic>.from(stroke as Map),
            ),
          )
          .toList(),
    );
  }

  factory CharacterDrawingData.fromJsonString(String value) {
    return CharacterDrawingData.fromJson(
      Map<String, dynamic>.from(jsonDecode(value) as Map),
    );
  }

  final List<CharacterDrawingStroke> strokes;

  bool get hasVisibleContent {
    return strokes.any((stroke) => stroke.tool == CharacterDrawingTool.pen);
  }

  Map<String, dynamic> toJson() {
    return {
      'version': 1,
      'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
    };
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }
}

class CharacterDrawingStroke {
  const CharacterDrawingStroke({
    required this.tool,
    required this.color,
    required this.width,
    required this.points,
  });

  factory CharacterDrawingStroke.fromJson(Map<String, dynamic> json) {
    final points = json['points'] as List<dynamic>? ?? [];

    return CharacterDrawingStroke(
      tool: CharacterDrawingTool.fromJson(json['tool'] as String),
      color: _colorFromJson(json['color'] as String),
      width: (json['width'] as num).toDouble(),
      points: points
          .map(
            (point) => CharacterDrawingPoint.fromJson(
              Map<String, dynamic>.from(point as Map),
            ),
          )
          .toList(),
    );
  }

  final CharacterDrawingTool tool;
  final Color color;
  final double width;
  final List<CharacterDrawingPoint> points;

  CharacterDrawingStroke copyWith({List<CharacterDrawingPoint>? points}) {
    return CharacterDrawingStroke(
      tool: tool,
      color: color,
      width: width,
      points: points ?? this.points,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tool': tool.toJson(),
      'color': _colorToJson(color),
      'width': width,
      'points': points.map((point) => point.toJson()).toList(),
    };
  }
}

class CharacterDrawingPoint {
  const CharacterDrawingPoint({required this.x, required this.y});

  factory CharacterDrawingPoint.fromJson(Map<String, dynamic> json) {
    return CharacterDrawingPoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  final double x;
  final double y;

  Map<String, dynamic> toJson() {
    return {'x': x, 'y': y};
  }
}

String _colorToJson(Color color) {
  return '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}';
}

Color _colorFromJson(String value) {
  final hex = value.replaceFirst('#', '');
  final normalized = hex.length == 6 ? 'ff$hex' : hex;

  return Color(int.parse(normalized, radix: 16));
}
