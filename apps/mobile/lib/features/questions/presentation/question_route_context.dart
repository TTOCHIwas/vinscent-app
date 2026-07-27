import '../../../core/date/app_date_policy.dart';

enum QuestionRouteSource {
  home,
  calendar;

  factory QuestionRouteSource.fromQuery(String? value) {
    return switch (value) {
      'calendar' => QuestionRouteSource.calendar,
      _ => QuestionRouteSource.home,
    };
  }

  String get queryValue => switch (this) {
    QuestionRouteSource.home => 'home',
    QuestionRouteSource.calendar => 'calendar',
  };

  String get questionPath => switch (this) {
    QuestionRouteSource.home => '/home/question',
    QuestionRouteSource.calendar => '/calendar/question',
  };
}

class QuestionRouteContext {
  const QuestionRouteContext({required this.source, this.targetDate});

  factory QuestionRouteContext.fromEditUri(Uri uri) {
    return QuestionRouteContext(
      source: QuestionRouteSource.fromQuery(uri.queryParameters['source']),
      targetDate: parseQuestionRouteDate(uri.queryParameters['date']),
    );
  }

  factory QuestionRouteContext.fromQuestionScreen({
    required String backLocation,
    DateTime? targetDate,
  }) {
    return QuestionRouteContext(
      source: backLocation == '/calendar'
          ? QuestionRouteSource.calendar
          : QuestionRouteSource.home,
      targetDate: targetDate,
    );
  }

  final QuestionRouteSource source;
  final DateTime? targetDate;

  String buildQuestionLocation() {
    final normalizedTargetDate = targetDate == null
        ? null
        : calendarDateOnly(targetDate!);
    if (normalizedTargetDate == null) {
      return source.questionPath;
    }

    return '${source.questionPath}?date=${formatQuestionRouteDate(normalizedTargetDate)}';
  }

  String buildEditLocation() {
    final buffer = StringBuffer(
      '/home/question/edit?source=${source.queryValue}',
    );
    final normalizedTargetDate = targetDate == null
        ? null
        : calendarDateOnly(targetDate!);
    if (normalizedTargetDate != null) {
      buffer.write('&date=${formatQuestionRouteDate(normalizedTargetDate)}');
    }

    return buffer.toString();
  }
}

DateTime? parseQuestionRouteDate(String? value) {
  return parseCalendarDate(value);
}

bool hasInvalidQuestionRouteDate(String? value) {
  return hasInvalidCalendarDate(value);
}

String formatQuestionRouteDate(DateTime date) {
  return formatCalendarDate(date);
}
