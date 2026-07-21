String? resolvePushNotificationLocation(Map<String, dynamic> data) {
  final explicitRoute = _allowListedRoute(data['route']);
  if (explicitRoute != null) {
    return explicitRoute;
  }

  final notificationType = data['type'];
  final eventType = data['event_type'];

  return switch (notificationType) {
    'partner_answer_completed' => _questionLocation(data['assigned_date']),
    'daily_question_delivery' ||
    'unanswered_reminder' ||
    'question_generated' => _questionLocation(data['assigned_date']),
    'partner_story_card_uploaded' => '/home',
    'recording_activity' => _recordingLocation(eventType),
    'couple_disconnect' => '/settings/couple',
    'couple_activity' => '/home',
    'ai_update' =>
      eventType == 'ai_feedback_ready'
          ? _questionLocation(data['assigned_date'])
          : '/ai',
    _ => null,
  };
}

String? _allowListedRoute(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !value.startsWith('/') ||
      value.startsWith('//')) {
    return null;
  }

  const allowedPaths = {
    '/home',
    '/home/question',
    '/home/recordings',
    '/calendar',
    '/calendar/question',
    '/ai',
    '/settings',
    '/settings/notifications',
    '/settings/character',
    '/settings/couple',
  };
  if (!allowedPaths.contains(uri.path)) {
    return null;
  }

  if (uri.queryParameters.isEmpty) {
    return uri.path;
  }

  if ((uri.path == '/home/question' || uri.path == '/calendar/question') &&
      uri.queryParameters.length == 1 &&
      _isDate(uri.queryParameters['date'])) {
    return uri.toString();
  }

  return null;
}

String _recordingLocation(Object? eventType) {
  return eventType == 'current_recording_updated'
      ? '/home'
      : '/home/recordings';
}

String _questionLocation(Object? assignedDate) {
  if (!_isDate(assignedDate)) {
    return '/home/question';
  }

  return Uri(
    path: '/home/question',
    queryParameters: {'date': assignedDate as String},
  ).toString();
}

bool _isDate(Object? value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return false;
  }

  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return false;
  }

  final normalized =
      '${parsed.year.toString().padLeft(4, '0')}-'
      '${parsed.month.toString().padLeft(2, '0')}-'
      '${parsed.day.toString().padLeft(2, '0')}';
  return normalized == value;
}
