/// Origin of a captured error for Crashlytics custom keys.
enum CrashSource {
  flutter('flutter'),
  async('async'),
  riverpod('riverpod'),
  network('network'),
  manual('manual');

  const CrashSource(this.key);
  final String key;
}
