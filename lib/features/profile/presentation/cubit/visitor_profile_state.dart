import '../../data/models/visitor_profile_model.dart';
import 'package:furtail_app/services/social_service.dart';

class VisitorProfileState {
  final bool loading;
  final String? error;
  final VisitorProfileModel? profile;
  final SocialStatus? status;
  final bool actionInProgress;

  const VisitorProfileState({
    required this.loading,
    required this.actionInProgress,
    this.error,
    this.profile,
    this.status,
  });

  factory VisitorProfileState.initial() => const VisitorProfileState(
        loading: true,
        actionInProgress: false,
      );

  VisitorProfileState copyWith({
    bool? loading,
    bool? actionInProgress,
    String? error,
    VisitorProfileModel? profile,
    SocialStatus? status,
  }) {
    return VisitorProfileState(
      loading: loading ?? this.loading,
      actionInProgress: actionInProgress ?? this.actionInProgress,
      error: error,
      profile: profile ?? this.profile,
      status: status ?? this.status,
    );
  }
}
