import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/presentation/widgets/app_network_image.dart';
import '../../../story_loops/data/story_loop_card_preview.dart';
import '../../data/calendar_card_preview_loader.dart';

ImageProvider? calendarCardNetworkImage({
  required StoryLoopCardPreview card,
  required Size maximumLogicalSize,
  required double pixelRatio,
}) {
  if (!AppConfig.calendarStorageImageTransforms ||
      !AppConfig.isSupabaseConfigured ||
      card.previewUrl != null ||
      card.previewPath.isEmpty) {
    return null;
  }
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return null;

  final sourceSize = card.cardType.previewSizeFor(card.layoutVersion);
  final transform = calendarCardPreviewTransform(
    sourceSize: sourceSize,
    maximumLogicalSize: maximumLogicalSize,
    pixelRatio: pixelRatio,
  );
  final cacheKey =
      'calendar-card/$userId/${transform?.height}/${card.previewPath}';
  return AppNetworkImage.withLoader(cacheKey, () {
    final loader = CalendarCardPreviewLoader(
      client.storage.from('story-cards'),
    );
    return loader.download(card.previewPath, transform: transform);
  });
}

TransformOptions? calendarCardPreviewTransform({
  required Size sourceSize,
  required Size maximumLogicalSize,
  required double pixelRatio,
}) {
  final scale = math.max(
    maximumLogicalSize.width / sourceSize.width,
    maximumLogicalSize.height / sourceSize.height,
  );
  const heightInterval = 32;
  final requiredHeight = sourceSize.height * scale * pixelRatio;
  final height = math.max(
    heightInterval,
    (requiredHeight / heightInterval).ceil() * heightInterval,
  );
  if (height >= sourceSize.height) return null;

  return TransformOptions(
    width: (sourceSize.width * height / sourceSize.height).ceil(),
    height: height,
    resize: ResizeMode.contain,
  );
}
