import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/app_sized_network_image.dart';

void main() {
  testWidgets('decodes a valid image at its rendered pixel size', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AppSizedNetworkImage(
          url: 'https://example.com/preview.png',
          logicalSize: const Size(40, 50),
          fallbackBuilder: (_) => const Text('fallback'),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as ResizeImage;
    expect(image.width, 40);
    expect(image.height, 50);
    expect(provider.width, 80);
    expect(provider.height, 100);
  });

  testWidgets('uses the fallback for an invalid URL', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppSizedNetworkImage(
          url: 'not-a-network-url',
          logicalSize: const Size(40, 50),
          fallbackBuilder: (_) => const Text('fallback'),
        ),
      ),
    );

    expect(find.text('fallback'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('keeps one cache key while the rendered size changes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<Object> pumpImage(Size logicalSize) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppSizedNetworkImage(
            url: 'https://example.com/preview.png',
            logicalSize: logicalSize,
            cacheLogicalSize: const Size(80, 100),
            gaplessPlayback: true,
            fallbackBuilder: (_) => const Text('fallback'),
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, logicalSize.width);
      expect(image.height, logicalSize.height);
      expect(image.gaplessPlayback, true);
      return image.image.obtainKey(const ImageConfiguration());
    }

    final compactKey = await pumpImage(const Size(40, 50));
    final expandedKey = await pumpImage(const Size(64, 80));

    expect(expandedKey, compactKey);
  });
}
