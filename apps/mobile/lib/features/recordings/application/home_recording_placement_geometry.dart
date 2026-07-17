import 'dart:math' as math;

import 'package:flutter/material.dart';

class HomeRecordingPlacementGeometry {
  HomeRecordingPlacementGeometry({
    required this.canvasSize,
    required this.itemSize,
    required List<Rect> forbiddenRects,
    this.safetyMargin = 4,
  }) : forbiddenRects = forbiddenRects
           .map((rect) => rect.inflate(safetyMargin))
           .toList(growable: false);

  final Size canvasSize;
  final double itemSize;
  final List<Rect> forbiddenRects;
  final double safetyMargin;

  double get _halfItem => itemSize / 2;

  Rect get _canvasRect => Offset.zero & canvasSize;

  bool isAllowed(Offset center) {
    final itemRect = Rect.fromCenter(
      center: center,
      width: itemSize,
      height: itemSize,
    );
    if (itemRect.left < _canvasRect.left ||
        itemRect.top < _canvasRect.top ||
        itemRect.right > _canvasRect.right ||
        itemRect.bottom > _canvasRect.bottom) {
      return false;
    }

    return forbiddenRects.every((rect) => !rect.overlaps(itemRect));
  }

  Offset? resolve(Offset requestedCenter) {
    final clamped = Offset(
      requestedCenter.dx.clamp(_halfItem, canvasSize.width - _halfItem),
      requestedCenter.dy.clamp(_halfItem, canvasSize.height - _halfItem),
    );
    if (isAllowed(clamped)) {
      return clamped;
    }

    final candidates = _allowedCandidates()
      ..sort(
        (left, right) => (left - clamped).distanceSquared.compareTo(
          (right - clamped).distanceSquared,
        ),
      );
    return candidates.firstOrNull;
  }

  Offset? findDefaultPosition({required Iterable<Offset> occupied}) {
    final occupiedPositions = occupied.toList(growable: false);
    final minimumSpacing = itemSize + safetyMargin;
    final candidates = _allowedCandidates()
        .where(
          (candidate) => occupiedPositions.every(
            (position) => (candidate - position).distance >= minimumSpacing,
          ),
        )
        .toList(growable: false);
    if (candidates.isEmpty) {
      return null;
    }
    if (occupiedPositions.isEmpty) {
      return candidates.first;
    }

    Offset? best;
    var bestDistance = -1.0;
    for (final candidate in candidates) {
      final nearestDistance = occupiedPositions
          .map((position) => (candidate - position).distanceSquared)
          .reduce(math.min);
      if (nearestDistance > bestDistance) {
        best = candidate;
        bestDistance = nearestDistance;
      }
    }
    return best;
  }

  Offset normalize(Offset center) {
    return Offset(
      (center.dx / canvasSize.width).clamp(0.0, 1.0),
      (center.dy / canvasSize.height).clamp(0.0, 1.0),
    );
  }

  Offset denormalize(Offset normalized) {
    return Offset(
      normalized.dx.clamp(0.0, 1.0) * canvasSize.width,
      normalized.dy.clamp(0.0, 1.0) * canvasSize.height,
    );
  }

  List<Offset> _allowedCandidates() {
    final step = itemSize + math.max(8.0, safetyMargin * 2);
    final xValues = _axisCandidates(
      minimum: _halfItem,
      maximum: canvasSize.width - _halfItem,
      step: step,
    );
    final yValues = _axisCandidates(
      minimum: _halfItem,
      maximum: canvasSize.height - _halfItem,
      step: step,
    );
    final candidates = <Offset>[
      for (final y in yValues)
        for (final x in xValues)
          if (isAllowed(Offset(x, y))) Offset(x, y),
    ];
    return candidates;
  }

  List<double> _axisCandidates({
    required double minimum,
    required double maximum,
    required double step,
  }) {
    if (maximum < minimum) {
      return const [];
    }

    final values = <double>[];
    for (var value = minimum; value <= maximum; value += step) {
      values.add(value);
    }
    if (values.isEmpty || values.last != maximum) {
      values.add(maximum);
    }
    return values;
  }
}
