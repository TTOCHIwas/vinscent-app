import 'dart:math' as math;

import 'package:flutter/foundation.dart';

void debugAuthLog(String message) {
  if (kDebugMode) {
    debugPrint('[auth] $message');
  }
}

String summarizeAuthValue(
  String? value, {
  int visiblePrefix = 6,
  int visibleSuffix = 4,
}) {
  if (value == null) {
    return 'null';
  }

  if (value.isEmpty) {
    return 'empty';
  }

  final prefixLength = math.min(visiblePrefix, value.length);
  final suffixLength = math.min(
    visibleSuffix,
    math.max(0, value.length - prefixLength),
  );

  final prefix = value.substring(0, prefixLength);
  if (value.length <= prefixLength + suffixLength) {
    return '$prefix(len=${value.length})';
  }

  final suffix = value.substring(value.length - suffixLength);
  return '$prefix...$suffix(len=${value.length})';
}
