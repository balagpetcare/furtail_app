import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConnectivityStatus { online, offline, unknown }

class ConnectivityService {
  final _connectivity = Connectivity();

  /// Emits the **current** status immediately, then emits on every change.
  ///
  /// Using async* ensures the offline banner shows at cold-start when the
  /// device is already offline — not only after the first connectivity change.
  Stream<ConnectivityStatus> get onStatusChange async* {
    // Emit current state right away so the offline banner is correct immediately.
    yield await checkNow();
    // Then follow every OS-level connectivity change with a DNS confirmation.
    await for (final results in _connectivity.onConnectivityChanged) {
      yield await _mapResults(results);
    }
  }

  Future<ConnectivityStatus> checkNow() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return _mapResults(results);
    } catch (_) {
      return ConnectivityStatus.unknown;
    }
  }

  Future<ConnectivityStatus> _mapResults(List<ConnectivityResult> results) async {
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      return ConnectivityStatus.offline;
    }
    // Confirm real internet access with a quick DNS probe.
    try {
      final lookup = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      if (lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty) {
        return ConnectivityStatus.online;
      }
    } on SocketException catch (_) {
      // Network interface up but no internet (e.g., captive portal).
    } on TimeoutException catch (_) {
      // Slow / poor connection – classify as offline for UI purposes.
    } catch (_) {
      // Unexpected error; fall through to offline.
    }
    return ConnectivityStatus.offline;
  }
}

final connectivityServiceProvider = Provider<ConnectivityService>(
  (_) => ConnectivityService(),
);

final connectivityStatusProvider = StreamProvider<ConnectivityStatus>((ref) {
  return ref.watch(connectivityServiceProvider).onStatusChange;
});
