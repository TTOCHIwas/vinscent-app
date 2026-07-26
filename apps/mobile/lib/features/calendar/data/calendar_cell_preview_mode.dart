enum CalendarCellPreviewMode {
  all('all'),
  cardsOnly('cards_only'),
  eventsOnly('events_only');

  const CalendarCellPreviewMode(this.storageValue);

  final String storageValue;

  bool get includesCards => this != CalendarCellPreviewMode.eventsOnly;

  bool get includesEvents => this != CalendarCellPreviewMode.cardsOnly;

  static CalendarCellPreviewMode fromStorageValue(String? value) {
    return CalendarCellPreviewMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => CalendarCellPreviewMode.all,
    );
  }
}
