import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'visitor_profile_state.dart';
import '../../data/models/visitor_profile_model.dart';
import 'package:furtail_app/services/social_service.dart';

final visitorProfileProvider = AutoDisposeNotifierProviderFamily<VisitorProfileController, VisitorProfileState, int>(
  VisitorProfileController.new,
);

class VisitorProfileController extends AutoDisposeFamilyNotifier<VisitorProfileState, int> {
  late final SocialService _social;

  @override
  VisitorProfileState build(int userId) {
    _social = SocialService();

    // Fire-and-forget initial load (don’t block build)
    scheduleMicrotask(() => load(userId));

    return VisitorProfileState.initial();
  }

  Future<void> load(int userId) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final raw = await _social.getVisitorProfile(userId);
      final profile = VisitorProfileModel.fromApi(raw);

      // Social status is best-effort (avoid blocking the screen on server issues)
      SocialStatus? status;
      try {
        status = await _social.getStatus(userId);
      } catch (_) {
        status = SocialStatus(
          isFollowing: false,
          isLiked: false,
          isFriend: false,
          outgoingRequestId: null,
          incomingRequestId: null,
        );
      }

      state = state.copyWith(loading: false, profile: profile, status: status);
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> follow() async {
    final p = state.profile;
    final s = state.status;
    if (p == null || s == null) return;
    state = state.copyWith(actionInProgress: true, error: null);
    try {
      if (s.isFollowing) {
        await _social.unfollow(p.id);
      } else {
        await _social.follow(p.id);
      }
      final updated = await _social.getStatus(p.id);
      state = state.copyWith(actionInProgress: false, status: updated);
    } catch (e) {
      state = state.copyWith(
        actionInProgress: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> like() async {
    final p = state.profile;
    final s = state.status;
    if (p == null || s == null) return;
    state = state.copyWith(actionInProgress: true, error: null);
    try {
      if (s.isLiked) {
        await _social.unlikeProfile(p.id);
      } else {
        await _social.likeProfile(p.id);
      }
      final updated = await _social.getStatus(p.id);
      state = state.copyWith(actionInProgress: false, status: updated);
    } catch (e) {
      state = state.copyWith(
        actionInProgress: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> sendFriendRequest() async {
    final p = state.profile;
    if (p == null) return;
    state = state.copyWith(actionInProgress: true, error: null);
    try {
      await _social.sendFriendRequest(p.id);
      final updated = await _social.getStatus(p.id);
      state = state.copyWith(actionInProgress: false, status: updated);
    } catch (e) {
      state = state.copyWith(
        actionInProgress: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> acceptIncoming() async {
    final p = state.profile;
    final s = state.status;
    if (p == null || s?.incomingRequestId == null) return;
    state = state.copyWith(actionInProgress: true);
    try {
      await _social.acceptFriendRequest(s!.incomingRequestId!);
      final updated = await _social.getStatus(p.id);
      state = state.copyWith(actionInProgress: false, status: updated);
    } catch (e) {
      state = state.copyWith(
        actionInProgress: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> rejectIncoming() async {
    final p = state.profile;
    final s = state.status;
    if (p == null || s?.incomingRequestId == null) return;
    state = state.copyWith(actionInProgress: true);
    try {
      await _social.rejectFriendRequest(s!.incomingRequestId!);
      final updated = await _social.getStatus(p.id);
      state = state.copyWith(actionInProgress: false, status: updated);
    } catch (e) {
      state = state.copyWith(
        actionInProgress: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ---- Compatibility helpers (keeps existing UI code simple) ----
  Future<void> toggleFollow() => follow();

  Future<void> toggleLikeProfile() => like();

  Future<void> friendAction() async {
    final p = state.profile;
    final s = state.status;
    if (p == null || s == null) return;

    // Priority: handle incoming request first.
    if (s.incomingRequestId != null) {
      return acceptIncoming();
    }

    // If already sent a request, allow cancel.
    if (s.outgoingRequestId != null) {
      state = state.copyWith(actionInProgress: true, error: null);
      try {
        await _social.cancelFriendRequest(s.outgoingRequestId!);
        final updated = await _social.getStatus(p.id);
        state = state.copyWith(actionInProgress: false, status: updated);
      } catch (e) {
        state = state.copyWith(actionInProgress: false, error: e.toString().replaceAll('Exception: ', ''));
      }
      return;
    }

    // Otherwise, send request.
    return sendFriendRequest();
  }

}
