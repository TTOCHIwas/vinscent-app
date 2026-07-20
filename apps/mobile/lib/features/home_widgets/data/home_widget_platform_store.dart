import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../application/home_widget_synchronizer.dart';
import 'home_widget_snapshot.dart';

final homeWidgetStoreProvider = Provider<HomeWidgetStore>((ref) {
  return const PluginHomeWidgetStore();
});

Future<void>? _homeWidgetConfiguration;

Future<void> configureHomeWidgetPlatform() {
  if (!Platform.isIOS) {
    return Future<void>.value();
  }
  return _homeWidgetConfiguration ??= HomeWidget.setAppGroupId(
    HomeWidgetStorage.appGroupId,
  ).then((_) {});
}

class PluginHomeWidgetStore implements HomeWidgetStore {
  const PluginHomeWidgetStore();

  @override
  Future<String?> read(String key) async {
    await configureHomeWidgetPlatform();
    return HomeWidget.getWidgetData<String>(key, appGroupId: _appGroupId);
  }

  @override
  Future<void> write(String key, String value) async {
    await configureHomeWidgetPlatform();
    await HomeWidget.saveWidgetData<String>(
      key,
      value,
      appGroupId: _appGroupId,
    );
  }

  @override
  Future<void> remove(String key) async {
    await configureHomeWidgetPlatform();
    await HomeWidget.saveWidgetData<String>(key, null, appGroupId: _appGroupId);
  }

  @override
  Future<void> saveFile({
    required String key,
    required Uint8List bytes,
    required String extension,
  }) async {
    await configureHomeWidgetPlatform();
    await HomeWidget.saveFile(
      key,
      bytes,
      extension: extension,
      appGroupId: _appGroupId,
    );
  }

  @override
  Future<void> refreshWidget(HomeWidgetTarget target) async {
    if (Platform.isAndroid) {
      await HomeWidget.updateWidget(
        qualifiedAndroidName: target.qualifiedAndroidName,
      );
    } else if (Platform.isIOS) {
      await configureHomeWidgetPlatform();
      await HomeWidget.updateWidget(iOSName: target.iOSName);
    }
  }

  String? get _appGroupId =>
      Platform.isIOS ? HomeWidgetStorage.appGroupId : null;
}
