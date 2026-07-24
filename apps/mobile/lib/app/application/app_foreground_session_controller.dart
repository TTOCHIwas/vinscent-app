import 'package:flutter_riverpod/flutter_riverpod.dart';

final appForegroundSessionControllerProvider =
    NotifierProvider<AppForegroundSessionController, String>(
      AppForegroundSessionController.new,
    );

class AppForegroundSessionController extends Notifier<String> {
  var _sequence = 0;

  @override
  String build() => _nextId();

  void beginNewSession() {
    state = _nextId();
  }

  String _nextId() {
    _sequence += 1;
    return '${DateTime.now().microsecondsSinceEpoch}-$_sequence';
  }
}
