import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../data/story_card_draft.dart';
import '../data/story_card_scene.dart';

final storyCardLocalDraftRepositoryProvider =
    Provider<StoryCardLocalDraftRepository>((ref) {
      const uuid = Uuid();
      return FileStoryCardLocalDraftRepository(
        cacheDirectoryLoader: getApplicationCacheDirectory,
        now: DateTime.now,
        idFactory: uuid.v4,
      );
    });

abstract interface class StoryCardLocalDraftRepository {
  Future<List<StoryCardLocalDraftSummary>> list();

  Future<StoryCardLocalDraftSummary> save({
    required StoryCardDraft draft,
    required Uint8List previewImageBytes,
  });

  Future<StoryCardDraft?> take(String id);

  Future<void> delete(String id);
}

class StoryCardLocalDraftSummary {
  const StoryCardLocalDraftSummary({
    required this.id,
    required this.savedAt,
    required this.expiresAt,
    required this.previewImageBytes,
  });

  final String id;
  final DateTime savedAt;
  final DateTime expiresAt;
  final Uint8List previewImageBytes;
}

class FileStoryCardLocalDraftRepository
    implements StoryCardLocalDraftRepository {
  FileStoryCardLocalDraftRepository({
    required Future<Directory> Function() cacheDirectoryLoader,
    required DateTime Function() now,
    required String Function() idFactory,
  }) : _cacheDirectoryLoader = cacheDirectoryLoader,
       _now = now,
       _idFactory = idFactory;

  static const retention = Duration(hours: 72);
  static const _rootDirectoryName = 'story_card_drafts';
  static const _manifestFileName = 'manifest.json';
  static const _previewFileName = 'preview.png';

  final Future<Directory> Function() _cacheDirectoryLoader;
  final DateTime Function() _now;
  final String Function() _idFactory;
  final Set<String> _activeWritingPaths = {};

  @override
  Future<List<StoryCardLocalDraftSummary>> list() async {
    final root = await _rootDirectory(create: false);
    if (!await root.exists()) {
      return const [];
    }

    final summaries = <StoryCardLocalDraftSummary>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) {
        continue;
      }
      if (entity.path.endsWith('.writing')) {
        if (!_activeWritingPaths.contains(entity.path)) {
          await _deleteDirectory(entity);
        }
        continue;
      }
      final summary = await _readSummary(entity);
      if (summary == null || !_now().isBefore(summary.expiresAt)) {
        await _deleteDirectory(entity);
        continue;
      }
      summaries.add(summary);
    }
    summaries.sort((left, right) => right.savedAt.compareTo(left.savedAt));
    return summaries;
  }

  @override
  Future<StoryCardLocalDraftSummary> save({
    required StoryCardDraft draft,
    required Uint8List previewImageBytes,
  }) async {
    await list();
    final root = await _rootDirectory(create: true);
    final id = _idFactory();
    final savedAt = _now();
    final expiresAt = savedAt.add(retention);
    final target = Directory(_join(root.path, id));
    final writing = Directory(_join(root.path, '$id.writing'));
    await _deleteDirectory(writing);
    _activeWritingPaths.add(writing.path);
    try {
      await writing.create(recursive: true);

      final photoFiles = <String?>[];
      final photos = draft.storedPhotoImageBytes;
      for (var index = 0; index < photos.length; index++) {
        final bytes = photos[index];
        if (bytes == null) {
          photoFiles.add(null);
          continue;
        }
        final fileName = 'photo_$index.bin';
        await File(
          _join(writing.path, fileName),
        ).writeAsBytes(bytes, flush: true);
        photoFiles.add(fileName);
      }
      await File(
        _join(writing.path, _previewFileName),
      ).writeAsBytes(previewImageBytes, flush: true);
      await File(_join(writing.path, _manifestFileName)).writeAsString(
        jsonEncode({
          'id': id,
          'saved_at': savedAt.toUtc().toIso8601String(),
          'expires_at': expiresAt.toUtc().toIso8601String(),
          'scene': draft.scene.toJson(includeInactivePhotoState: true),
          'photo_files': photoFiles,
        }),
        flush: true,
      );

      await _deleteDirectory(target);
      await writing.rename(target.path);
      return StoryCardLocalDraftSummary(
        id: id,
        savedAt: savedAt,
        expiresAt: expiresAt,
        previewImageBytes: Uint8List.fromList(previewImageBytes),
      );
    } finally {
      _activeWritingPaths.remove(writing.path);
      await _deleteDirectory(writing);
    }
  }

  @override
  Future<StoryCardDraft?> take(String id) async {
    final directory = await _draftDirectory(id);
    if (!await directory.exists()) {
      return null;
    }
    try {
      final manifest = await _readManifest(directory);
      final expiresAt = DateTime.parse(manifest['expires_at'] as String);
      if (!_now().isBefore(expiresAt)) {
        return null;
      }
      final photoFiles = manifest['photo_files'] as List<dynamic>? ?? const [];
      final photos = <Uint8List?>[];
      for (final value in photoFiles) {
        if (value == null) {
          photos.add(null);
        } else {
          photos.add(
            await File(_join(directory.path, value as String)).readAsBytes(),
          );
        }
      }
      final scene = StoryCardScene.fromJson(
        Map<String, dynamic>.from(manifest['scene'] as Map),
      );
      return StoryCardDraft(
        scene: scene,
        backgroundImageBytes: photos.firstOrNull,
        additionalPhotoImageBytes: photos.skip(1).toList(growable: false),
      );
    } catch (_) {
      return null;
    } finally {
      await _deleteDirectory(directory);
    }
  }

  @override
  Future<void> delete(String id) async {
    await _deleteDirectory(await _draftDirectory(id));
  }

  Future<StoryCardLocalDraftSummary?> _readSummary(Directory directory) async {
    try {
      final manifest = await _readManifest(directory);
      return StoryCardLocalDraftSummary(
        id: manifest['id'] as String,
        savedAt: DateTime.parse(manifest['saved_at'] as String),
        expiresAt: DateTime.parse(manifest['expires_at'] as String),
        previewImageBytes: await File(
          _join(directory.path, _previewFileName),
        ).readAsBytes(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _readManifest(Directory directory) async {
    final source = await File(
      _join(directory.path, _manifestFileName),
    ).readAsString();
    return Map<String, dynamic>.from(jsonDecode(source) as Map);
  }

  Future<Directory> _rootDirectory({required bool create}) async {
    final cache = await _cacheDirectoryLoader();
    final root = Directory(_join(cache.path, _rootDirectoryName));
    if (create) {
      await root.create(recursive: true);
    }
    return root;
  }

  Future<Directory> _draftDirectory(String id) async {
    if (id.isEmpty || id.contains('/') || id.contains(r'\')) {
      throw ArgumentError.value(id, 'id', 'Invalid local draft id.');
    }
    final root = await _rootDirectory(create: false);
    return Directory(_join(root.path, id));
  }

  Future<void> _deleteDirectory(Directory directory) async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  String _join(String parent, String child) {
    return '$parent${Platform.pathSeparator}$child';
  }
}
