enum StoryCardCameraEffect {
  none(id: 'none', label: '없음'),
  coupleCharacter(id: 'couple-character', label: '캐릭터');

  const StoryCardCameraEffect({required this.id, required this.label});

  final String id;
  final String label;
}
