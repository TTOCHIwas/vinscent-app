import '../../couple/data/couple.dart';
import 'story_card_stack_preview.dart';

class TodayStoryCardStacks {
  const TodayStoryCardStacks({
    required this.coupleId,
    required this.coupleDate,
    required this.accessMode,
    required this.canCreateCard,
    required this.stacks,
  });

  final String coupleId;
  final DateTime coupleDate;
  final CoupleAccessMode accessMode;
  final bool canCreateCard;
  final List<StoryCardStackPreview> stacks;

  StoryCardStackPreview? get myStack {
    for (final stack in stacks) {
      if (stack.isMine) {
        return stack;
      }
    }
    return null;
  }

  StoryCardStackPreview? get partnerStack {
    for (final stack in stacks) {
      if (!stack.isMine) {
        return stack;
      }
    }
    return null;
  }
}
