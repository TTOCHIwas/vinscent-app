import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../data/story_card_camera_effect.dart';
import '../../data/story_card_film_look.dart';

enum _StoryCardCameraStyleTab { film, effect }

class StoryCardCameraStyleSelector extends StatefulWidget {
  const StoryCardCameraStyleSelector({
    super.key,
    required this.selectedFilmLook,
    required this.selectedEffect,
    required this.isEffectLoading,
    required this.onFilmLookChanged,
    required this.onEffectChanged,
  });

  final StoryCardFilmLook selectedFilmLook;
  final StoryCardCameraEffect selectedEffect;
  final bool isEffectLoading;
  final ValueChanged<StoryCardFilmLook> onFilmLookChanged;
  final ValueChanged<StoryCardCameraEffect> onEffectChanged;

  @override
  State<StoryCardCameraStyleSelector> createState() =>
      _StoryCardCameraStyleSelectorState();
}

class _StoryCardCameraStyleSelectorState
    extends State<StoryCardCameraStyleSelector> {
  var _tab = _StoryCardCameraStyleTab.film;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xB3000000),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 38,
                child: Row(
                  children: [
                    Expanded(
                      child: _StyleTabButton(
                        key: const ValueKey('story-card-style-film-tab'),
                        label: '필름',
                        isSelected: _tab == _StoryCardCameraStyleTab.film,
                        onPressed: () => setState(
                          () => _tab = _StoryCardCameraStyleTab.film,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _StyleTabButton(
                        key: const ValueKey('story-card-style-effect-tab'),
                        label: '효과',
                        isSelected: _tab == _StoryCardCameraStyleTab.effect,
                        onPressed: () => setState(
                          () => _tab = _StoryCardCameraStyleTab.effect,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0x24FFFFFF)),
              SizedBox(
                height: 58,
                child: _tab == _StoryCardCameraStyleTab.film
                    ? Row(
                        children: [
                          for (final look in StoryCardFilmLook.values)
                            Expanded(
                              child: _StyleChoiceButton(
                                key: ValueKey(
                                  'story-card-camera-film-${look.id}',
                                ),
                                label: look.label,
                                isSelected: look == widget.selectedFilmLook,
                                onPressed: () => widget.onFilmLookChanged(look),
                              ),
                            ),
                        ],
                      )
                    : Row(
                        children: [
                          for (final effect in StoryCardCameraEffect.values)
                            Expanded(
                              child: _StyleChoiceButton(
                                key: ValueKey(
                                  'story-card-camera-effect-${effect.id}',
                                ),
                                label: effect.label,
                                isSelected: effect == widget.selectedEffect,
                                isLoading:
                                    widget.isEffectLoading &&
                                    effect ==
                                        StoryCardCameraEffect.coupleCharacter,
                                onPressed: widget.isEffectLoading
                                    ? null
                                    : () => widget.onEffectChanged(effect),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StyleTabButton extends StatelessWidget {
  const _StyleTabButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onPressed,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0x8FFFFFFF),
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              height: AppTypography.bodyLineHeight,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _StyleChoiceButton extends StatelessWidget {
  const _StyleChoiceButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
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
            if (isLoading)
              const SizedBox.square(
                dimension: 15,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 1.5,
                ),
              )
            else
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xB3FFFFFF),
                  fontSize: 13,
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
