/// Centralized tuning constants for the realtime typing indicator, so the
/// debounce/throttle/expiry timings live in one place instead of scattered
/// magic numbers across the controller and widgets.
class TypingConstants {
  const TypingConstants._();

  /// While the local user keeps typing without pausing, `typing.started` is
  /// re-published on this cadence — not on every keystroke — purely to keep
  /// the *remote* client's [remoteExpiry] timer alive during a single long
  /// typing session (the realtime protocol only guarantees one start event
  /// per burst, not a stream).
  static const Duration heartbeatInterval = Duration(seconds: 3);

  /// How long the local user must stop typing (no keystrokes) before a
  /// `typing.stopped` is published automatically. Deliberately longer than
  /// [heartbeatInterval] so a continuously-typing user's own heartbeat
  /// always refreshes well before this could fire — the two timers must
  /// never race at the same instant.
  static const Duration stopDebounce = Duration(seconds: 5);

  /// How long a remote `typing.started` is displayed before it's cleared
  /// automatically if no follow-up `typing.started` (heartbeat) or
  /// `typing.stopped` arrives — the client-side safety net for a
  /// `typing.stopped` lost to a dropped connection, backgrounded app, or
  /// process kill. Deliberately > [heartbeatInterval] so a live typing
  /// session's own heartbeats always refresh it before it lapses.
  static const Duration remoteExpiry = Duration(seconds: 7);
}
