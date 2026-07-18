import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file/file.dart' as pfile;

/// Cache limits – tuned for mid-range Android devices (~2-3 GB storage budget).
class FurtailCacheLimits {
  /// Max number of cached image files. Reduced from 300 → 200.
  static const imageMaxObjects = 200;
  static const imageStalePeriod = Duration(days: 7);

  /// Max number of cached video files. Reduced from 100 → 60.
  static const videoMaxObjects = 60;
  static const videoStalePeriod = Duration(days: 14);

  // ── Byte-based limits ────────────────────────────────────────────
  /// Max on-disk size for video cache. Reduced from 500 MB → 300 MB.
  static const videoMaxCacheBytes = 300 * 1024 * 1024;

  /// Max on-disk size for image cache. Reduced from 200 MB → 100 MB.
  static const imageMaxCacheBytes = 100 * 1024 * 1024;
}

/// Shared helpers for cache enforcements.
Future<int> _dirSizeBytes(Directory dir) async {
  int total = 0;
  try {
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
  } catch (_) {}
  return total;
}

Future<Directory> _cacheStoreDir(String cacheKey) async {
  final appCache = await getApplicationCacheDirectory();
  return Directory('${appCache.path}/$cacheKey');
}

Future<int> _enforceMaxSizeImpl(String cacheKey, int maxBytes) async {
  final storeDir = await _cacheStoreDir(cacheKey);
  if (!await storeDir.exists()) return 0;

  final currentSize = await _dirSizeBytes(storeDir);
  if (currentSize <= maxBytes) return 0;

  // Collect all cached files (skip metadata .json)
  final files = <File>[];
  await for (final entity in storeDir.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is File && !entity.path.endsWith('.json')) {
      files.add(entity);
    }
  }

  // Sort by last modified (oldest first → delete oldest first)
  files.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));

  int freed = 0;
  final overshoot = currentSize - maxBytes;
  for (final file in files) {
    if (freed >= overshoot) break;
    // Skip active files to prevent deleting currently playing files
    if (VideoCacheService.instance.isPathActive(file.path)) {
      continue;
    }
    try {
      freed += await file.length();
      await file.delete();
    } catch (_) {}
  }

  if (kDebugMode) {
    debugPrint(
      '[$cacheKey] enforceMaxSize: freed ${(freed / 1048576).toStringAsFixed(1)}MB '
      '(was ${(currentSize / 1048576).toStringAsFixed(1)}MB, '
      'target ${(maxBytes / 1048576).toStringAsFixed(1)}MB)',
    );
  }
  return freed;
}

/// Image cache manager shared across [CachedNetworkImage] widgets.
class FurtailImageCacheManager extends CacheManager with ImageCacheManager {
  static const cacheKey = 'furtailImageCache';

  static final FurtailImageCacheManager _instance =
      FurtailImageCacheManager._();
  factory FurtailImageCacheManager() => _instance;

  FurtailImageCacheManager._()
    : super(
        Config(
          cacheKey,
          stalePeriod: FurtailCacheLimits.imageStalePeriod,
          maxNrOfCacheObjects: FurtailCacheLimits.imageMaxObjects,
          repo: JsonCacheInfoRepository(databaseName: cacheKey),
          fileService: HttpFileService(),
        ),
      );

  /// Total byte size of all cached image files on disk.
  Future<int> getCacheSizeBytes() async => _dirSizeBytes(await _storeDir());

  Future<Directory> _storeDir() async {
    final appCache = await getApplicationCacheDirectory();
    return Directory('${appCache.path}/$cacheKey');
  }

  /// Delete oldest cached files until under [FurtailCacheLimits.imageMaxCacheBytes].
  Future<int> enforceMaxSize() =>
      _enforceMaxSizeImpl(cacheKey, FurtailCacheLimits.imageMaxCacheBytes);

  @override
  Future<FileInfo> downloadFile(
    String url, {
    Map<String, String>? authHeaders,
    String? key,
    bool force = false,
  }) async {
    final fileInfo = await super.downloadFile(
      url,
      authHeaders: authHeaders,
      key: key,
      force: force,
    );
    unawaited(enforceMaxSize());
    return fileInfo;
  }

  @override
  Future<pfile.File> putFile(
    String url,
    Uint8List fileBytes, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) async {
    final file = await super.putFile(
      url,
      fileBytes,
      key: key,
      eTag: eTag,
      maxAge: maxAge,
      fileExtension: fileExtension,
    );
    unawaited(enforceMaxSize());
    return file;
  }
}

/// Separate cache manager for videos.
class FurtailVideoCacheManager extends CacheManager {
  static const cacheKey = 'furtailVideoCache';

  static final FurtailVideoCacheManager _instance =
      FurtailVideoCacheManager._();
  factory FurtailVideoCacheManager() => _instance;

  FurtailVideoCacheManager._()
    : super(
        Config(
          cacheKey,
          stalePeriod: FurtailCacheLimits.videoStalePeriod,
          maxNrOfCacheObjects: FurtailCacheLimits.videoMaxObjects,
          repo: JsonCacheInfoRepository(databaseName: cacheKey),
          fileService: HttpFileService(),
        ),
      );

  /// Total byte size of all cached video files on disk.
  Future<int> getCacheSizeBytes() async => _dirSizeBytes(await _storeDir());

  Future<Directory> _storeDir() async {
    final appCache = await getApplicationCacheDirectory();
    return Directory('${appCache.path}/$cacheKey');
  }

  /// Delete oldest cached files until under [FurtailCacheLimits.videoMaxCacheBytes].
  Future<int> enforceMaxSize() =>
      _enforceMaxSizeImpl(cacheKey, FurtailCacheLimits.videoMaxCacheBytes);

  /// Clears the entire video cache.
  static Future<void> clearAll() => FurtailVideoCacheManager().emptyCache();
}

/// Enterprise-safe disk caching service for video assets.
class VideoCacheService {
  VideoCacheService._();
  static final VideoCacheService instance = VideoCacheService._();

  final FurtailVideoCacheManager _cacheManager = FurtailVideoCacheManager();

  bool isStreamUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path.toLowerCase();
      return path.endsWith('.m3u8') || path.contains('/index.m3u8');
    } catch (_) {
      return url.toLowerCase().contains('.m3u8');
    }
  }

  /// Gets the normalized stable cache key by stripping dynamic query parameters (e.g., token signatures)
  String normalizeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.queryParameters.isEmpty) return url;
      return Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.port,
        path: uri.path,
      ).toString();
    } catch (_) {
      return url;
    }
  }

  /// Get video file from disk cache, downloading it if not present.
  /// Shows logs indicating cache hit vs network download.
  Future<File> getVideoFile(String url) async {
    if (isStreamUrl(url)) {
      throw UnsupportedError('HLS streams are played directly from network');
    }
    final key = normalizeUrl(url);
    try {
      final fileInfo = await _cacheManager.getFileFromCache(key);
      if (fileInfo != null && await fileInfo.file.exists()) {
        if (kDebugMode) {
          debugPrint('[VideoCache] CACHE HIT: key=$key');
        }
        // Update modified time for LRU eviction
        try {
          await fileInfo.file.setLastModified(DateTime.now());
        } catch (_) {}
        return fileInfo.file;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[VideoCache] Cache lookup failed: $e');
      }
    }

    if (kDebugMode) {
      debugPrint('[VideoCache] CACHE MISS (Downloading): key=$key');
    }

    try {
      final fileInfo = await _cacheManager.downloadFile(url, key: key);
      // Enforce byte limit after each successful download
      unawaited(_cacheManager.enforceMaxSize());
      return fileInfo.file;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[VideoCache] Download failed: $e');
      }
      // Delete incomplete/partial cached entry on failure
      await _cacheManager.removeFile(key);
      rethrow;
    }
  }

  /// Prefetch video in the background only if on Wi-Fi connection.
  Future<void> prefetchVideo(String url) async {
    try {
      if (isStreamUrl(url)) {
        return;
      }
      final connectivityList = await Connectivity().checkConnectivity();
      final onMobile = connectivityList.contains(ConnectivityResult.mobile);
      if (onMobile) {
        if (kDebugMode) {
          debugPrint('[VideoCache] Prefetch disabled on mobile data: $url');
        }
        return;
      }

      final key = normalizeUrl(url);
      final fileInfo = await _cacheManager.getFileFromCache(key);
      if (fileInfo != null && await fileInfo.file.exists()) {
        return; // Already cached
      }

      if (kDebugMode) {
        debugPrint('[VideoCache] Prefetching video (Wi-Fi): key=$key');
      }

      // Async background download
      _cacheManager
          .downloadFile(url, key: key)
          .then((_) {
            _cacheManager.enforceMaxSize(); // Enforce limit after prefetch
          })
          .catchError((e) {
            if (kDebugMode) {
              debugPrint('[VideoCache] Background prefetch failed: $e');
            }
            // Ensure failed downloads don't pollute state
            _cacheManager.removeFile(key);
          });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[VideoCache] Prefetch check error: $e');
      }
    }
  }

  /// Remove a corrupt file from the cache so it gets refetched next time.
  Future<void> removeFile(String url) async {
    if (isStreamUrl(url)) {
      return;
    }
    final key = normalizeUrl(url);
    if (kDebugMode) {
      debugPrint('[VideoCache] Removing file from cache: key=$key');
    }
    await _cacheManager.removeFile(key);
  }

  final Set<String> _activePaths = {};

  void registerActivePath(String path) {
    _activePaths.add(path);
  }

  void unregisterActivePath(String path) {
    _activePaths.remove(path);
  }

  bool isPathActive(String path) {
    return _activePaths.contains(path);
  }

  /// Total byte size of the video cache on disk.
  Future<int> getCacheSize() => _cacheManager.getCacheSizeBytes();

  /// Clears both video and image caches plus temp directory.
  static Future<int> clearAllCaches() async {
    int freed = 0;

    try {
      final vidSize = await FurtailVideoCacheManager().getCacheSizeBytes();
      await FurtailVideoCacheManager().emptyCache();
      freed += vidSize;
    } catch (_) {}

    try {
      final imgSize = await FurtailImageCacheManager().getCacheSizeBytes();
      await FurtailImageCacheManager().emptyCache();
      freed += imgSize;
    } catch (_) {}

    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        freed += await _dirSizeBytes(tempDir);
        await for (final entity in tempDir.list()) {
          try {
            if (entity is File) {
              await entity.delete();
            } else if (entity is Directory) {
              await entity.delete(recursive: true);
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    // Also clear the in-memory Flutter image decode cache.
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}

    if (kDebugMode) {
      debugPrint(
        '[Cache] clearAllCaches: freed ${(freed / 1048576).toStringAsFixed(1)} MB',
      );
    }
    return freed;
  }

  /// Deletes temporary files older than [maxAge].
  /// Safe to call on app startup and after uploads to prevent accumulation
  /// of video_compress output files.
  static Future<int> clearStaleTempFiles({
    Duration maxAge = const Duration(hours: 24),
  }) async {
    int freed = 0;
    try {
      final tempDir = await getTemporaryDirectory();
      if (!await tempDir.exists()) return 0;
      final cutoff = DateTime.now().subtract(maxAge);
      await for (final entity in tempDir.list(
        recursive: true,
        followLinks: false,
      )) {
        try {
          if (entity is File) {
            final stat = await entity.stat();
            if (stat.modified.isBefore(cutoff)) {
              freed += await entity.length();
              await entity.delete();
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
    if (kDebugMode && freed > 0) {
      debugPrint(
        '[Cache] clearStaleTempFiles: freed ${(freed / 1048576).toStringAsFixed(1)} MB',
      );
    }
    return freed;
  }
}
