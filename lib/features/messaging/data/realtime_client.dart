import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:furtail_app/core/auth/secure_storage_service.dart';
import 'package:furtail_app/core/network/api_endpoints.dart';

/// A single event from the backend's authenticated SSE stream
/// (`GET /api/v1/realtime/stream`, see `realtime-hub.ts` on the backend):
/// `message.created`, `conversation.updated`, or `message.read`.
class RealtimeMessageEvent {
  final String type;
  final Map<String, dynamic> data;
  const RealtimeMessageEvent({required this.type, required this.data});
}

/// The smallest maintainable Server-Sent-Events client for this app: no new
/// package (a bare `Dio` streamed GET, parsed by hand), matching the
/// backend's equally minimal choice not to add `ws`/`socket.io`. This is
/// intentionally best-effort — every screen that uses it must still
/// reconcile from REST on its own (on open / app resume / connectivity
/// restore), so a dropped or never-established stream never loses a
/// message or an unread count, only delays how quickly the UI notices.
class RealtimeClient {
  RealtimeClient({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  final _controller = StreamController<RealtimeMessageEvent>.broadcast();
  bool _stopped = true;
  int _consecutiveFailures = 0;
  Timer? _backoffTimer;

  Stream<RealtimeMessageEvent> get events => _controller.stream;

  void start() {
    if (!_stopped) return;
    _stopped = false;
    unawaited(_connectLoop());
  }

  void stop() {
    _stopped = true;
    _backoffTimer?.cancel();
    _backoffTimer = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }

  Future<void> _connectLoop() async {
    while (!_stopped) {
      try {
        await _connectOnce();
        _consecutiveFailures = 0;
      } catch (_) {
        _consecutiveFailures += 1;
        if (kDebugMode) {
          debugPrint('[Realtime] disconnected (attempt $_consecutiveFailures)');
        }
      }
      if (_stopped) return;
      // Simple capped exponential backoff: 2s, 4s, 8s, ... up to 30s.
      final delayMs = (2000 * (1 << _consecutiveFailures.clamp(0, 4))).clamp(
        2000,
        30000,
      );
      if (kDebugMode && _consecutiveFailures > 0) {
        debugPrint('[Realtime] reconnecting in ${delayMs}ms');
      }
      final completer = Completer<void>();
      _backoffTimer = Timer(Duration(milliseconds: delayMs), () {
        if (!completer.isCompleted) completer.complete();
      });
      await completer.future;
    }
  }

  Future<void> _connectOnce() async {
    final token = await SecureStorageService().accessToken;
    if (token == null || token.isEmpty) {
      // Not signed in — nothing to stream; back off like any other failure.
      throw StateError('No access token');
    }

    final response = await _dio.get<ResponseBody>(
      ApiEndpoints.realtimeStream(),
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Authorization': 'Bearer $token'},
        receiveTimeout: Duration.zero,
      ),
    );

    final stream = response.data?.stream;
    if (stream == null) throw StateError('No stream in response');

    if (kDebugMode) {
      debugPrint('[Realtime] connected');
    }

    var buffer = '';
    await for (final chunk in stream) {
      if (_stopped) return;
      buffer += utf8.decode(chunk, allowMalformed: true);
      while (true) {
        final boundary = buffer.indexOf('\n\n');
        if (boundary == -1) break;
        final rawEvent = buffer.substring(0, boundary);
        buffer = buffer.substring(boundary + 2);
        _handleRawEvent(rawEvent);
      }
    }
  }

  void _handleRawEvent(String raw) {
    String? eventType;
    final dataLines = <String>[];
    for (final line in raw.split('\n')) {
      if (line.startsWith('event:')) {
        eventType = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trim());
      }
      // Heartbeat comments (`: heartbeat`) and `retry:` lines are ignored.
    }
    if (eventType == null || dataLines.isEmpty) return;
    try {
      final decoded = jsonDecode(dataLines.join('\n'));
      if (decoded is Map) {
        if (kDebugMode && eventType == 'message.created') {
          debugPrint(
            '[Realtime] message.created ${decoded['messageId'] ?? decoded['id']} '
            'conversation=${decoded['conversationId']}',
          );
        }
        _controller.add(
          RealtimeMessageEvent(
            type: eventType,
            data: decoded.cast<String, dynamic>(),
          ),
        );
      }
    } catch (_) {
      // Malformed frame — drop it; REST reconciliation covers the gap.
    }
  }
}
