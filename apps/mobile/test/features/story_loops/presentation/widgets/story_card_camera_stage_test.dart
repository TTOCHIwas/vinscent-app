import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart' show CameraImage;
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vinscent/features/story_loops/application/story_card_face_detector.dart';
import 'package:vinscent/features/story_loops/application/story_card_face_effect.dart';
import 'package:vinscent/features/story_loops/data/story_card_film_look.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_camera_stage.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_editor_action_bar.dart';

void main() {
  late CameraPlatform originalPlatform;
  late _FakeCameraPlatform cameraPlatform;

  setUp(() {
    originalPlatform = CameraPlatform.instance;
    cameraPlatform = _FakeCameraPlatform();
    CameraPlatform.instance = cameraPlatform;
  });

  tearDown(() {
    cameraPlatform.close();
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

  testWidgets('Android 얼굴 인식에 필요한 NV21 프레임을 요청한다', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(_subject());
      await tester.pumpAndSettle();

      expect(cameraPlatform.requestedImageFormats, [ImageFormatGroup.nv21]);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('연속 핀치 입력은 최신 배율만 제한된 빈도로 전달한다', (tester) async {
    await tester.pumpWidget(_subject());
    await tester.pumpAndSettle();

    final preview = find.byKey(const ValueKey('story-card-camera-preview'));
    final center = tester.getCenter(preview);
    final first = await tester.startGesture(
      center - const Offset(24, 0),
      pointer: 1,
    );
    final second = await tester.startGesture(
      center + const Offset(24, 0),
      pointer: 2,
    );
    await tester.pump();

    for (var index = 0; index < 12; index += 1) {
      final distance = 30.0 + index * 6;
      await first.moveTo(center - Offset(distance, 0));
      await second.moveTo(center + Offset(distance, 0));
    }
    await first.up();
    await second.up();
    await tester.pump(const Duration(milliseconds: 160));

    expect(cameraPlatform.zoomLevels, isNotEmpty);
    expect(cameraPlatform.zoomLevels.length, lessThan(12));
    expect(cameraPlatform.zoomLevels.last, greaterThan(1));
  });

  testWidgets('좌우 스와이프로 필터를 순환하고 이름을 잠시 표시한다', (tester) async {
    StoryCardFilmState? selectedFilm;
    await tester.pumpWidget(
      _subject(onFilmChanged: (film) => selectedFilm = film),
    );
    await tester.pumpAndSettle();

    final preview = find.byKey(const ValueKey('story-card-camera-preview'));
    await tester.drag(preview, const Offset(-140, 0));
    await tester.pump();

    expect(selectedFilm?.look, StoryCardFilmLook.warmth);
    expect(
      find.byKey(const ValueKey('story-card-camera-film-announcement')),
      findsOneWidget,
    );
    expect(find.text('온기'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1200));
    expect(
      find.byKey(const ValueKey('story-card-camera-film-announcement')),
      findsNothing,
    );

    await tester.drag(preview, const Offset(140, 0));
    await tester.pump();
    expect(selectedFilm?.look, StoryCardFilmLook.original);
  });

  testWidgets('위아래 스와이프로 전후면 카메라를 전환한다', (tester) async {
    await tester.pumpWidget(_subject());
    await tester.pumpAndSettle();

    final preview = find.byKey(const ValueKey('story-card-camera-preview'));
    await tester.drag(preview, const Offset(0, -140));
    await tester.pumpAndSettle();

    expect(cameraPlatform.createdCameras, [
      _FakeCameraPlatform.backCamera,
      _FakeCameraPlatform.frontCamera,
    ]);
  });

  testWidgets('미리보기를 누르면 초점과 노출 지점을 지정하고 밝기 바를 표시한다', (tester) async {
    StoryCardFilmState? selectedFilm;
    await tester.pumpWidget(
      _subject(onFilmChanged: (film) => selectedFilm = film),
    );
    await tester.pumpAndSettle();

    final preview = find.byKey(const ValueKey('story-card-camera-preview'));
    await tester.tapAt(tester.getCenter(preview));
    await tester.pump();

    expect(cameraPlatform.focusPoints, hasLength(1));
    expect(cameraPlatform.exposurePoints, hasLength(1));
    expect(cameraPlatform.focusPoints.single.x, closeTo(0.5, 0.01));
    expect(cameraPlatform.focusPoints.single.y, closeTo(0.5, 0.01));
    expect(
      find.byKey(const ValueKey('story-card-camera-focus-indicator')),
      findsOneWidget,
    );
    final focusIndicator = find.byKey(
      const ValueKey('story-card-camera-focus-indicator'),
    );
    expect(tester.getSize(focusIndicator), const Size.square(64));
    expect(tester.widget<CustomPaint>(focusIndicator).painter, isNotNull);
    expect(
      find.descendant(of: focusIndicator, matching: find.byType(DecoratedBox)),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('story-card-camera-exposure-slider')),
      findsOneWidget,
    );
    expect(find.byType(Slider), findsNothing);
    expect(find.byIcon(LucideIcons.sun), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('story-card-camera-exposure-slider')),
      const Offset(70, 0),
    );
    await tester.pump(const Duration(milliseconds: 120));

    expect(cameraPlatform.exposureOffsets, isNotEmpty);
    expect(cameraPlatform.exposureOffsets.last, greaterThan(0));
    expect(selectedFilm, isNull);
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

  testWidgets('촬영 전 텍스트와 그리기 도구도 편집 화면 액션 바를 사용한다', (tester) async {
    await tester.pumpWidget(_subject());
    await tester.pumpAndSettle();

    final actionBar = find.byType(StoryCardEditorActionBar);
    expect(actionBar, findsOneWidget);
    expect(find.byKey(const ValueKey('story-card-caption-tool')), findsNothing);

    final stageCenter = tester.getCenter(find.byType(StoryCardCameraStage));
    final actionBarCenter = tester.getCenter(actionBar);
    expect(actionBarCenter.dy, closeTo(stageCenter.dy, 1));
    expect(actionBarCenter.dx, greaterThan(stageCenter.dx));
  });

  testWidgets('하단 카메라 조작계를 중앙 셔터 기준으로 대칭 배치한다', (tester) async {
    await tester.pumpWidget(_subject());
    await tester.pumpAndSettle();

    final gallery = find.byKey(const ValueKey('story-card-camera-gallery'));
    final capture = find.byKey(const ValueKey('story-card-camera-capture'));
    final cameraSwitch = find.byKey(const ValueKey('story-card-camera-switch'));
    final galleryCenter = tester.getCenter(gallery);
    final captureCenter = tester.getCenter(capture);
    final switchCenter = tester.getCenter(cameraSwitch);

    expect(find.byIcon(LucideIcons.image), findsOneWidget);
    expect(find.byIcon(LucideIcons.refreshCcw), findsOneWidget);
    expect(tester.getSize(gallery), const Size.square(54));
    expect(tester.getSize(capture), const Size.square(80));
    expect(tester.getSize(cameraSwitch), const Size.square(54));
    expect(galleryCenter.dx, lessThan(captureCenter.dx));
    expect(switchCenter.dx, greaterThan(captureCenter.dx));
    expect(
      captureCenter.dx - galleryCenter.dx,
      closeTo(switchCenter.dx - captureCenter.dx, 1),
    );
    expect(galleryCenter.dy, closeTo(captureCenter.dy, 1));
    expect(switchCenter.dy, closeTo(captureCenter.dy, 1));
  });

  testWidgets('최초 카메라에는 카드 프레임 가이드를 표시하지 않는다', (tester) async {
    await tester.pumpWidget(_subject());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('story-card-camera-crop-guide')),
      findsNothing,
    );
  });

  testWidgets('사진 칸 카메라는 대상 비율 가이드와 임시저장함 진입을 제공한다', (tester) async {
    var draftsPressed = false;
    await tester.pumpWidget(
      _subject(
        guideAspectRatio: 1,
        draftCount: 2,
        onDraftsPressed: () => draftsPressed = true,
      ),
    );
    await tester.pumpAndSettle();

    final close = find.byKey(const ValueKey('story-card-camera-close'));
    final drafts = find.byKey(const ValueKey('story-card-camera-drafts'));
    final guide = find.byKey(const ValueKey('story-card-camera-crop-guide'));
    expect(guide, findsOneWidget);
    expect(tester.getSize(guide).aspectRatio, closeTo(1, 0.01));
    expect(drafts, findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(
      tester.getCenter(drafts).dx,
      greaterThan(tester.getCenter(close).dx),
    );

    await tester.tap(drafts);
    expect(draftsPressed, isTrue);
  });

  testWidgets('필름 도구에서 촬영 전 룩을 선택한다', (tester) async {
    StoryCardFilmState? selectedFilm;
    await tester.pumpWidget(
      _subject(onFilmChanged: (film) => selectedFilm = film),
    );
    await tester.pumpAndSettle();

    final filmTool = find.byKey(const ValueKey('story-card-film-tool'));
    expect(
      find.descendant(
        of: filmTool,
        matching: find.byIcon(LucideIcons.wandSparkles),
      ),
      findsOneWidget,
    );

    await tester.tap(filmTool);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('story-card-camera-film-selector')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('story-card-camera-film-quiet')),
    );
    await tester.pump();

    expect(selectedFilm?.look, StoryCardFilmLook.quiet);
    expect(selectedFilm?.seed, greaterThan(0));
  });

  testWidgets('캐릭터 효과를 선택한 동안만 얼굴을 추적해 미리보기에 표시한다', (tester) async {
    final detector = _FakeStoryCardFaceDetector();
    final character = image.Image(width: 32, height: 32, numChannels: 4);
    image.fill(character, color: image.ColorRgba8(230, 30, 40, 255));
    await tester.pumpWidget(
      _subject(
        faceDetector: detector,
        loadCharacterImage: () async =>
            Uint8List.fromList(image.encodePng(character)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('story-card-film-tool')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('story-card-style-effect-tab')));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('story-card-camera-effect-couple-character')),
    );
    await tester.pumpAndSettle();

    expect(cameraPlatform.hasImageStreamListener, isTrue);
    cameraPlatform.emitImage();
    await tester.pump();
    await tester.pump();

    expect(detector.cameraDetectionCount, 1);
    expect(
      find.byKey(const ValueKey('story-card-camera-character-effect')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('story-card-camera-effect-none')),
    );
    await tester.pumpAndSettle();

    expect(cameraPlatform.hasImageStreamListener, isFalse);
    expect(
      find.byKey(const ValueKey('story-card-camera-character-effect')),
      findsNothing,
    );
  });

  testWidgets('화면 종료 중 얼굴 감지기 정리 실패가 전역 예외로 새지 않는다', (tester) async {
    final detector = _FakeStoryCardFaceDetector(throwOnClose: true);
    final character = image.Image(width: 32, height: 32, numChannels: 4);
    image.fill(character, color: image.ColorRgba8(230, 30, 40, 255));
    await tester.pumpWidget(
      _subject(
        faceDetector: detector,
        loadCharacterImage: () async =>
            Uint8List.fromList(image.encodePng(character)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('story-card-film-tool')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('story-card-style-effect-tab')));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('story-card-camera-effect-couple-character')),
    );
    await tester.pumpAndSettle();
    expect(cameraPlatform.hasImageStreamListener, isTrue);
    cameraPlatform.emitImage();
    await tester.pump();
    await tester.pump();
    expect(detector.cameraDetectionCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();

    expect(detector.closeCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('플래시는 off에서 auto로 전환한다', (tester) async {
    await tester.pumpWidget(_subject());
    await tester.pumpAndSettle();

    expect(cameraPlatform.flashModes, [FlashMode.off]);
    await tester.tap(find.byKey(const ValueKey('story-card-camera-flash')));
    await tester.pumpAndSettle();

    expect(cameraPlatform.flashModes, [FlashMode.off, FlashMode.auto]);
  });
}

Widget _subject({
  ValueChanged<StoryCardFilmState>? onFilmChanged,
  StoryCardFaceDetector? faceDetector,
  Future<Uint8List?> Function()? loadCharacterImage,
  double? guideAspectRatio,
  int draftCount = 0,
  VoidCallback? onDraftsPressed,
}) {
  return MaterialApp(
    home: Scaffold(
      body: StoryCardCameraStage(
        onBack: () {},
        onImageSelected: (_) {},
        onFilmChanged: onFilmChanged,
        faceDetector: faceDetector,
        loadCharacterImage: loadCharacterImage,
        guideAspectRatio: guideAspectRatio,
        draftCount: draftCount,
        onDraftsPressed: onDraftsPressed,
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
  final flashModes = <FlashMode>[];
  final focusPoints = <math.Point<double>>[];
  final exposurePoints = <math.Point<double>>[];
  final exposureOffsets = <double>[];
  final requestedImageFormats = <ImageFormatGroup>[];
  final _imageStream = StreamController<CameraImageData>.broadcast(sync: true);
  var _nextCameraId = 1;

  bool get hasImageStreamListener => _imageStream.hasListener;

  void emitImage() {
    _imageStream.add(
      CameraImageData(
        format: const CameraImageFormat(ImageFormatGroup.nv21, raw: 17),
        planes: [
          CameraImagePlane(
            bytes: Uint8List(24),
            bytesPerRow: 4,
            width: 4,
            height: 4,
          ),
        ],
        height: 4,
        width: 4,
      ),
    );
  }

  void close() {
    unawaited(_imageStream.close());
  }

  @override
  Future<List<CameraDescription>> availableCameras() async {
    return const [backCamera, frontCamera];
  }

  @override
  bool supportsImageStreaming() => true;

  @override
  Stream<CameraImageData> onStreamedFrameAvailable(
    int cameraId, {
    CameraImageStreamOptions? options,
  }) {
    return _imageStream.stream;
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
  }) async {
    requestedImageFormats.add(imageFormatGroup);
  }

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
  Future<double> getMinExposureOffset(int cameraId) async => -2;

  @override
  Future<double> getMaxExposureOffset(int cameraId) async => 2;

  @override
  Future<double> getExposureOffsetStepSize(int cameraId) async => 0.25;

  @override
  Future<void> setZoomLevel(int cameraId, double zoom) async {
    zoomLevels.add(zoom);
  }

  @override
  Future<void> setFlashMode(int cameraId, FlashMode mode) async {
    flashModes.add(mode);
  }

  @override
  Future<void> setFocusPoint(int cameraId, math.Point<double>? point) async {
    if (point != null) {
      focusPoints.add(point);
    }
  }

  @override
  Future<void> setExposurePoint(int cameraId, math.Point<double>? point) async {
    if (point != null) {
      exposurePoints.add(point);
    }
  }

  @override
  Future<double> setExposureOffset(int cameraId, double offset) async {
    exposureOffsets.add(offset);
    return offset;
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

class _FakeStoryCardFaceDetector implements StoryCardFaceDetector {
  _FakeStoryCardFaceDetector({this.throwOnClose = false});

  final bool throwOnClose;
  int cameraDetectionCount = 0;
  int fileDetectionCount = 0;
  int closeCount = 0;

  @override
  Future<List<StoryCardFaceObservation>> detectCameraImage({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) async {
    cameraDetectionCount += 1;
    return const [
      StoryCardFaceObservation(
        normalizedBounds: Rect.fromLTWH(0.3, 0.32, 0.24, 0.28),
      ),
    ];
  }

  @override
  Future<List<StoryCardFaceObservation>> detectFile({
    required String path,
    required Size uprightSize,
  }) async {
    fileDetectionCount += 1;
    return const [
      StoryCardFaceObservation(
        normalizedBounds: Rect.fromLTWH(0.3, 0.2, 0.24, 0.28),
      ),
    ];
  }

  @override
  Future<void> close() async {
    closeCount += 1;
    if (throwOnClose) {
      throw StateError('close failed');
    }
  }
}
