enum HomeWidgetLaunchAction {
  card,
  record;

  static HomeWidgetLaunchAction? fromUri(Uri? uri) {
    if (uri == null ||
        uri.scheme != 'vinscent' ||
        uri.host != 'widget' ||
        !uri.queryParameters.containsKey('homeWidget')) {
      return null;
    }

    return switch (uri.path) {
      '/card' => HomeWidgetLaunchAction.card,
      '/record' => HomeWidgetLaunchAction.record,
      _ => null,
    };
  }
}

class HomeWidgetCardLaunchPolicy {
  const HomeWidgetCardLaunchPolicy._();

  static const homeLocation = '/home';

  static String resolve() => homeLocation;
}
