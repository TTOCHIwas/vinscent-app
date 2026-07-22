import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_camera_stage.dart';

void main() {
  late CameraPlatform originalPlatform;
  late _FakeCameraPlatform cameraPlatform;

  setUp(() {
    originalPlatform = CameraPlatform.instance;
    cameraPlatform = _FakeCameraPlatform();
    CameraPlatform.instance = cameraPlatform;
  });

  tearDown(() {
    CameraPlatform.instance = originalPlatform;
  });

  testWidgets('두 손가락 핀치로 카메라 배율을 변경한다', (tester) async {
    await tester.pumpWidget(_subject());
    await tester.pumpAndSettle();

    final preview = find.byKey(const ValueKey('story-card-camera-preview'));
    expect(preview, findsOneWidget);

    final center = tester.getCenter(preview);
    final first = await tester.startGesture(
      center - const Offset(30, 0),
      pointer: 1,
    );
    final second = await tester.startGesture(
      center + const Offset(30, 0),
      pointer: 2,
    );
    await tester.pump();
    await first.moveTo(center - const Offset(90, 0));
    await second.moveTo(center + const Offset(90, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pumpAndSettle();

    expect(cameraPlatform.zoomLevels, isNotEmpty);
    expect(cameraPlatform.zoomLevels.last, greaterThan(1));
    expect(
      cameraPlatform.zoomLevels.every((zoom) => zoom >= 1 && zoom <= 8),
      isTrue,
    );
  });

  testWidgets('전환 버튼으로 후면 카메라에서 전면 카메라로 바꾼다', (tester) async {
    await tester.pumpWidget(_subject());
    await tester.pumpAndSettle();

    expect(cameraPlatform.createdCameras, [_FakeCameraPlatform.backCamera]);

    await tester.tap(find.byKey(const ValueKey('story-card-camera-switch')));
    await tester.pumpAndSettle();

    expect(cameraPlatform.createdCameras, [
      _FakeCameraPlatform.backCamera,
      _FakeCameraPlatform.frontCamera,
    ]);
    expect(cameraPlatform.disposedCameraIds, contains(1));
  });

  testWidgets('앱 복귀 후에도 전환한 전면 카메라를 유지한다', (tester) async {
    await tester.pumpWidget(_subject());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('story-card-camera-switch')));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(cameraPlatform.createdCameras, [
      _FakeCameraPlatform.backCamera,
      _FakeCameraPlatform.frontCamera,
      _FakeCameraPlatform.frontCamera,
    ]);
  });
}

Widget _subject() {
  return MaterialApp(
    home: Scaffold(
      body: StoryCardCameraStage(
        onBack: () {},
        onImageSelected: (_) {},
        onTextSelected: () {},
        onDrawingSelected: () {},
      ),
    ),
  );
}

class _FakeCameraPlatform extends CameraPlatform {
  static const backCamera = CameraDescription(
    name: 'back',
    lensDirection: CameraLensDirection.back,
    sensorOrientation: 90,
  );
  static const frontCamera = CameraDescription(
    name: 'front',
    lensDirection: CameraLensDirection.front,
    sensorOrientation: 270,
  );

  final createdCameras = <CameraDescription>[];
  final disposedCameraIds = <int>[];
  final zoomLevels = <double>[];
  var _nextCameraId = 1;

  @override
  Future<List<CameraDescription>> availableCameras() async {
    return const [backCamera, frontCamera];
  }

  @override
  Future<int> createCamera(
    CameraDescription cameraDescription,
    ResolutionPreset? resolutionPreset, {
    bool enableAudio = false,
  }) async {
    createdCameras.add(cameraDescription);
    return _nextCameraId++;
  }

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {}

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) {
    return Stream.value(
      CameraInitializedEvent(
        cameraId,
        1080,
        1920,
        ExposureMode.auto,
        true,
        FocusMode.auto,
        true,
      ),
    );
  }

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() {
    return Stream.value(
      DeviceOrientationChangedEvent(DeviceOrientation.portraitUp),
    );
  }

  @override
  Future<double> getMinZoomLevel(int cameraId) async => 1;

  @override
  Future<double> getMaxZoomLevel(int cameraId) async => 8;

  @override
  Future<void> setZoomLevel(int cameraId, double zoom) async {
    zoomLevels.add(zoom);
  }

  @override
  Widget buildPreview(int cameraId) {
    return const ColoredBox(color: Colors.black);
  }

  @override
  Future<void> dispose(int cameraId) async {
    disposedCameraIds.add(cameraId);
  }
}
