typedef AccountUserDataCleanup = Future<void> Function(String userId);
typedef AccountDeviceDataCleanup = Future<void> Function();

enum AccountLocalDataCleanupOperation {
  proactiveSuggestion,
  calendarPreviewPreference,
  publicHolidayRegionPreference,
  deviceCalendarSync,
  homeFeedbackImpression,
  pendingRecordingDrafts,
  homeWidgets,
}

class AccountLocalDataCleanupFailure {
  const AccountLocalDataCleanupFailure({
    required this.operation,
    required this.error,
    required this.stackTrace,
  });

  final AccountLocalDataCleanupOperation operation;
  final Object error;
  final StackTrace stackTrace;
}

class AccountLocalDataCleanupResult {
  AccountLocalDataCleanupResult({
    required List<AccountLocalDataCleanupFailure> failures,
  }) : failures = List.unmodifiable(failures);

  final List<AccountLocalDataCleanupFailure> failures;

  bool get isComplete => failures.isEmpty;
}

class AccountLocalDataCleanup {
  const AccountLocalDataCleanup({
    required AccountUserDataCleanup clearProactiveSuggestion,
    required AccountUserDataCleanup clearCalendarPreviewPreference,
    required AccountUserDataCleanup clearPublicHolidayRegionPreference,
    required AccountUserDataCleanup clearDeviceCalendarSync,
    required AccountUserDataCleanup clearHomeFeedbackImpression,
    required AccountDeviceDataCleanup clearPendingRecordingDrafts,
    required AccountDeviceDataCleanup clearHomeWidgets,
  }) : _clearProactiveSuggestion = clearProactiveSuggestion,
       _clearCalendarPreviewPreference = clearCalendarPreviewPreference,
       _clearPublicHolidayRegionPreference = clearPublicHolidayRegionPreference,
       _clearDeviceCalendarSync = clearDeviceCalendarSync,
       _clearHomeFeedbackImpression = clearHomeFeedbackImpression,
       _clearPendingRecordingDrafts = clearPendingRecordingDrafts,
       _clearHomeWidgets = clearHomeWidgets;

  final AccountUserDataCleanup _clearProactiveSuggestion;
  final AccountUserDataCleanup _clearCalendarPreviewPreference;
  final AccountUserDataCleanup _clearPublicHolidayRegionPreference;
  final AccountUserDataCleanup _clearDeviceCalendarSync;
  final AccountUserDataCleanup _clearHomeFeedbackImpression;
  final AccountDeviceDataCleanup _clearPendingRecordingDrafts;
  final AccountDeviceDataCleanup _clearHomeWidgets;

  Future<AccountLocalDataCleanupResult> execute(String userId) async {
    final failures = <AccountLocalDataCleanupFailure>[];
    await _attempt(
      AccountLocalDataCleanupOperation.proactiveSuggestion,
      () => _clearProactiveSuggestion(userId),
      failures,
    );
    await _attempt(
      AccountLocalDataCleanupOperation.calendarPreviewPreference,
      () => _clearCalendarPreviewPreference(userId),
      failures,
    );
    await _attempt(
      AccountLocalDataCleanupOperation.publicHolidayRegionPreference,
      () => _clearPublicHolidayRegionPreference(userId),
      failures,
    );
    await _attempt(
      AccountLocalDataCleanupOperation.deviceCalendarSync,
      () => _clearDeviceCalendarSync(userId),
      failures,
    );
    await _attempt(
      AccountLocalDataCleanupOperation.homeFeedbackImpression,
      () => _clearHomeFeedbackImpression(userId),
      failures,
    );
    await _attempt(
      AccountLocalDataCleanupOperation.pendingRecordingDrafts,
      _clearPendingRecordingDrafts,
      failures,
    );
    await _attempt(
      AccountLocalDataCleanupOperation.homeWidgets,
      _clearHomeWidgets,
      failures,
    );
    return AccountLocalDataCleanupResult(failures: failures);
  }

  Future<void> _attempt(
    AccountLocalDataCleanupOperation operation,
    AccountDeviceDataCleanup cleanup,
    List<AccountLocalDataCleanupFailure> failures,
  ) async {
    try {
      await cleanup();
    } catch (error, stackTrace) {
      failures.add(
        AccountLocalDataCleanupFailure(
          operation: operation,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
