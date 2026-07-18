import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Furtail'**
  String get appTitle;

  /// No description provided for @authWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Furtail'**
  String get authWelcomeTitle;

  /// No description provided for @authSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue caring for your pets'**
  String get authSignInSubtitle;

  /// No description provided for @authIdentifierHint.
  ///
  /// In en, this message translates to:
  /// **'Email, phone number, or username'**
  String get authIdentifierHint;

  /// No description provided for @authPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordHint;

  /// No description provided for @authConfirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get authConfirmPasswordHint;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// No description provided for @authLogin.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get authLogin;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get authNoAccount;

  /// No description provided for @authRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get authRegister;

  /// No description provided for @authOrContinueWith.
  ///
  /// In en, this message translates to:
  /// **'or continue with'**
  String get authOrContinueWith;

  /// No description provided for @authMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get authMore;

  /// No description provided for @authProviderPending.
  ///
  /// In en, this message translates to:
  /// **'{provider} sign-in isn\'t available yet in this app.'**
  String authProviderPending(String provider);

  /// No description provided for @authCreateAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get authCreateAccountTitle;

  /// No description provided for @authCreateAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join the Furtail community today'**
  String get authCreateAccountSubtitle;

  /// No description provided for @authFullNameHint.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get authFullNameHint;

  /// No description provided for @authEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmailHint;

  /// No description provided for @authPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get authPhoneHint;

  /// No description provided for @authCreateAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get authCreateAccountButton;

  /// No description provided for @authHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get authHaveAccount;

  /// No description provided for @authLoginLink.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get authLoginLink;

  /// No description provided for @authFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get authFieldRequired;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least {minLength} characters'**
  String authPasswordTooShort(int minLength);

  /// No description provided for @authPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get authPasswordMismatch;

  /// No description provided for @authInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get authInvalidEmail;

  /// No description provided for @authRegisteredSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account created. Please log in.'**
  String get authRegisteredSuccess;

  /// No description provided for @otpTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with a one-time code'**
  String get otpTitle;

  /// No description provided for @otpChannelEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get otpChannelEmail;

  /// No description provided for @otpChannelPhone.
  ///
  /// In en, this message translates to:
  /// **'SMS'**
  String get otpChannelPhone;

  /// No description provided for @otpChannelWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get otpChannelWhatsapp;

  /// No description provided for @otpRecipientHint.
  ///
  /// In en, this message translates to:
  /// **'Email or phone number'**
  String get otpRecipientHint;

  /// No description provided for @otpSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get otpSendCode;

  /// No description provided for @otpEnterCodeSentTo.
  ///
  /// In en, this message translates to:
  /// **'Enter the code sent to {destination}'**
  String otpEnterCodeSentTo(String destination);

  /// No description provided for @otpCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get otpCodeHint;

  /// No description provided for @otpVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get otpVerify;

  /// No description provided for @otpResend.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get otpResend;

  /// No description provided for @otpResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String otpResendIn(int seconds);

  /// No description provided for @otpChangeRecipient.
  ///
  /// In en, this message translates to:
  /// **'Use a different email/phone'**
  String get otpChangeRecipient;

  /// No description provided for @otpErrorExpired.
  ///
  /// In en, this message translates to:
  /// **'This code has expired. Request a new one.'**
  String get otpErrorExpired;

  /// No description provided for @otpErrorMaxAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many incorrect attempts. Request a new code.'**
  String get otpErrorMaxAttempts;

  /// No description provided for @otpErrorInvalid.
  ///
  /// In en, this message translates to:
  /// **'Incorrect code. Please try again.'**
  String get otpErrorInvalid;

  /// No description provided for @otpErrorCooldown.
  ///
  /// In en, this message translates to:
  /// **'Please wait before requesting another code.'**
  String get otpErrorCooldown;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordTokenHint.
  ///
  /// In en, this message translates to:
  /// **'Reset code from your email'**
  String get resetPasswordTokenHint;

  /// No description provided for @resetPasswordNewPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get resetPasswordNewPasswordHint;

  /// No description provided for @resetPasswordConfirmHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get resetPasswordConfirmHint;

  /// No description provided for @resetPasswordSubmit.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPasswordSubmit;

  /// No description provided for @resetPasswordSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password reset. Please log in with your new password.'**
  String get resetPasswordSuccess;

  /// No description provided for @resetPasswordPolicyMinLength.
  ///
  /// In en, this message translates to:
  /// **'At least {minLength} characters'**
  String resetPasswordPolicyMinLength(int minLength);

  /// No description provided for @resetPasswordPolicyUppercase.
  ///
  /// In en, this message translates to:
  /// **'At least one uppercase letter'**
  String get resetPasswordPolicyUppercase;

  /// No description provided for @resetPasswordPolicyNumber.
  ///
  /// In en, this message translates to:
  /// **'At least one number'**
  String get resetPasswordPolicyNumber;

  /// No description provided for @resetPasswordPolicySymbol.
  ///
  /// In en, this message translates to:
  /// **'At least one symbol'**
  String get resetPasswordPolicySymbol;

  /// No description provided for @resetPasswordTokenExplainer.
  ///
  /// In en, this message translates to:
  /// **'Paste the reset code from the email we sent you.'**
  String get resetPasswordTokenExplainer;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeLightDesc.
  ///
  /// In en, this message translates to:
  /// **'Always use light theme'**
  String get themeLightDesc;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeDarkDesc.
  ///
  /// In en, this message translates to:
  /// **'Always use dark theme'**
  String get themeDarkDesc;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeSystemDesc.
  ///
  /// In en, this message translates to:
  /// **'Match device light or dark setting'**
  String get themeSystemDesc;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get darkMode;

  /// No description provided for @nightModeDayMode.
  ///
  /// In en, this message translates to:
  /// **'Night mood / Day mood'**
  String get nightModeDayMode;

  /// No description provided for @mediaPlayback.
  ///
  /// In en, this message translates to:
  /// **'Media playback'**
  String get mediaPlayback;

  /// No description provided for @playVideosOneByOneWifiOnly.
  ///
  /// In en, this message translates to:
  /// **'Play videos one by one (WiFi only)'**
  String get playVideosOneByOneWifiOnly;

  /// No description provided for @playVideosOneByOneWifiOnlyDesc.
  ///
  /// In en, this message translates to:
  /// **'If ON, only one video/reel plays at a time. Switching pauses the previous one.'**
  String get playVideosOneByOneWifiOnlyDesc;

  /// No description provided for @muteAllVideos.
  ///
  /// In en, this message translates to:
  /// **'Mute all videos'**
  String get muteAllVideos;

  /// No description provided for @muteAllVideosDesc.
  ///
  /// In en, this message translates to:
  /// **'All videos/reels will be muted/unmuted together.'**
  String get muteAllVideosDesc;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select language'**
  String get selectLanguage;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @bangla.
  ///
  /// In en, this message translates to:
  /// **'বাংলা'**
  String get bangla;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @deletePet.
  ///
  /// In en, this message translates to:
  /// **'Delete pet'**
  String get deletePet;

  /// No description provided for @deletePetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this pet? This action cannot be undone.'**
  String get deletePetConfirm;

  /// No description provided for @deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get deleted;

  /// No description provided for @notificationPreferences.
  ///
  /// In en, this message translates to:
  /// **'Notification preferences'**
  String get notificationPreferences;

  /// No description provided for @notificationPreferencesDesc.
  ///
  /// In en, this message translates to:
  /// **'Push, email, and in-app alerts'**
  String get notificationPreferencesDesc;

  /// No description provided for @privacySettings.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacySettings;

  /// No description provided for @privacySettingsDesc.
  ///
  /// In en, this message translates to:
  /// **'Profile visibility and messaging'**
  String get privacySettingsDesc;

  /// No description provided for @blockedUsers.
  ///
  /// In en, this message translates to:
  /// **'Blocked users'**
  String get blockedUsers;

  /// No description provided for @blockedUsersDesc.
  ///
  /// In en, this message translates to:
  /// **'People you have blocked'**
  String get blockedUsersDesc;

  /// No description provided for @storageAndCache.
  ///
  /// In en, this message translates to:
  /// **'Storage & cache'**
  String get storageAndCache;

  /// No description provided for @storageAndCacheDesc.
  ///
  /// In en, this message translates to:
  /// **'Usage and clear cached data'**
  String get storageAndCacheDesc;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'You will need to sign in again to use your account.'**
  String get logoutConfirmMessage;

  /// No description provided for @pushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get pushNotifications;

  /// No description provided for @pushNotificationsDesc.
  ///
  /// In en, this message translates to:
  /// **'Master switch for device alerts'**
  String get pushNotificationsDesc;

  /// No description provided for @campaignReminders.
  ///
  /// In en, this message translates to:
  /// **'Campaign reminders'**
  String get campaignReminders;

  /// No description provided for @vaccineReminders.
  ///
  /// In en, this message translates to:
  /// **'Vaccine reminders'**
  String get vaccineReminders;

  /// No description provided for @donationUpdates.
  ///
  /// In en, this message translates to:
  /// **'Donation updates'**
  String get donationUpdates;

  /// No description provided for @communityActivity.
  ///
  /// In en, this message translates to:
  /// **'Community activity'**
  String get communityActivity;

  /// No description provided for @commentsNotif.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get commentsNotif;

  /// No description provided for @likesNotif.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get likesNotif;

  /// No description provided for @followsNotif.
  ///
  /// In en, this message translates to:
  /// **'New followers'**
  String get followsNotif;

  /// No description provided for @announcementsNotif.
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get announcementsNotif;

  /// No description provided for @emergencyNotif.
  ///
  /// In en, this message translates to:
  /// **'Emergency alerts'**
  String get emergencyNotif;

  /// No description provided for @emergencyNotifDesc.
  ///
  /// In en, this message translates to:
  /// **'Critical safety and health alerts (recommended on)'**
  String get emergencyNotifDesc;

  /// No description provided for @allowEmailNotif.
  ///
  /// In en, this message translates to:
  /// **'Email notifications'**
  String get allowEmailNotif;

  /// No description provided for @allowSmsNotif.
  ///
  /// In en, this message translates to:
  /// **'SMS notifications'**
  String get allowSmsNotif;

  /// No description provided for @profileVisible.
  ///
  /// In en, this message translates to:
  /// **'Public profile'**
  String get profileVisible;

  /// No description provided for @profileVisibleDesc.
  ///
  /// In en, this message translates to:
  /// **'Anyone can view your profile'**
  String get profileVisibleDesc;

  /// No description provided for @showOnlineStatus.
  ///
  /// In en, this message translates to:
  /// **'Show online status'**
  String get showOnlineStatus;

  /// No description provided for @messagesFollowersOnly.
  ///
  /// In en, this message translates to:
  /// **'Messages from followers only'**
  String get messagesFollowersOnly;

  /// No description provided for @showActivityInFeed.
  ///
  /// In en, this message translates to:
  /// **'Show activity in feed'**
  String get showActivityInFeed;

  /// No description provided for @allowTagging.
  ///
  /// In en, this message translates to:
  /// **'Allow others to tag you'**
  String get allowTagging;

  /// No description provided for @noBlockedUsers.
  ///
  /// In en, this message translates to:
  /// **'No blocked users'**
  String get noBlockedUsers;

  /// No description provided for @noBlockedUsersDesc.
  ///
  /// In en, this message translates to:
  /// **'Users you block will appear here'**
  String get noBlockedUsersDesc;

  /// No description provided for @unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblock;

  /// No description provided for @blockUser.
  ///
  /// In en, this message translates to:
  /// **'Block user'**
  String get blockUser;

  /// No description provided for @blockUserHint.
  ///
  /// In en, this message translates to:
  /// **'Enter user ID and display name'**
  String get blockUserHint;

  /// No description provided for @userId.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get userId;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @storageUsage.
  ///
  /// In en, this message translates to:
  /// **'Storage usage'**
  String get storageUsage;

  /// No description provided for @cacheSize.
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get cacheSize;

  /// No description provided for @tempSize.
  ///
  /// In en, this message translates to:
  /// **'Temporary files'**
  String get tempSize;

  /// No description provided for @totalSize.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalSize;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get clearCache;

  /// No description provided for @clearCacheConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear cached images and temporary files?'**
  String get clearCacheConfirm;

  /// No description provided for @cacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get cacheCleared;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @accountDesc.
  ///
  /// In en, this message translates to:
  /// **'Profile, email, password, sessions'**
  String get accountDesc;

  /// No description provided for @accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account settings'**
  String get accountSettings;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @editProfileDesc.
  ///
  /// In en, this message translates to:
  /// **'Name, bio, avatar, cover photo'**
  String get editProfileDesc;

  /// No description provided for @changeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get changeEmail;

  /// No description provided for @changeEmailDesc.
  ///
  /// In en, this message translates to:
  /// **'Update your email address'**
  String get changeEmailDesc;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @changePasswordDesc.
  ///
  /// In en, this message translates to:
  /// **'Update your login password'**
  String get changePasswordDesc;

  /// No description provided for @connectedAccounts.
  ///
  /// In en, this message translates to:
  /// **'Connected accounts'**
  String get connectedAccounts;

  /// No description provided for @connectedAccountsDesc.
  ///
  /// In en, this message translates to:
  /// **'Google, Facebook and other links'**
  String get connectedAccountsDesc;

  /// No description provided for @activeSessions.
  ///
  /// In en, this message translates to:
  /// **'Active sessions'**
  String get activeSessions;

  /// No description provided for @activeSessionsDesc.
  ///
  /// In en, this message translates to:
  /// **'Devices currently signed in'**
  String get activeSessionsDesc;

  /// No description provided for @downloadMyData.
  ///
  /// In en, this message translates to:
  /// **'Download my data'**
  String get downloadMyData;

  /// No description provided for @downloadMyDataDesc.
  ///
  /// In en, this message translates to:
  /// **'Get a copy of your Furtail data'**
  String get downloadMyDataDesc;

  /// No description provided for @deactivateAccount.
  ///
  /// In en, this message translates to:
  /// **'Deactivate account'**
  String get deactivateAccount;

  /// No description provided for @deactivateAccountDesc.
  ///
  /// In en, this message translates to:
  /// **'Temporarily hide your account'**
  String get deactivateAccountDesc;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountDesc.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete all your data'**
  String get deleteAccountDesc;

  /// No description provided for @helpAndSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & support'**
  String get helpAndSupport;

  /// No description provided for @faq.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get faq;

  /// No description provided for @faqDesc.
  ///
  /// In en, this message translates to:
  /// **'Frequently asked questions'**
  String get faqDesc;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get contactSupport;

  /// No description provided for @contactSupportDesc.
  ///
  /// In en, this message translates to:
  /// **'Get help from the Furtail team'**
  String get contactSupportDesc;

  /// No description provided for @reportBug.
  ///
  /// In en, this message translates to:
  /// **'Report a bug'**
  String get reportBug;

  /// No description provided for @reportBugDesc.
  ///
  /// In en, this message translates to:
  /// **'Help us improve the app'**
  String get reportBugDesc;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @communityGuidelines.
  ///
  /// In en, this message translates to:
  /// **'Community guidelines'**
  String get communityGuidelines;

  /// No description provided for @communityGuidelinesDesc.
  ///
  /// In en, this message translates to:
  /// **'Rules for a safe, kind community'**
  String get communityGuidelinesDesc;

  /// No description provided for @communityGuidelinesShort.
  ///
  /// In en, this message translates to:
  /// **'Guidelines'**
  String get communityGuidelinesShort;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of service'**
  String get termsOfService;

  /// No description provided for @termsOfServiceDesc.
  ///
  /// In en, this message translates to:
  /// **'Legal terms for using Furtail'**
  String get termsOfServiceDesc;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @privacyPolicyDesc.
  ///
  /// In en, this message translates to:
  /// **'How we handle your data'**
  String get privacyPolicyDesc;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get appVersion;

  /// No description provided for @mediaAndStorage.
  ///
  /// In en, this message translates to:
  /// **'Media & storage'**
  String get mediaAndStorage;

  /// No description provided for @mediaAndStorageDesc.
  ///
  /// In en, this message translates to:
  /// **'Upload quality, auto-play, cache'**
  String get mediaAndStorageDesc;

  /// No description provided for @uploadQuality.
  ///
  /// In en, this message translates to:
  /// **'Upload quality'**
  String get uploadQuality;

  /// No description provided for @uploadQualityDataSaver.
  ///
  /// In en, this message translates to:
  /// **'Data saver'**
  String get uploadQualityDataSaver;

  /// No description provided for @uploadQualityStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get uploadQualityStandard;

  /// No description provided for @uploadQualityHigh.
  ///
  /// In en, this message translates to:
  /// **'High quality'**
  String get uploadQualityHigh;

  /// No description provided for @autoPlayVideos.
  ///
  /// In en, this message translates to:
  /// **'Auto-play videos'**
  String get autoPlayVideos;

  /// No description provided for @autoPlayAlways.
  ///
  /// In en, this message translates to:
  /// **'Always'**
  String get autoPlayAlways;

  /// No description provided for @autoPlayWifiOnly.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi only'**
  String get autoPlayWifiOnly;

  /// No description provided for @autoPlayNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get autoPlayNever;

  /// No description provided for @compressImages.
  ///
  /// In en, this message translates to:
  /// **'Compress images'**
  String get compressImages;

  /// No description provided for @compressImagesDesc.
  ///
  /// In en, this message translates to:
  /// **'Reduce image size before uploading'**
  String get compressImagesDesc;

  /// No description provided for @compressVideos.
  ///
  /// In en, this message translates to:
  /// **'Compress videos'**
  String get compressVideos;

  /// No description provided for @compressVideosDesc.
  ///
  /// In en, this message translates to:
  /// **'Reduce video size before uploading'**
  String get compressVideosDesc;

  /// No description provided for @saveUploadedMedia.
  ///
  /// In en, this message translates to:
  /// **'Save uploaded media to device'**
  String get saveUploadedMedia;

  /// No description provided for @saveUploadedMediaDesc.
  ///
  /// In en, this message translates to:
  /// **'Keep a local copy after posting'**
  String get saveUploadedMediaDesc;

  /// No description provided for @clearMediaCache.
  ///
  /// In en, this message translates to:
  /// **'Clear media cache'**
  String get clearMediaCache;

  /// No description provided for @clearMediaCacheDesc.
  ///
  /// In en, this message translates to:
  /// **'Free up storage used by cached media'**
  String get clearMediaCacheDesc;

  /// No description provided for @mediaCacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Media cache cleared'**
  String get mediaCacheCleared;

  /// No description provided for @whoCanComment.
  ///
  /// In en, this message translates to:
  /// **'Who can comment'**
  String get whoCanComment;

  /// No description provided for @whoCanCommentDesc.
  ///
  /// In en, this message translates to:
  /// **'Control who can reply to your posts'**
  String get whoCanCommentDesc;

  /// No description provided for @everyone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get everyone;

  /// No description provided for @followersOnly.
  ///
  /// In en, this message translates to:
  /// **'Followers only'**
  String get followersOnly;

  /// No description provided for @noOne.
  ///
  /// In en, this message translates to:
  /// **'No one'**
  String get noOne;

  /// No description provided for @mentionsNotif.
  ///
  /// In en, this message translates to:
  /// **'Mentions'**
  String get mentionsNotif;

  /// No description provided for @messagesNotif.
  ///
  /// In en, this message translates to:
  /// **'Direct messages'**
  String get messagesNotif;

  /// No description provided for @marketingNotif.
  ///
  /// In en, this message translates to:
  /// **'Promotions & tips'**
  String get marketingNotif;

  /// No description provided for @marketingNotifDesc.
  ///
  /// In en, this message translates to:
  /// **'Product updates and helpful tips'**
  String get marketingNotifDesc;

  /// No description provided for @reportAProblem.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get reportAProblem;

  /// No description provided for @reportAProblemDesc.
  ///
  /// In en, this message translates to:
  /// **'Flag harmful or inappropriate content'**
  String get reportAProblemDesc;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @noContentYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get noContentYet;

  /// No description provided for @youAreOffline.
  ///
  /// In en, this message translates to:
  /// **'You are offline'**
  String get youAreOffline;

  /// No description provided for @offlineDesc.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection'**
  String get offlineDesc;

  /// No description provided for @interactions.
  ///
  /// In en, this message translates to:
  /// **'Interactions'**
  String get interactions;

  /// No description provided for @safety.
  ///
  /// In en, this message translates to:
  /// **'Safety'**
  String get safety;

  /// No description provided for @uploadPreferences.
  ///
  /// In en, this message translates to:
  /// **'Upload preferences'**
  String get uploadPreferences;

  /// No description provided for @dangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get dangerZone;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
