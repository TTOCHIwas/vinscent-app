import 'dart:convert';
import 'dart:ui';

enum AppDrawingTool {
  pen,
  eraser;

  factory AppDrawingTool.fromJson(String value) {
    return switch (value) {
      'pen' => AppDrawingTool.pen,
      'eraser' => AppDrawingTool.eraser,
      _ => throw FormatException('Unknown drawing tool: $value'),
    };
  }

  String toJson() {
    return switch (this) {
      AppDrawingTool.pen => 'pen',
      AppDrawingTool.eraser => 'eraser',
    };
  }
}

class AppDrawingData {
  const AppDrawingData({required this.strokes});

  factory AppDrawingData.empty() {
    return const AppDrawingData(strokes: []);
  }

  factory AppDrawingData.fromJson(Map<String, dynamic> json) {
    final strokes = json['strokes'] as List<dynamic>? ?? [];

    return AppDrawingData(
      strokes: strokes
          .map(
            (stroke) => AppDrawingStroke.fromJson(
              Map<String, dynamic>.from(stroke as Map),
            ),
          )
          .toList(),
    );
  }

  factory AppDrawingData.fromJsonString(String value) {
    return AppDrawingData.fromJson(
      Map<String, dynamic>.from(jsonDecode(value) as Map),
    );
  }

  final List<AppDrawingStroke> strokes;

  bool get hasVisibleContent {
    return strokes.any((stroke) => stroke.tool == AppDrawingTool.pen);
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

class AppDrawingStroke {
  const AppDrawingStroke({
    required this.tool,
    required this.color,
    required this.width,
    required this.points,
  });

  factory AppDrawingStroke.fromJson(Map<String, dynamic> json) {
    final points = json['points'] as List<dynamic>? ?? [];

    return AppDrawingStroke(
      tool: AppDrawingTool.fromJson(json['tool'] as String),
      color: _colorFromJson(json['color'] as String),
      width: (json['width'] as num).toDouble(),
      points: points
          .map(
            (point) => AppDrawingPoint.fromJson(
              Map<String, dynamic>.from(point as Map),
            ),
          )
          .toList(),
    );
  }

  final AppDrawingTool tool;
  final Color color;
  final double width;
  final List<AppDrawingPoint> points;

  AppDrawingStroke copyWith({List<AppDrawingPoint>? points}) {
    return AppDrawingStroke(
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

class AppDrawingPoint {
  const AppDrawingPoint({required this.x, required this.y});

  factory AppDrawingPoint.fromJson(Map<String, dynamic> json) {
    return AppDrawingPoint(
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
