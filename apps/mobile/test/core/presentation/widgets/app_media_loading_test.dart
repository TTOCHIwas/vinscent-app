import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/app_media_reveal.dart';
import 'package:vinscent/core/presentation/widgets/app_media_loading_group.dart';
import 'package:vinscent/core/presentation/widgets/app_sized_network_image.dart';
import 'package:vinscent/core/storage/image_bytes_cache.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_preview_surface.dart';
import 'package:vinscent/features/calendar/presentation/widgets/calendar_month_story_cell.dart';
import 'package:vinscent/features/calendar/data/couple_calendar_event.dart';

import '../../../support/story_loop_fixtures.dart';
import '../../../features/calendar/presentation/calendar_screen_test_support.dart';

void main() {
  tearDown(() {
    ImageBytesCache.shared.clear();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  for (final progress in [0.0, 1.0]) {
    testWidgets(
      'reveals both date cards together after unequal loads, expansion $progress',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        final bytes = (await tester.runAsync(_png))!;
        final first = Completer<HttpClientResponse>();
        final second = Completer<HttpClientResponse>();
        debugNetworkImageHttpClientProvider = () => _Client(
          bytes,
          responses: {'/first.png': first.future, '/second.png': second.future},
        );
        Widget calendar() => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 90,
              height: 180,
              child: CalendarMonthStoryCell(
                date: DateTime(2026, 5, 1),
                textColor: Colors.black,
                isSelected: false,
                expandedContentProgress: progress,
                summary: sampleMonthSummaryDay(
                  coupleDate: DateTime(2026, 5, 1),
                  cardCount: 2,
                  cards: [
                    for (final name in ['first', 'second'])
                      samplePreviewCard(
                        id: name,
                        submittedAt: DateTime(2026, 5, 1),
                      ).copyWith(previewUrl: 'https://audit.invalid/$name.png'),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpWidget(calendar());
        await tester.pump();
        expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
        await tester.runAsync(() async {
          final ready = _ready(
            tester.widgetList<Image>(find.byType(Image)).first,
          );
          first.complete(_Response(bytes));
          await ready;
        });
        await tester.pump();
        await tester.pump();
        expect(find.byType(RawImage), findsNothing);
        expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(calendar());
        expect(find.byType(RawImage), findsNothing);
        await tester.pump();
        expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
        await tester.runAsync(() async {
          final ready = _ready(
            tester.widgetList<Image>(find.byType(Image)).last,
          );
          second.complete(_Response(bytes));
          await ready;
        });
        await tester.pumpAndSettle();
        expect(find.byType(CupertinoActivityIndicator), findsNothing);
        expect(find.byType(RawImage), findsNWidgets(2));
        expect(tester.takeException(), isNull);
        debugNetworkImageHttpClientProvider = null;
      },
    );
  }

  for (final remove in [false, true]) {
    testWidgets(
      'clears the date spinner when a pending image is ${remove ? 'removed' : 'invalidated'}',
      (tester) async {
        final bytes = (await tester.runAsync(_png))!;
        final gate = Completer<HttpClientResponse>();
        final show = ValueNotifier(true);
        addTearDown(show.dispose);
        debugNetworkImageHttpClientProvider = () =>
            _Client(bytes, gate: gate.future);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox.square(
                dimension: 100,
                child: AppMediaLoadingGroup(
                  child: ValueListenableBuilder(
                    valueListenable: show,
                    builder: (context, value, _) => remove && !value
                        ? const SizedBox()
                        : AppSizedNetworkImage(
                            url: value
                                ? 'https://audit.invalid/pending-$remove.png'
                                : null,
                            logicalSize: const Size(80, 100),
                            gaplessPlayback: true,
                            fallbackBuilder: (_) => const Text('fallback'),
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
        show.value = false;
        await tester.pump();
        await tester.pump();
        expect(find.byType(CupertinoActivityIndicator), findsNothing);
        if (!remove) expect(find.text('fallback'), findsOneWidget);
        await tester.runAsync(() async {
          gate.complete(_Response(bytes));
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pump();
        expect(find.byType(CupertinoActivityIndicator), findsNothing);
        debugNetworkImageHttpClientProvider = null;
      },
    );
  }

  for (final progress in [0.0, 1.0]) {
    testWidgets(
      'shows one spinner per date for cards and artwork, expansion $progress',
      (tester) async {
        final bytes = (await tester.runAsync(_png))!;
        final gate = Completer<HttpClientResponse>();
        debugNetworkImageHttpClientProvider = () =>
            _Client(bytes, gate: gate.future);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  for (var day = 1; day <= 2; day++)
                    SizedBox(
                      width: 90,
                      height: progress == 0 ? 90 : 200,
                      child: CalendarMonthStoryCell(
                        key: ValueKey('date-$day'),
                        date: DateTime(2026, 5, day),
                        textColor: Colors.black,
                        isSelected: false,
                        expandedContentProgress: progress,
                        summary: sampleMonthSummaryDay(
                          coupleDate: DateTime(2026, 5, day),
                          cardCount: 2,
                          cards: [
                            for (var index = 0; index < 2; index++)
                              samplePreviewCard(
                                id: 'd$day-c$index',
                                submittedAt: DateTime(2026, 5, day),
                              ).copyWith(
                                previewUrl:
                                    'https://audit.invalid/d$day-c$index.png',
                              ),
                          ],
                        ),
                        events: [
                          calendarEvent(
                            id: 'event-$day',
                            title: '일정',
                            date: DateTime(2026, 5, day),
                            artwork: CoupleCalendarEventArtwork(
                              previewPath: 'art-$day',
                              drawingDataPath: 'draw-$day',
                              previewUrl: 'https://audit.invalid/art-$day.png',
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        for (var day = 1; day <= 2; day++) {
          expect(
            find.descendant(
              of: find.byKey(ValueKey('date-$day')),
              matching: find.byType(CupertinoActivityIndicator),
            ),
            findsOneWidget,
          );
        }
        expect(find.byType(CupertinoActivityIndicator), findsNWidgets(2));
        await tester.runAsync(() async {
          final ready = Future.wait(
            tester.widgetList<Image>(find.byType(Image)).map(_ready),
          );
          gate.complete(_Response(bytes));
          await ready;
        });
        await tester.pumpAndSettle();
        expect(find.byType(CupertinoActivityIndicator), findsNothing);
        expect(tester.takeException(), isNull);
        debugNetworkImageHttpClientProvider = null;
      },
    );
  }

  testWidgets('waits for decoded image before revealing the whole card once', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    final bytes = (await tester.runAsync(_png))!;
    final gate = Completer<HttpClientResponse>();
    final client = _Client(bytes, gate: gate.future);
    debugNetworkImageHttpClientProvider = () => client;
    var taps = 0;
    Widget card() => MaterialApp(
      home: Scaffold(
        body: Center(
          child: StoryCardPreviewSurface(
            previewUrl: 'https://audit.invalid/card.png',
            width: 120,
            onTap: () => taps++,
          ),
        ),
      ),
    );
    await tester.pumpWidget(card());
    await tester.pump();
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(_shadows(tester), isEmpty);
    final before = tester.getSize(find.byType(StoryCardPreviewSurface));
    await tester.runAsync(() async {
      final ready = _ready(tester.widget<Image>(find.byType(Image)));
      gate.complete(_Response(bytes));
      await ready;
    });
    await tester.pump();
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    expect(_shadows(tester), hasLength(1));
    final scale = find.descendant(
      of: find.byType(AppMediaReveal),
      matching: find.descendant(
        of: find.byType(AppMediaReveal),
        matching: find.byType(ScaleTransition),
      ),
    );
    expect(
      tester.widget<ScaleTransition>(scale).scale.value,
      closeTo(0.88, 0.01),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.widget<ScaleTransition>(scale).scale.value, greaterThan(1));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<ScaleTransition>(scale).scale.value, 1);
    expect(tester.getSize(find.byType(StoryCardPreviewSurface)), before);
    expect(
      tester.renderObject<RenderImage>(find.byType(RawImage)).image,
      isNotNull,
    );
    await tester.tap(find.byType(StoryCardPreviewSurface));
    expect(taps, 1);
    await tester.pumpWidget(card());
    expect(tester.widget<ScaleTransition>(scale).scale.value, 1);
    expect(client.requests, hasLength(1));
    debugNetworkImageHttpClientProvider = null;
  });

  testWidgets('different decode sizes share one encoded download', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    final bytes = (await tester.runAsync(_png))!;
    final client = _Client(bytes);
    debugNetworkImageHttpClientProvider = () => client;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              for (final size in [const Size(40, 50), const Size(80, 100)])
                AppSizedNetworkImage(
                  url: 'https://audit.invalid/shared.png',
                  logicalSize: size,
                  fallbackBuilder: (_) => const Text('error'),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future.wait(
        tester.widgetList<Image>(find.byType(Image)).map(_ready),
      );
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(client.requests, hasLength(1));
    final providers = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image as ResizeImage)
        .toList();
    expect(providers.map((p) => p.width), [40, 80]);
    expect(find.text('error'), findsNothing);
    debugNetworkImageHttpClientProvider = null;
  });

  testWidgets('gapless replacement retains the previous ready frame', (
    tester,
  ) async {
    final bytes = (await tester.runAsync(_png))!;
    debugNetworkImageHttpClientProvider = () => _Client(bytes);
    Widget image(String url) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: AppSizedNetworkImage(
            url: url,
            logicalSize: const Size(80, 100),
            gaplessPlayback: true,
            fallbackBuilder: (_) => const Text('error'),
          ),
        ),
      ),
    );
    await tester.pumpWidget(image('https://audit.invalid/old.png'));
    await tester.runAsync(
      () => _ready(tester.widget<Image>(find.byType(Image))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    final old = tester.renderObject<RenderImage>(find.byType(RawImage)).image;
    final gate = Completer<HttpClientResponse>();
    debugNetworkImageHttpClientProvider = () =>
        _Client(bytes, gate: gate.future);
    await tester.pumpWidget(image('https://audit.invalid/new.png'));
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    expect(
      tester.renderObject<RenderImage>(find.byType(RawImage)).image,
      same(old),
    );
    expect(
      tester
          .widget<ScaleTransition>(
            find.descendant(
              of: find.byType(AppMediaReveal),
              matching: find.byType(ScaleTransition),
            ),
          )
          .scale
          .value,
      1,
    );
    await tester.runAsync(() async {
      final ready = _ready(tester.widget<Image>(find.byType(Image)));
      gate.complete(_Response(bytes));
      await ready;
    });
    await tester.pump();
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    expect(
      tester
          .widget<ScaleTransition>(
            find.descendant(
              of: find.byType(AppMediaReveal),
              matching: find.byType(ScaleTransition),
            ),
          )
          .scale
          .value,
      1,
    );
    debugNetworkImageHttpClientProvider = null;
  });

  testWidgets('cached remount does not replay the spring', (tester) async {
    final bytes = (await tester.runAsync(_png))!;
    final client = _Client(bytes);
    debugNetworkImageHttpClientProvider = () => client;
    Widget image() => MaterialApp(
      home: Scaffold(
        body: Center(
          child: AppSizedNetworkImage(
            url: 'https://audit.invalid/cached.png',
            logicalSize: const Size(80, 100),
            fallbackBuilder: (_) => const Text('error'),
          ),
        ),
      ),
    );
    await tester.pumpWidget(image());
    await tester.runAsync(
      () => _ready(tester.widget<Image>(find.byType(Image))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(image());
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    expect(
      tester
          .widget<ScaleTransition>(
            find.descendant(
              of: find.byType(AppMediaReveal),
              matching: find.byType(ScaleTransition),
            ),
          )
          .scale
          .value,
      1,
    );
    expect(client.requests, hasLength(1));
    debugNetworkImageHttpClientProvider = null;
  });

  testWidgets('reduced motion shows the prepared content without a spring', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: AppMediaReveal(ready: true, child: Text('ready')),
        ),
      ),
    );
    expect(
      tester
          .widget<ScaleTransition>(
            find.descendant(
              of: find.byType(AppMediaReveal),
              matching: find.byType(ScaleTransition),
            ),
          )
          .scale
          .value,
      1,
    );
  });
}

Iterable<DecoratedBox> _shadows(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(StoryCardPreviewSurface),
        matching: find.byType(DecoratedBox),
      ),
    )
    .where(
      (box) =>
          box.decoration is BoxDecoration &&
          (box.decoration as BoxDecoration).boxShadow != null,
    );

Future<void> _ready(Image image) async {
  final ready = Completer<void>();
  final stream = image.image.resolve(const ImageConfiguration());
  final listener = ImageStreamListener(
    (info, synchronous) {
      if (!ready.isCompleted) ready.complete();
    },
    onError: (Object error, StackTrace? stack) {
      if (!ready.isCompleted) ready.completeError(error);
    },
  );
  stream.addListener(listener);
  try {
    await ready.future.timeout(const Duration(seconds: 5));
  } finally {
    stream.removeListener(listener);
  }
}

Future<Uint8List> _png() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(Colors.blue, BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(160, 200);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}

class _Client extends Fake implements HttpClient {
  _Client(this.bytes, {this.gate, this.responses});
  final Uint8List bytes;
  final Future<HttpClientResponse>? gate;
  final Map<String, Future<HttpClientResponse>>? responses;
  final requests = <Uri>[];
  @override
  Future<HttpClientRequest> getUrl(Uri uri) async {
    requests.add(uri);
    return _Request(
      responses?[uri.path] ?? gate ?? Future.value(_Response(bytes)),
    );
  }
}

class _Request extends Fake implements HttpClientRequest {
  _Request(this.response);
  final Future<HttpClientResponse> response;
  @override
  Future<HttpClientResponse> close() => response;
}

class _Response extends Fake implements HttpClientResponse {
  _Response(this.bytes);
  final Uint8List bytes;
  @override
  int get statusCode => HttpStatus.ok;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
}
