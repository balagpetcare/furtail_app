class StorageUsageInfo {
  final int cacheBytes;
  final int tempBytes;
  final int totalBytes;

  const StorageUsageInfo({
    required this.cacheBytes,
    required this.tempBytes,
    required this.totalBytes,
  });

  static const empty = StorageUsageInfo(cacheBytes: 0, tempBytes: 0, totalBytes: 0);
}
