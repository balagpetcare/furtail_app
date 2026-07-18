// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Furtail';

  @override
  String get authWelcomeTitle => 'Welcome to Furtail';

  @override
  String get authSignInSubtitle => 'Sign in to continue caring for your pets';

  @override
  String get authIdentifierHint => 'Email, phone number, or username';

  @override
  String get authPasswordHint => 'Password';

  @override
  String get authConfirmPasswordHint => 'Confirm password';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authLogin => 'Log In';

  @override
  String get authNoAccount => 'Don\'t have an account? ';

  @override
  String get authRegister => 'Register';

  @override
  String get authOrContinueWith => 'or continue with';

  @override
  String get authMore => 'More';

  @override
  String authProviderPending(String provider) {
    return '$provider sign-in isn\'t available yet in this app.';
  }

  @override
  String get authCreateAccountTitle => 'Create Account';

  @override
  String get authCreateAccountSubtitle => 'Join the Furtail community today';

  @override
  String get authFullNameHint => 'Full name';

  @override
  String get authEmailHint => 'Email';

  @override
  String get authPhoneHint => 'Phone number';

  @override
  String get authCreateAccountButton => 'Create Account';

  @override
  String get authHaveAccount => 'Already have an account? ';

  @override
  String get authLoginLink => 'Login';

  @override
  String get authFieldRequired => 'This field is required';

  @override
  String authPasswordTooShort(int minLength) {
    return 'Password must be at least $minLength characters';
  }

  @override
  String get authPasswordMismatch => 'Passwords do not match';

  @override
  String get authInvalidEmail => 'Enter a valid email address';

  @override
  String get authRegisteredSuccess => 'Account created. Please log in.';

  @override
  String get otpTitle => 'Sign in with a one-time code';

  @override
  String get otpChannelEmail => 'Email';

  @override
  String get otpChannelPhone => 'SMS';

  @override
  String get otpChannelWhatsapp => 'WhatsApp';

  @override
  String get otpRecipientHint => 'Email or phone number';

  @override
  String get otpSendCode => 'Send code';

  @override
  String otpEnterCodeSentTo(String destination) {
    return 'Enter the code sent to $destination';
  }

  @override
  String get otpCodeHint => 'Verification code';

  @override
  String get otpVerify => 'Verify';

  @override
  String get otpResend => 'Resend code';

  @override
  String otpResendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get otpChangeRecipient => 'Use a different email/phone';

  @override
  String get otpErrorExpired => 'This code has expired. Request a new one.';

  @override
  String get otpErrorMaxAttempts =>
      'Too many incorrect attempts. Request a new code.';

  @override
  String get otpErrorInvalid => 'Incorrect code. Please try again.';

  @override
  String get otpErrorCooldown => 'Please wait before requesting another code.';

  @override
  String get resetPasswordTitle => 'Reset password';

  @override
  String get resetPasswordTokenHint => 'Reset code from your email';

  @override
  String get resetPasswordNewPasswordHint => 'New password';

  @override
  String get resetPasswordConfirmHint => 'Confirm new password';

  @override
  String get resetPasswordSubmit => 'Reset password';

  @override
  String get resetPasswordSuccess =>
      'Password reset. Please log in with your new password.';

  @override
  String resetPasswordPolicyMinLength(int minLength) {
    return 'At least $minLength characters';
  }

  @override
  String get resetPasswordPolicyUppercase => 'At least one uppercase letter';

  @override
  String get resetPasswordPolicyNumber => 'At least one number';

  @override
  String get resetPasswordPolicySymbol => 'At least one symbol';

  @override
  String get resetPasswordTokenExplainer =>
      'Paste the reset code from the email we sent you.';

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeLight => 'Light';

  @override
  String get themeLightDesc => 'Always use light theme';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeDarkDesc => 'Always use dark theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeSystemDesc => 'Match device light or dark setting';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get nightModeDayMode => 'Night mood / Day mood';

  @override
  String get mediaPlayback => 'Media playback';

  @override
  String get playVideosOneByOneWifiOnly => 'Play videos one by one (WiFi only)';

  @override
  String get playVideosOneByOneWifiOnlyDesc =>
      'If ON, only one video/reel plays at a time. Switching pauses the previous one.';

  @override
  String get muteAllVideos => 'Mute all videos';

  @override
  String get muteAllVideosDesc =>
      'All videos/reels will be muted/unmuted together.';

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select language';

  @override
  String get continueLabel => 'Continue';

  @override
  String get english => 'English';

  @override
  String get bangla => 'বাংলা';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get deletePet => 'Delete pet';

  @override
  String get deletePetConfirm =>
      'Are you sure you want to delete this pet? This action cannot be undone.';

  @override
  String get deleted => 'Deleted';

  @override
  String get notificationPreferences => 'Notification preferences';

  @override
  String get notificationPreferencesDesc => 'Push, email, and in-app alerts';

  @override
  String get privacySettings => 'Privacy';

  @override
  String get privacySettingsDesc => 'Profile visibility and messaging';

  @override
  String get blockedUsers => 'Blocked users';

  @override
  String get blockedUsersDesc => 'People you have blocked';

  @override
  String get storageAndCache => 'Storage & cache';

  @override
  String get storageAndCacheDesc => 'Usage and clear cached data';

  @override
  String get logout => 'Log out';

  @override
  String get logoutConfirmTitle => 'Log out?';

  @override
  String get logoutConfirmMessage =>
      'You will need to sign in again to use your account.';

  @override
  String get pushNotifications => 'Push notifications';

  @override
  String get pushNotificationsDesc => 'Master switch for device alerts';

  @override
  String get campaignReminders => 'Campaign reminders';

  @override
  String get vaccineReminders => 'Vaccine reminders';

  @override
  String get donationUpdates => 'Donation updates';

  @override
  String get communityActivity => 'Community activity';

  @override
  String get commentsNotif => 'Comments';

  @override
  String get likesNotif => 'Likes';

  @override
  String get followsNotif => 'New followers';

  @override
  String get announcementsNotif => 'Announcements';

  @override
  String get emergencyNotif => 'Emergency alerts';

  @override
  String get emergencyNotifDesc =>
      'Critical safety and health alerts (recommended on)';

  @override
  String get allowEmailNotif => 'Email notifications';

  @override
  String get allowSmsNotif => 'SMS notifications';

  @override
  String get profileVisible => 'Public profile';

  @override
  String get profileVisibleDesc => 'Anyone can view your profile';

  @override
  String get showOnlineStatus => 'Show online status';

  @override
  String get messagesFollowersOnly => 'Messages from followers only';

  @override
  String get showActivityInFeed => 'Show activity in feed';

  @override
  String get allowTagging => 'Allow others to tag you';

  @override
  String get noBlockedUsers => 'No blocked users';

  @override
  String get noBlockedUsersDesc => 'Users you block will appear here';

  @override
  String get unblock => 'Unblock';

  @override
  String get blockUser => 'Block user';

  @override
  String get blockUserHint => 'Enter user ID and display name';

  @override
  String get userId => 'User ID';

  @override
  String get displayName => 'Display name';

  @override
  String get storageUsage => 'Storage usage';

  @override
  String get cacheSize => 'Cache';

  @override
  String get tempSize => 'Temporary files';

  @override
  String get totalSize => 'Total';

  @override
  String get clearCache => 'Clear cache';

  @override
  String get clearCacheConfirm => 'Clear cached images and temporary files?';

  @override
  String get cacheCleared => 'Cache cleared';

  @override
  String get refresh => 'Refresh';

  @override
  String get save => 'Save';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get account => 'Account';

  @override
  String get accountDesc => 'Profile, email, password, sessions';

  @override
  String get accountSettings => 'Account settings';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get editProfileDesc => 'Name, bio, avatar, cover photo';

  @override
  String get changeEmail => 'Change email';

  @override
  String get changeEmailDesc => 'Update your email address';

  @override
  String get changePassword => 'Change password';

  @override
  String get changePasswordDesc => 'Update your login password';

  @override
  String get connectedAccounts => 'Connected accounts';

  @override
  String get connectedAccountsDesc => 'Google, Facebook and other links';

  @override
  String get activeSessions => 'Active sessions';

  @override
  String get activeSessionsDesc => 'Devices currently signed in';

  @override
  String get downloadMyData => 'Download my data';

  @override
  String get downloadMyDataDesc => 'Get a copy of your Furtail data';

  @override
  String get deactivateAccount => 'Deactivate account';

  @override
  String get deactivateAccountDesc => 'Temporarily hide your account';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountDesc => 'Permanently delete all your data';

  @override
  String get helpAndSupport => 'Help & support';

  @override
  String get faq => 'FAQ';

  @override
  String get faqDesc => 'Frequently asked questions';

  @override
  String get contactSupport => 'Contact support';

  @override
  String get contactSupportDesc => 'Get help from the Furtail team';

  @override
  String get reportBug => 'Report a bug';

  @override
  String get reportBugDesc => 'Help us improve the app';

  @override
  String get about => 'About';

  @override
  String get communityGuidelines => 'Community guidelines';

  @override
  String get communityGuidelinesDesc => 'Rules for a safe, kind community';

  @override
  String get communityGuidelinesShort => 'Guidelines';

  @override
  String get termsOfService => 'Terms of service';

  @override
  String get termsOfServiceDesc => 'Legal terms for using Furtail';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get privacyPolicyDesc => 'How we handle your data';

  @override
  String get appVersion => 'App version';

  @override
  String get mediaAndStorage => 'Media & storage';

  @override
  String get mediaAndStorageDesc => 'Upload quality, auto-play, cache';

  @override
  String get uploadQuality => 'Upload quality';

  @override
  String get uploadQualityDataSaver => 'Data saver';

  @override
  String get uploadQualityStandard => 'Standard';

  @override
  String get uploadQualityHigh => 'High quality';

  @override
  String get autoPlayVideos => 'Auto-play videos';

  @override
  String get autoPlayAlways => 'Always';

  @override
  String get autoPlayWifiOnly => 'Wi-Fi only';

  @override
  String get autoPlayNever => 'Never';

  @override
  String get compressImages => 'Compress images';

  @override
  String get compressImagesDesc => 'Reduce image size before uploading';

  @override
  String get compressVideos => 'Compress videos';

  @override
  String get compressVideosDesc => 'Reduce video size before uploading';

  @override
  String get saveUploadedMedia => 'Save uploaded media to device';

  @override
  String get saveUploadedMediaDesc => 'Keep a local copy after posting';

  @override
  String get clearMediaCache => 'Clear media cache';

  @override
  String get clearMediaCacheDesc => 'Free up storage used by cached media';

  @override
  String get mediaCacheCleared => 'Media cache cleared';

  @override
  String get whoCanComment => 'Who can comment';

  @override
  String get whoCanCommentDesc => 'Control who can reply to your posts';

  @override
  String get everyone => 'Everyone';

  @override
  String get followersOnly => 'Followers only';

  @override
  String get noOne => 'No one';

  @override
  String get mentionsNotif => 'Mentions';

  @override
  String get messagesNotif => 'Direct messages';

  @override
  String get marketingNotif => 'Promotions & tips';

  @override
  String get marketingNotifDesc => 'Product updates and helpful tips';

  @override
  String get reportAProblem => 'Report a problem';

  @override
  String get reportAProblemDesc => 'Flag harmful or inappropriate content';

  @override
  String get somethingWentWrong => 'Something went wrong';

  @override
  String get tryAgain => 'Try again';

  @override
  String get noContentYet => 'Nothing here yet';

  @override
  String get youAreOffline => 'You are offline';

  @override
  String get offlineDesc => 'Check your internet connection';

  @override
  String get interactions => 'Interactions';

  @override
  String get safety => 'Safety';

  @override
  String get uploadPreferences => 'Upload preferences';

  @override
  String get dangerZone => 'Danger zone';
}
