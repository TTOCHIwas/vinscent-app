import 'package:flutter/widgets.dart';

class ShellBottomBarVisibilityNotification extends Notification {
  const ShellBottomBarVisibilityNotification({required this.isHidden});

  final bool isHidden;
}
