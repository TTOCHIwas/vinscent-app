import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef SignedUrlBatchLoader =
    Future<Map<String, String>> Function(
      List<String> paths,
      int expiresInSeconds,
    );

final signedUrlCacheProvider = Provider<SignedUrlCache>(
  (ref) => SignedUrlCache(),
);

class SignedUrlCache {
  SignedUrlCache({
    DateTime Function()? clock,
    this.refreshBefore = const Duration(minutes: 5),
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Duration refreshBefore;
  final _entries = <_SignedUrlCacheKey, _SignedUrlCacheEntry>{};
  final _inFlight = <_SignedUrlCacheKey, Future<String?>>{};

  Future<Map<String, String>> resolve({
    required String bucketId,
    required Iterable<String> paths,
    required int expiresInSeconds,
    required SignedUrlBatchLoader loader,
  }) async {
    final uniquePaths = paths
        .where((path) => path.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (uniquePaths.isEmpty) {
      return const {};
    }

    final now = _clock();
    final resolved = <String, String>{};
    final pending = <String, Future<String?>>{};
    final pathsToLoad = <String>[];

    for (final path in uniquePaths) {
      final key = _SignedUrlCacheKey(bucketId, path);
      final cached = _entries[key];
      if (cached != null && cached.isFreshAt(now, refreshBefore)) {
        resolved[path] = cached.url;
        continue;
      }

      final currentRequest = _inFlight[key];
      if (currentRequest != null) {
        pending[path] = currentRequest;
      } else {
        pathsToLoad.add(path);
      }
    }

    if (pathsToLoad.isNotEmpty) {
      final batchRequest = loader(pathsToLoad, expiresInSeconds);
      for (final path in pathsToLoad) {
        final key = _SignedUrlCacheKey(bucketId, path);
        late final Future<String?> request;
        request = batchRequest
            .then((urlsByPath) {
              final url = urlsByPath[path];
              if (url == null || url.isEmpty) {
                return null;
              }
              _entries[key] = _SignedUrlCacheEntry(
                url: url,
                expiresAt: _clock().add(Duration(seconds: expiresInSeconds)),
              );
              return url;
            })
            .whenComplete(() {
              if (identical(_inFlight[key], request)) {
                _inFlight.remove(key);
              }
            });
        _inFlight[key] = request;
        pending[path] = request;
      }
    }

    for (final entry in pending.entries) {
      final url = await entry.value;
      if (url != null) {
        resolved[entry.key] = url;
      }
    }
    return resolved;
  }
}

class _SignedUrlCacheKey {
  const _SignedUrlCacheKey(this.bucketId, this.path);

  final String bucketId;
  final String path;

  @override
  bool operator ==(Object other) {
    return other is _SignedUrlCacheKey &&
        other.bucketId == bucketId &&
        other.path == path;
  }

  @override
  int get hashCode => Object.hash(bucketId, path);
}

class _SignedUrlCacheEntry {
  const _SignedUrlCacheEntry({required this.url, required this.expiresAt});

  final String url;
  final DateTime expiresAt;

  bool isFreshAt(DateTime now, Duration refreshBefore) {
    return expiresAt.isAfter(now.add(refreshBefore));
  }
}
