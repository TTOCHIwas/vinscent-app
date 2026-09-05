import '../../../core/date/app_date_policy.dart';

bool shouldRefreshCalendarForPush(Map<String, dynamic> data) {
  return data['type'] == 'calendar_event_reminder';
}

bool shouldRefreshStoryLoopForPush(Map<String, dynamic> data) {
  final type = data['type'];
  if (type == 'ai_update') {
    return data['event_type'] == 'ai_feedback_ready';
  }
  return type == 'partner_answer_completed' ||
      type == 'daily_question_delivery' ||
      type == 'unanswered_reminder' ||
      type == 'question_generated' ||
      type == 'partner_story_card_uploaded';
}

String? resolvePushNotificationLocation(Map<String, dynamic> data) {
  final eventType = data['event_type'];
  if (eventType == 'ai_memory_review_ready') {
    return '/ai/memories';
  }

  final explicitRoute = _allowListedRoute(data['route']);
  if (explicitRoute != null) {
    return explicitRoute;
  }

  final notificationType = data['type'];
  return switch (notificationType) {
    'partner_answer_completed' => _questionLocation(data['assigned_date']),
    'daily_question_delivery' ||
    'unanswered_reminder' ||
    'question_generated' => _questionLocation(data['assigned_date']),
    'partner_story_card_uploaded' => '/home',
    'recording_activity' => _recordingLocation(eventType),
    'calendar_event_reminder' => _calendarLocation(data['event_date']),
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
    '/ai/memories',
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

  if ((uri.path == '/home/question' ||
          uri.path == '/calendar/question' ||
          uri.path == '/calendar') &&
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

String _calendarLocation(Object? eventDate) {
  if (!_isDate(eventDate)) {
    return '/calendar';
  }

  return Uri(
    path: '/calendar',
    queryParameters: {'date': eventDate as String},
  ).toString();
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
  return value is String && parseCalendarDate(value) != null;
}
