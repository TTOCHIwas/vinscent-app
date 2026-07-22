import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../application/home_widget_synchronizer.dart';
import 'home_widget_asset_validator.dart';
import 'home_widget_snapshot.dart';

final homeWidgetStoreProvider = Provider<HomeWidgetStore>((ref) {
  return const PluginHomeWidgetStore();
});

Future<void>? _homeWidgetConfiguration;

Future<void> configureHomeWidgetPlatform() async {
  if (!Platform.isIOS) {
    return;
  }

  final activeConfiguration = _homeWidgetConfiguration;
  if (activeConfiguration != null) {
    await activeConfiguration;
    return;
  }

  final configuration = HomeWidget.setAppGroupId(
    HomeWidgetStorage.appGroupId,
  ).then((_) {});
  _homeWidgetConfiguration = configuration;
  try {
    await configuration;
  } catch (_) {
    if (identical(_homeWidgetConfiguration, configuration)) {
      _homeWidgetConfiguration = null;
    }
    rethrow;
  }
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
    final path = await HomeWidget.getWidgetData<String>(
      key,
      appGroupId: _appGroupId,
    );
    if (path != null && _isManagedWidgetFile(path, key)) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await HomeWidget.saveWidgetData<String>(key, null, appGroupId: _appGroupId);
  }

  @override
  Future<String> saveFile({
    required String key,
    required Uint8List bytes,
    required String extension,
  }) async {
    await configureHomeWidgetPlatform();
    return await HomeWidget.saveFile(
      key,
      bytes,
      extension: extension,
      appGroupId: _appGroupId,
    );
  }

  @override
  Future<bool> isFileUsable(String path, {required String extension}) async {
    try {
      final file = File(path);
      if (!await file.exists() || await file.length() == 0) {
        return false;
      }

      final reader = await file.open();
      try {
        final header = await reader.read(12);
        return isValidHomeWidgetAsset(header, extension);
      } finally {
        await reader.close();
      }
    } on FileSystemException {
      return false;
    }
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

  bool _isManagedWidgetFile(String path, String key) {
    final file = File(path);
    final segments = file.parent.uri.pathSegments.where(
      (segment) => segment.isNotEmpty,
    );
    return segments.isNotEmpty &&
        segments.last == 'home_widget' &&
        file.uri.pathSegments.last.startsWith('$key.');
  }
}
