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
}
