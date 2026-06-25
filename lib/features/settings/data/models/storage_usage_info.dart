class StorageUsageInfo {
  final int cacheBytes; // total (backward compat)
  final int imageCacheBytes;
  final int videoCacheBytes;
  final int tempBytes;
  final int totalBytes;

  const StorageUsageInfo({
    required this.cacheBytes,
    required this.imageCacheBytes,
    required this.videoCacheBytes,
    required this.tempBytes,
    required this.totalBytes,
  });

  static const empty = StorageUsageInfo(
    cacheBytes: 0,
    imageCacheBytes: 0,
    videoCacheBytes: 0,
    tempBytes: 0,
    totalBytes: 0,
  );
}
