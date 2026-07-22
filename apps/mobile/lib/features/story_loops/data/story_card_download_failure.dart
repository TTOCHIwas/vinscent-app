enum StoryCardDownloadFailureReason {
  configMissing,
  cardNotFound,
  requestTimeout,
  sourceUnavailable,
  invalidSource,
  renderFailed,
  accessDenied,
  notEnoughSpace,
  notSupported,
  unknown,
}

class StoryCardDownloadException implements Exception {
  const StoryCardDownloadException(this.reason, [this.message]);

  final StoryCardDownloadFailureReason reason;
  final String? message;
}
