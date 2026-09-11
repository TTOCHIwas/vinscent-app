import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const storyCardEditorLocation = '/home/story';
const storyCardEditorSwipeRightLocation =
    '$storyCardEditorLocation?entry=home-swipe-right';

Page<void> buildStoryCardEditorPage({
  required LocalKey key,
  required Uri uri,
  required Widget child,
}) {
  if (uri.queryParameters['entry'] != 'home-swipe-right') {
    return MaterialPage<void>(key: key, child: child);
  }

  return CustomTransitionPage<void>(
    key: key,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final position = Tween<Offset>(
        begin: const Offset(-1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return SlideTransition(
        key: const Key('story-card-editor-slide-transition'),
        position: position,
        child: child,
      );
    },
  );
}
