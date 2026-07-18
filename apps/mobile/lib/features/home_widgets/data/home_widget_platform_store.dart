import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../application/home_widget_synchronizer.dart';

final homeWidgetStoreProvider = Provider<HomeWidgetStore>((ref) {
  return const PluginHomeWidgetStore();
});

class PluginHomeWidgetStore implements HomeWidgetStore {
  const PluginHomeWidgetStore();

  @override
  Future<String?> read(String key) {
    return HomeWidget.getWidgetData<String>(key);
  }

  @override
  Future<void> write(String key, String value) async {
    await HomeWidget.saveWidgetData<String>(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await HomeWidget.saveWidgetData<String>(key, null);
  }

  @override
  Future<void> saveFile({
    required String key,
    required Uint8List bytes,
    required String extension,
  }) async {
    await HomeWidget.saveFile(key, bytes, extension: extension);
  }

  @override
  Future<void> updateAndroidWidget(String qualifiedProviderName) async {
    if (!Platform.isAndroid) {
      return;
    }
    await HomeWidget.updateWidget(qualifiedAndroidName: qualifiedProviderName);
  }
}
