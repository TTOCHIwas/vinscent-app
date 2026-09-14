import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../data/story_card_film_look.dart';
import 'story_card_editor_style.dart';
import 'story_card_picker_surface.dart';

class StoryCardFilmLookSelector extends StatelessWidget {
  const StoryCardFilmLookSelector({
    super.key,
    required this.selectedLook,
    required this.onLookChanged,
    required this.keyPrefix,
  });

  final StoryCardFilmLook selectedLook;
  final ValueChanged<StoryCardFilmLook> onLookChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return StoryCardPickerSurface(
      surfaceKey: const ValueKey('story-card-film-picker-surface'),
      color: storyCardEditorChromeColor,
      child: SizedBox(
        height: 68,
        child: Row(
          children: [
            for (final look in StoryCardFilmLook.values)
              Expanded(
                child: _FilmLookButton(
                  key: ValueKey('$keyPrefix-${look.id}'),
                  look: look,
                  isSelected: look == selectedLook,
                  onPressed: () => onLookChanged(look),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilmLookButton extends StatelessWidget {
  const _FilmLookButton({
    super.key,
    required this.look,
    required this.isSelected,
    required this.onPressed,
  });

  final StoryCardFilmLook look;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${look.label} 필름',
      child: InkResponse(
        onTap: onPressed,
        radius: 30,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: isSelected ? 16 : 4,
              height: 2,
              color: isSelected ? Colors.white : Colors.transparent,
            ),
            const SizedBox(height: 7),
            Text(
              look.label,
              maxLines: 1,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xB3FFFFFF),
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                height: AppTypography.bodyLineHeight,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
