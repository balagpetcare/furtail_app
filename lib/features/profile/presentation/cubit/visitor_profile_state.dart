import '../../data/models/visitor_profile_model.dart';
import 'package:furtail_app/services/social_service.dart';

class VisitorProfileState {
  final bool loading;
  final String? error;
  final VisitorProfileModel? profile;
  final SocialStatus? status;
  final bool isFollowLoading;
  final bool isFriendLoading;
  final bool isMessageLoading;

  const VisitorProfileState({
    required this.loading,
    this.isFollowLoading = false,
    this.isFriendLoading = false,
    this.isMessageLoading = false,
    this.error,
    this.profile,
    this.status,
  });

  factory VisitorProfileState.initial() => const VisitorProfileState(
        loading: true,
      );

  VisitorProfileState copyWith({
    bool? loading,
    bool? isFollowLoading,
    bool? isFriendLoading,
    bool? isMessageLoading,
    String? error,
    VisitorProfileModel? profile,
    SocialStatus? status,
  }) {
    return VisitorProfileState(
      loading: loading ?? this.loading,
      isFollowLoading: isFollowLoading ?? this.isFollowLoading,
      isFriendLoading: isFriendLoading ?? this.isFriendLoading,
      isMessageLoading: isMessageLoading ?? this.isMessageLoading,
      error: error,
      profile: profile ?? this.profile,
      status: status ?? this.status,
    );
  }
}

