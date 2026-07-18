import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// PKCE (RFC 7636) material for one authorization attempt, plus the opaque
/// `state` used to bind the callback to the flow that started it. Generated
/// fresh per attempt with a cryptographically secure RNG — never reused.
class PkceFlow {
  PkceFlow._(this.codeVerifier, this.codeChallenge, this.state);

  factory PkceFlow.generate() {
    final verifier = _randomUrlSafe(32); // 43 base64url chars
    final challenge = base64UrlEncode(
      sha256.convert(ascii.encode(verifier)).bytes,
    ).replaceAll('=', '');
    return PkceFlow._(verifier, challenge, _randomUrlSafe(16));
  }

  final String codeVerifier;
  final String codeChallenge;
  final String state;

  static final _rng = Random.secure();

  static String _randomUrlSafe(int byteLength) {
    final bytes = List<int>.generate(byteLength, (_) => _rng.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
