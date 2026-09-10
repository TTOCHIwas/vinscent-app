import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../application/story_card_film_shader.dart';
import '../../data/story_card_film_look.dart';

class StoryCardFilmFilteredPreview extends StatefulWidget {
  const StoryCardFilmFilteredPreview({
    super.key,
    required this.film,
    required this.child,
  });

  final StoryCardFilmState film;
  final Widget child;

  @override
  State<StoryCardFilmFilteredPreview> createState() =>
      _StoryCardFilmFilteredPreviewState();
}

class _StoryCardFilmFilteredPreviewState
    extends State<StoryCardFilmFilteredPreview> {
  ui.FragmentShader? _shader;
  ui.ImageFilter? _imageFilter;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadFilter());
  }

  @override
  void didUpdateWidget(covariant StoryCardFilmFilteredPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.film != widget.film) {
      unawaited(_loadFilter());
    }
  }

  Future<void> _loadFilter() async {
    final generation = ++_generation;
    final previousShader = _shader;
    _shader = null;
    _imageFilter = null;
    previousShader?.dispose();

    if (widget.film.look == StoryCardFilmLook.original ||
        !ui.ImageFilter.isShaderFilterSupported) {
      return;
    }

    try {
      final program = await StoryCardFilmShaderProgram.load();
      if (!mounted || generation != _generation) {
        return;
      }
      final shader = StoryCardFilmShader.createForImageFilter(
        program: program,
        film: widget.film,
      );
      final imageFilter = ui.ImageFilter.shader(shader);
      setState(() {
        _shader = shader;
        _imageFilter = imageFilter;
      });
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Failed to prepare story card film preview: $error');
      }
    }
  }

  @override
  void dispose() {
    _generation += 1;
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageFilter = _imageFilter;
    if (imageFilter == null) {
      return widget.child;
    }
    return ImageFiltered(
      key: const ValueKey('story-card-live-film-filter'),
      imageFilter: imageFilter,
      child: widget.child,
    );
  }
}
