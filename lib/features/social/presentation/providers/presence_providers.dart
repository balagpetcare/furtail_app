import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:furtail_app/services/api_client.dart';
import 'package:furtail_app/features/messaging/data/realtime_client.dart';
import 'package:furtail_app/features/messaging/presentation/providers/messaging_providers.dart';

import '../../data/models/presence_info.dart';
import '../../data/presence_repository.dart';

final presenceRepositoryProvider = Provider<PresenceRepository>(
  (ref) => PresenceRepository(client: ref.watch(apiClientProvider)),
);

/// The heartbeat interval — see `presence.service.ts`'s
/// `PRESENCE_TTL_SECONDS = 150`; anything comfortably under that keeps the
/// Redis key alive without flapping to offline on one slow/missed beat.
const _heartbeatInterval = Duration(seconds: 60);

/// Starts/stops exactly one heartbeat `Timer` for the whole app session —
/// wired from `main.dart`'s lifecycle+auth observer, never from a screen
/// widget, so backgrounding one screen can't accidentally leave a second
/// timer running underneath another.
class HeartbeatController {
  HeartbeatController(this._repo);
  final PresenceRepository _repo;
  Timer? _timer;

  bool get isRunning => _timer != null;

  void start() {
    if (_timer != null) return;
    unawaited(_beat());
    _timer = Timer.periodic(_heartbeatInterval, (_) => unawaited(_beat()));
  }

  void stop({bool notifyOffline = false}) {
    _timer?.cancel();
    _timer = null;
    if (notifyOffline) {
      unawaited(_repo.goOffline().catchError((_) {}));
    }
  }

  Future<void> _beat() async {
    try {
      await _repo.heartbeat();
      if (kDebugMode) {
        debugPrint('[Presence] heartbeat');
      }
    } catch (_) {
      // Best-effort — the next tick recovers; a temporarily-missed
      // heartbeat only delays the TTL, it never corrupts state.
    }
  }
}

/// App-lifetime, not autoDispose — the timer must keep running underneath
/// whichever screen happens to be on top, exactly like `realtimeClientProvider`.
final heartbeatControllerProvider = Provider<HeartbeatController>((ref) {
  final controller = HeartbeatController(ref.watch(presenceRepositoryProvider));
  ref.onDispose(() => controller.stop());
  return controller;
});

/// Shared cache of the latest known [PresenceInfo] per user id — the single
/// source every screen (Friends, Inbox, Chat header) reads from, so a
/// `presence.online`/`presence.offline` event updates one row everywhere at
/// once instead of each screen tracking its own copy.
class PresenceCacheController extends Notifier<Map<int, PresenceInfo>> {
  StreamSubscription<RealtimeMessageEvent>? _sub;

  PresenceRepository get _repo => ref.read(presenceRepositoryProvider);

  @override
  Map<int, PresenceInfo> build() {
    ref.onDispose(() => _sub?.cancel());
    final hub = ref.read(realtimeClientProvider);
    hub.start();
    _sub = hub.events.listen(_onRealtimeEvent);
    return const {};
  }

  PresenceInfo of(int userId) => state[userId] ?? PresenceInfo.unknown;

  /// Bulk-fetches presence for a set of user ids in one call and merges the
  /// results into the shared cache — never call the repository per-user.
  Future<void> fetchAll(Iterable<int> userIds) async {
    final ids = userIds.toSet().toList();
    if (ids.isEmpty) return;
    try {
      final results = await _repo.bulk(ids);
      final next = Map<int, PresenceInfo>.from(state);
      for (final r in results) {
        next[r.userId] = r;
      }
      state = next;
    } catch (_) {
      // Best-effort — screens keep whatever presence they last had.
    }
  }

  void _onRealtimeEvent(RealtimeMessageEvent event) {
    final userId = (event.data['userId'] as num?)?.toInt();
    if (userId == null) return;
    switch (event.type) {
      case 'presence.online':
        _setEntry(
          PresenceInfo(userId: userId, isOnline: true, lastSeenAt: null),
        );
      case 'presence.offline':
        final lastSeenAt = DateTime.tryParse(
          event.data['lastSeenAt']?.toString() ?? '',
        )?.toLocal();
        _setEntry(
          PresenceInfo(userId: userId, isOnline: false, lastSeenAt: lastSeenAt),
        );
    }
  }

  void _setEntry(PresenceInfo info) {
    state = {...state, info.userId: info};
  }
}

/// App-lifetime cache — same rationale as [realtimeClientProvider]: Friends,
/// Inbox, and any open Chat all read/write the same instance so an update
/// to one friend's row is visible everywhere without a full reload.
final presenceCacheProvider =
    NotifierProvider<PresenceCacheController, Map<int, PresenceInfo>>(
      PresenceCacheController.new,
    );
