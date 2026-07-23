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

  /// No description provided for @fundraisingWizardTitle.
  ///
  /// In en, this message translates to:
  /// **'Create fundraiser'**
  String get fundraisingWizardTitle;

  /// No description provided for @fundraisingWizardStepEligibility.
  ///
  /// In en, this message translates to:
  /// **'Eligibility'**
  String get fundraisingWizardStepEligibility;

  /// No description provided for @fundraisingWizardStepBeneficiary.
  ///
  /// In en, this message translates to:
  /// **'Type & beneficiary'**
  String get fundraisingWizardStepBeneficiary;

  /// No description provided for @fundraisingWizardStepStory.
  ///
  /// In en, this message translates to:
  /// **'Story & goal'**
  String get fundraisingWizardStepStory;

  /// No description provided for @fundraisingWizardStepCase.
  ///
  /// In en, this message translates to:
  /// **'Case details'**
  String get fundraisingWizardStepCase;

  /// No description provided for @fundraisingWizardStepLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get fundraisingWizardStepLocation;

  /// No description provided for @fundraisingWizardStepEvidence.
  ///
  /// In en, this message translates to:
  /// **'Evidence & media'**
  String get fundraisingWizardStepEvidence;

  /// No description provided for @fundraisingWizardStepPayout.
  ///
  /// In en, this message translates to:
  /// **'Payout'**
  String get fundraisingWizardStepPayout;

  /// No description provided for @fundraisingWizardStepPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get fundraisingWizardStepPreview;

  /// No description provided for @fundraisingWizardEligibilityDescription.
  ///
  /// In en, this message translates to:
  /// **'Confirm your fundraising profile and verification before continuing.'**
  String get fundraisingWizardEligibilityDescription;

  /// No description provided for @fundraisingWizardBeneficiaryDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose who this fundraiser supports and what type of need it covers.'**
  String get fundraisingWizardBeneficiaryDescription;

  /// No description provided for @fundraisingWizardStoryDescription.
  ///
  /// In en, this message translates to:
  /// **'Explain the story clearly and set a realistic fundraising goal.'**
  String get fundraisingWizardStoryDescription;

  /// No description provided for @fundraisingWizardCaseDescription.
  ///
  /// In en, this message translates to:
  /// **'Add pet or case details and break down the expected expense.'**
  String get fundraisingWizardCaseDescription;

  /// No description provided for @fundraisingWizardLocationDescription.
  ///
  /// In en, this message translates to:
  /// **'Select the Bangladesh location connected to this fundraiser.'**
  String get fundraisingWizardLocationDescription;

  /// No description provided for @fundraisingWizardEvidenceDescription.
  ///
  /// In en, this message translates to:
  /// **'Upload supporting photos, videos, and approved document evidence.'**
  String get fundraisingWizardEvidenceDescription;

  /// No description provided for @fundraisingWizardPayoutDescription.
  ///
  /// In en, this message translates to:
  /// **'Make sure you have an active payout method before submission.'**
  String get fundraisingWizardPayoutDescription;

  /// No description provided for @fundraisingWizardPreviewDescription.
  ///
  /// In en, this message translates to:
  /// **'Review the campaign exactly as it will be submitted for review.'**
  String get fundraisingWizardPreviewDescription;

  /// No description provided for @fundraisingBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get fundraisingBack;

  /// No description provided for @fundraisingSaveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get fundraisingSaveDraft;

  /// No description provided for @fundraisingDraftSaved.
  ///
  /// In en, this message translates to:
  /// **'Draft saved'**
  String get fundraisingDraftSaved;

  /// No description provided for @fundraisingAddPhotos.
  ///
  /// In en, this message translates to:
  /// **'Add photos'**
  String get fundraisingAddPhotos;

  /// No description provided for @fundraisingAddVideo.
  ///
  /// In en, this message translates to:
  /// **'Add video'**
  String get fundraisingAddVideo;

  /// No description provided for @fundraisingAddDocuments.
  ///
  /// In en, this message translates to:
  /// **'Add documents'**
  String get fundraisingAddDocuments;

  /// No description provided for @fundraisingCategoryField.
  ///
  /// In en, this message translates to:
  /// **'Fundraiser category'**
  String get fundraisingCategoryField;

  /// No description provided for @fundraisingCategoryTreatment.
  ///
  /// In en, this message translates to:
  /// **'Treatment'**
  String get fundraisingCategoryTreatment;

  /// No description provided for @fundraisingCategoryRescue.
  ///
  /// In en, this message translates to:
  /// **'Rescue'**
  String get fundraisingCategoryRescue;

  /// No description provided for @fundraisingCategoryShelter.
  ///
  /// In en, this message translates to:
  /// **'Shelter support'**
  String get fundraisingCategoryShelter;

  /// No description provided for @fundraisingCategoryFood.
  ///
  /// In en, this message translates to:
  /// **'Food and care'**
  String get fundraisingCategoryFood;

  /// No description provided for @fundraisingCategoryEquipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get fundraisingCategoryEquipment;

  /// No description provided for @fundraisingCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get fundraisingCategoryOther;

  /// No description provided for @fundraisingBeneficiaryTypeField.
  ///
  /// In en, this message translates to:
  /// **'Beneficiary type'**
  String get fundraisingBeneficiaryTypeField;

  /// No description provided for @fundraisingBeneficiaryPet.
  ///
  /// In en, this message translates to:
  /// **'Pet'**
  String get fundraisingBeneficiaryPet;

  /// No description provided for @fundraisingBeneficiaryPerson.
  ///
  /// In en, this message translates to:
  /// **'Person'**
  String get fundraisingBeneficiaryPerson;

  /// No description provided for @fundraisingBeneficiaryShelter.
  ///
  /// In en, this message translates to:
  /// **'Shelter'**
  String get fundraisingBeneficiaryShelter;

  /// No description provided for @fundraisingBeneficiaryOrganization.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get fundraisingBeneficiaryOrganization;

  /// No description provided for @fundraisingBeneficiaryCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get fundraisingBeneficiaryCommunity;

  /// No description provided for @fundraisingBeneficiaryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get fundraisingBeneficiaryOther;

  /// No description provided for @fundraisingBeneficiaryNameField.
  ///
  /// In en, this message translates to:
  /// **'Beneficiary name'**
  String get fundraisingBeneficiaryNameField;

  /// No description provided for @fundraisingTitleField.
  ///
  /// In en, this message translates to:
  /// **'Campaign title'**
  String get fundraisingTitleField;

  /// No description provided for @fundraisingStoryField.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get fundraisingStoryField;

  /// No description provided for @fundraisingGoalField.
  ///
  /// In en, this message translates to:
  /// **'Target amount (BDT)'**
  String get fundraisingGoalField;

  /// No description provided for @fundraisingSelectDeadline.
  ///
  /// In en, this message translates to:
  /// **'Select deadline'**
  String get fundraisingSelectDeadline;

  /// No description provided for @fundraisingPetField.
  ///
  /// In en, this message translates to:
  /// **'Related pet'**
  String get fundraisingPetField;

  /// No description provided for @fundraisingNoPetSelected.
  ///
  /// In en, this message translates to:
  /// **'No pet selected'**
  String get fundraisingNoPetSelected;

  /// No description provided for @fundraisingUrgencyField.
  ///
  /// In en, this message translates to:
  /// **'Urgency'**
  String get fundraisingUrgencyField;

  /// No description provided for @fundraisingUrgencyLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get fundraisingUrgencyLow;

  /// No description provided for @fundraisingUrgencyMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get fundraisingUrgencyMedium;

  /// No description provided for @fundraisingUrgencyHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get fundraisingUrgencyHigh;

  /// No description provided for @fundraisingUrgencyCritical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get fundraisingUrgencyCritical;

  /// No description provided for @fundraisingTreatmentProviderField.
  ///
  /// In en, this message translates to:
  /// **'Treatment provider'**
  String get fundraisingTreatmentProviderField;

  /// No description provided for @fundraisingExpenseSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Expense summary'**
  String get fundraisingExpenseSummaryTitle;

  /// No description provided for @fundraisingSuggestedGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'Suggested target'**
  String get fundraisingSuggestedGoalTitle;

  /// No description provided for @fundraisingSuggestedGoalBody.
  ///
  /// In en, this message translates to:
  /// **'Based on the expense breakdown, we suggest this target amount.'**
  String get fundraisingSuggestedGoalBody;

  /// No description provided for @fundraisingUseSuggestedTarget.
  ///
  /// In en, this message translates to:
  /// **'Use suggested target'**
  String get fundraisingUseSuggestedTarget;

  /// No description provided for @fundraisingLocationNoteField.
  ///
  /// In en, this message translates to:
  /// **'Location details'**
  String get fundraisingLocationNoteField;

  /// No description provided for @fundraisingLocationPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Selected location'**
  String get fundraisingLocationPreviewTitle;

  /// No description provided for @fundraisingLocationPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'No location selected yet'**
  String get fundraisingLocationPlaceholder;

  /// No description provided for @fundraisingMediaEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Add evidence for this campaign'**
  String get fundraisingMediaEmptyTitle;

  /// No description provided for @fundraisingMediaEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Include photos, videos, and approved documents so reviewers can verify the request.'**
  String get fundraisingMediaEmptyBody;

  /// No description provided for @fundraisingEligibilityStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Fundraising account status'**
  String get fundraisingEligibilityStatusTitle;

  /// No description provided for @fundraisingEligibilityVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get fundraisingEligibilityVerified;

  /// No description provided for @fundraisingEligibilityPending.
  ///
  /// In en, this message translates to:
  /// **'Pending review'**
  String get fundraisingEligibilityPending;

  /// No description provided for @fundraisingEligibilityRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get fundraisingEligibilityRejected;

  /// No description provided for @fundraisingEligibilityDraft.
  ///
  /// In en, this message translates to:
  /// **'Incomplete'**
  String get fundraisingEligibilityDraft;

  /// No description provided for @fundraisingEligibilityProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get fundraisingEligibilityProfileTitle;

  /// No description provided for @fundraisingEligibilityProfileBody.
  ///
  /// In en, this message translates to:
  /// **'Add address and identity details before creating a fundraiser.'**
  String get fundraisingEligibilityProfileBody;

  /// No description provided for @fundraisingEligibilityDocumentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload verification documents'**
  String get fundraisingEligibilityDocumentsTitle;

  /// No description provided for @fundraisingEligibilityDocumentsBody.
  ///
  /// In en, this message translates to:
  /// **'Reviewers need your required documents before they can approve campaigns.'**
  String get fundraisingEligibilityDocumentsBody;

  /// No description provided for @fundraisingEligibilityRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Verification needs attention'**
  String get fundraisingEligibilityRejectedTitle;

  /// No description provided for @fundraisingEligibilityRejectedBody.
  ///
  /// In en, this message translates to:
  /// **'Your verification was rejected. Review the feedback and update your information.'**
  String get fundraisingEligibilityRejectedBody;

  /// No description provided for @fundraisingEligibilityChecklistTitle.
  ///
  /// In en, this message translates to:
  /// **'Before you continue'**
  String get fundraisingEligibilityChecklistTitle;

  /// No description provided for @fundraisingEligibilityChecklistProfile.
  ///
  /// In en, this message translates to:
  /// **'Fundraising profile completed'**
  String get fundraisingEligibilityChecklistProfile;

  /// No description provided for @fundraisingEligibilityChecklistDocuments.
  ///
  /// In en, this message translates to:
  /// **'Required documents uploaded'**
  String get fundraisingEligibilityChecklistDocuments;

  /// No description provided for @fundraisingEligibilityChecklistStatus.
  ///
  /// In en, this message translates to:
  /// **'Verification status allows submission'**
  String get fundraisingEligibilityChecklistStatus;

  /// No description provided for @fundraisingCompleteVerification.
  ///
  /// In en, this message translates to:
  /// **'Complete verification'**
  String get fundraisingCompleteVerification;

  /// No description provided for @fundraisingOpenDocuments.
  ///
  /// In en, this message translates to:
  /// **'Open documents'**
  String get fundraisingOpenDocuments;

  /// No description provided for @fundraisingFixNow.
  ///
  /// In en, this message translates to:
  /// **'Fix now'**
  String get fundraisingFixNow;

  /// No description provided for @fundraisingReviewProfile.
  ///
  /// In en, this message translates to:
  /// **'Review profile'**
  String get fundraisingReviewProfile;

  /// No description provided for @fundraisingPayoutStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Payout readiness'**
  String get fundraisingPayoutStatusTitle;

  /// No description provided for @fundraisingPayoutStatusMissing.
  ///
  /// In en, this message translates to:
  /// **'Add an active payout method before submitting for review.'**
  String get fundraisingPayoutStatusMissing;

  /// No description provided for @fundraisingPayoutStatusReady.
  ///
  /// In en, this message translates to:
  /// **'An active payout method is ready for this fundraiser.'**
  String get fundraisingPayoutStatusReady;

  /// No description provided for @fundraisingManagePayout.
  ///
  /// In en, this message translates to:
  /// **'Manage payout methods'**
  String get fundraisingManagePayout;

  /// No description provided for @fundraisingPreviewSubmitTitle.
  ///
  /// In en, this message translates to:
  /// **'Final review'**
  String get fundraisingPreviewSubmitTitle;

  /// No description provided for @fundraisingPreviewSubmitBody.
  ///
  /// In en, this message translates to:
  /// **'Submitting sends this fundraiser to the review queue with PENDING_REVIEW status.'**
  String get fundraisingPreviewSubmitBody;

  /// No description provided for @fundraisingGoalLabel.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get fundraisingGoalLabel;

  /// No description provided for @fundraisingBeneficiaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Beneficiary'**
  String get fundraisingBeneficiaryLabel;

  /// No description provided for @fundraisingBeneficiaryPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Not provided yet'**
  String get fundraisingBeneficiaryPlaceholder;

  /// No description provided for @fundraisingLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get fundraisingLocationLabel;

  /// No description provided for @fundraisingEvidenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Evidence'**
  String get fundraisingEvidenceLabel;

  /// No description provided for @fundraisingPendingReviewBadge.
  ///
  /// In en, this message translates to:
  /// **'Pending review'**
  String get fundraisingPendingReviewBadge;

  /// No description provided for @fundraisingPreviewTitlePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Your campaign title will appear here'**
  String get fundraisingPreviewTitlePlaceholder;

  /// No description provided for @fundraisingPreviewStoryPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Your story preview will appear here once you add details.'**
  String get fundraisingPreviewStoryPlaceholder;

  /// No description provided for @fundraisingSubmitForReview.
  ///
  /// In en, this message translates to:
  /// **'Submit for review'**
  String get fundraisingSubmitForReview;

  /// No description provided for @fundraisingSubmittedTitle.
  ///
  /// In en, this message translates to:
  /// **'Submitted for review'**
  String get fundraisingSubmittedTitle;

  /// No description provided for @fundraisingSubmittedBody.
  ///
  /// In en, this message translates to:
  /// **'Your campaign draft is now in the review queue with PENDING_REVIEW status.'**
  String get fundraisingSubmittedBody;

  /// No description provided for @fundraisingDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get fundraisingDone;

  /// No description provided for @fundraisingLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave fundraiser draft?'**
  String get fundraisingLeaveTitle;

  /// No description provided for @fundraisingLeaveBody.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Save the draft before leaving or discard the latest edits.'**
  String get fundraisingLeaveBody;

  /// No description provided for @fundraisingStay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get fundraisingStay;

  /// No description provided for @fundraisingDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get fundraisingDiscard;

  /// No description provided for @fundraisingSaveAndLeave.
  ///
  /// In en, this message translates to:
  /// **'Save and leave'**
  String get fundraisingSaveAndLeave;

  /// No description provided for @fundraisingMissingLocalFile.
  ///
  /// In en, this message translates to:
  /// **'The selected file is no longer available on this device.'**
  String get fundraisingMissingLocalFile;

  /// No description provided for @fundraisingErrorSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again.'**
  String get fundraisingErrorSessionExpired;

  /// No description provided for @fundraisingErrorTimeout.
  ///
  /// In en, this message translates to:
  /// **'The request timed out. Please try again.'**
  String get fundraisingErrorTimeout;

  /// No description provided for @fundraisingErrorOffline.
  ///
  /// In en, this message translates to:
  /// **'You appear to be offline. Check your connection and try again.'**
  String get fundraisingErrorOffline;

  /// No description provided for @fundraisingErrorVerificationRejected.
  ///
  /// In en, this message translates to:
  /// **'Your fundraising verification needs to be updated before you can continue.'**
  String get fundraisingErrorVerificationRejected;

  /// No description provided for @fundraisingErrorMediaFailed.
  ///
  /// In en, this message translates to:
  /// **'One or more uploads failed. Retry or remove the failed items to continue.'**
  String get fundraisingErrorMediaFailed;

  /// No description provided for @fundraisingErrorSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not save this draft right now. Your local recovery copy is still available.'**
  String get fundraisingErrorSaveFailed;

  /// No description provided for @fundraisingErrorSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not submit this fundraiser for review. Please try again.'**
  String get fundraisingErrorSubmitFailed;

  /// No description provided for @fundraisingErrorValidation.
  ///
  /// In en, this message translates to:
  /// **'Please complete the required fields for this step.'**
  String get fundraisingErrorValidation;

  /// No description provided for @fundraisingErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while preparing this fundraiser.'**
  String get fundraisingErrorUnknown;

  /// No description provided for @fundraisingValidationCompleteProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete your fundraising profile first.'**
  String get fundraisingValidationCompleteProfile;

  /// No description provided for @fundraisingValidationUploadDocuments.
  ///
  /// In en, this message translates to:
  /// **'Upload the required verification documents.'**
  String get fundraisingValidationUploadDocuments;

  /// No description provided for @fundraisingValidationResolveRejection.
  ///
  /// In en, this message translates to:
  /// **'Resolve the verification rejection before continuing.'**
  String get fundraisingValidationResolveRejection;

  /// No description provided for @fundraisingValidationCategory.
  ///
  /// In en, this message translates to:
  /// **'Select a fundraiser category.'**
  String get fundraisingValidationCategory;

  /// No description provided for @fundraisingValidationBeneficiaryType.
  ///
  /// In en, this message translates to:
  /// **'Select a beneficiary type.'**
  String get fundraisingValidationBeneficiaryType;

  /// No description provided for @fundraisingValidationBeneficiaryName.
  ///
  /// In en, this message translates to:
  /// **'Enter the beneficiary name.'**
  String get fundraisingValidationBeneficiaryName;

  /// No description provided for @fundraisingValidationTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter a campaign title with at least 6 characters.'**
  String get fundraisingValidationTitle;

  /// No description provided for @fundraisingValidationStory.
  ///
  /// In en, this message translates to:
  /// **'Enter a clear story with at least 40 characters.'**
  String get fundraisingValidationStory;

  /// No description provided for @fundraisingValidationTargetAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a target amount greater than 0.'**
  String get fundraisingValidationTargetAmount;

  /// No description provided for @fundraisingValidationDeadline.
  ///
  /// In en, this message translates to:
  /// **'Select a campaign deadline.'**
  String get fundraisingValidationDeadline;

  /// No description provided for @fundraisingValidationEstimatedExpense.
  ///
  /// In en, this message translates to:
  /// **'Add an estimated expense amount.'**
  String get fundraisingValidationEstimatedExpense;

  /// No description provided for @fundraisingValidationUrgency.
  ///
  /// In en, this message translates to:
  /// **'Select the urgency level.'**
  String get fundraisingValidationUrgency;

  /// No description provided for @fundraisingValidationLocation.
  ///
  /// In en, this message translates to:
  /// **'Select the campaign location.'**
  String get fundraisingValidationLocation;

  /// No description provided for @fundraisingValidationMedia.
  ///
  /// In en, this message translates to:
  /// **'Upload at least one media or evidence item.'**
  String get fundraisingValidationMedia;

  /// No description provided for @fundraisingValidationMediaBlocking.
  ///
  /// In en, this message translates to:
  /// **'Resolve failed or pending media items before continuing.'**
  String get fundraisingValidationMediaBlocking;

  /// No description provided for @fundraisingValidationPayout.
  ///
  /// In en, this message translates to:
  /// **'Add an active payout method before submission.'**
  String get fundraisingValidationPayout;

  /// No description provided for @fundraisingDonationCheckoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete your donation'**
  String get fundraisingDonationCheckoutTitle;

  /// No description provided for @fundraisingDonationCheckoutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review the amount and continue to secure checkout.'**
  String get fundraisingDonationCheckoutSubtitle;

  /// No description provided for @fundraisingDonationAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Donation amount'**
  String get fundraisingDonationAmountLabel;

  /// No description provided for @fundraisingDonationVisibilityPublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get fundraisingDonationVisibilityPublic;

  /// No description provided for @fundraisingDonationVisibilityAnonymous.
  ///
  /// In en, this message translates to:
  /// **'Anonymous'**
  String get fundraisingDonationVisibilityAnonymous;

  /// No description provided for @fundraisingDonationMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Support message'**
  String get fundraisingDonationMessageLabel;

  /// No description provided for @fundraisingDonationMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Optional encouragement for the fundraiser'**
  String get fundraisingDonationMessageHint;

  /// No description provided for @fundraisingDonationPaymentMethodTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get fundraisingDonationPaymentMethodTitle;

  /// No description provided for @fundraisingDonationPaymentMethodOnline.
  ///
  /// In en, this message translates to:
  /// **'Online payment'**
  String get fundraisingDonationPaymentMethodOnline;

  /// No description provided for @fundraisingDonationPaymentMethodSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You will finish payment in the secure provider window.'**
  String get fundraisingDonationPaymentMethodSubtitle;

  /// No description provided for @fundraisingDonationSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get fundraisingDonationSummaryTitle;

  /// No description provided for @fundraisingDonationSummaryAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get fundraisingDonationSummaryAmount;

  /// No description provided for @fundraisingDonationSummaryFee.
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get fundraisingDonationSummaryFee;

  /// No description provided for @fundraisingDonationSummaryTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get fundraisingDonationSummaryTotal;

  /// No description provided for @fundraisingDonationConsent.
  ///
  /// In en, this message translates to:
  /// **'I understand that payment confirmation happens only after the server verifies the provider result.'**
  String get fundraisingDonationConsent;

  /// No description provided for @fundraisingDonationValidationAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a donation amount greater than 0.'**
  String get fundraisingDonationValidationAmount;

  /// No description provided for @fundraisingDonationValidationConsent.
  ///
  /// In en, this message translates to:
  /// **'Accept the confirmation terms before continuing.'**
  String get fundraisingDonationValidationConsent;

  /// No description provided for @fundraisingDonationContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get fundraisingDonationContinue;

  /// No description provided for @fundraisingDonationCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get fundraisingDonationCancel;

  /// No description provided for @fundraisingDonationProcessingTitle.
  ///
  /// In en, this message translates to:
  /// **'Processing donation'**
  String get fundraisingDonationProcessingTitle;

  /// No description provided for @fundraisingDonationProcessingHeadline.
  ///
  /// In en, this message translates to:
  /// **'We are confirming your donation'**
  String get fundraisingDonationProcessingHeadline;

  /// No description provided for @fundraisingDonationOpenProvider.
  ///
  /// In en, this message translates to:
  /// **'Open payment provider'**
  String get fundraisingDonationOpenProvider;

  /// No description provided for @fundraisingDonationCheckStatus.
  ///
  /// In en, this message translates to:
  /// **'Check status'**
  String get fundraisingDonationCheckStatus;

  /// No description provided for @fundraisingDonationStatusCreated.
  ///
  /// In en, this message translates to:
  /// **'Checkout created. Complete payment in the provider window.'**
  String get fundraisingDonationStatusCreated;

  /// No description provided for @fundraisingDonationStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Payment pending. Return after you complete the provider steps.'**
  String get fundraisingDonationStatusPending;

  /// No description provided for @fundraisingDonationStatusProcessing.
  ///
  /// In en, this message translates to:
  /// **'Payment received. Waiting for server confirmation.'**
  String get fundraisingDonationStatusProcessing;

  /// No description provided for @fundraisingDonationStatusSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Donation confirmed.'**
  String get fundraisingDonationStatusSucceeded;

  /// No description provided for @fundraisingDonationStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment failed.'**
  String get fundraisingDonationStatusFailed;

  /// No description provided for @fundraisingDonationStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Payment cancelled.'**
  String get fundraisingDonationStatusCancelled;

  /// No description provided for @fundraisingDonationStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Checkout expired.'**
  String get fundraisingDonationStatusExpired;

  /// No description provided for @fundraisingDonationStatusOnHold.
  ///
  /// In en, this message translates to:
  /// **'Donation is being reviewed.'**
  String get fundraisingDonationStatusOnHold;

  /// No description provided for @fundraisingDonationResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Donation result'**
  String get fundraisingDonationResultTitle;

  /// No description provided for @fundraisingDonationSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Donation confirmed'**
  String get fundraisingDonationSuccessTitle;

  /// No description provided for @fundraisingDonationSuccessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Thank you. Your donation was confirmed by the server.'**
  String get fundraisingDonationSuccessSubtitle;

  /// No description provided for @fundraisingDonationHoldTitle.
  ///
  /// In en, this message translates to:
  /// **'Donation under review'**
  String get fundraisingDonationHoldTitle;

  /// No description provided for @fundraisingDonationHoldSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your payment was received, but the donation needs additional review.'**
  String get fundraisingDonationHoldSubtitle;

  /// No description provided for @fundraisingDonationFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Donation not completed'**
  String get fundraisingDonationFailedTitle;

  /// No description provided for @fundraisingDonationFailedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The donation could not be completed. You can try again with a new payment attempt.'**
  String get fundraisingDonationFailedSubtitle;

  /// No description provided for @fundraisingDonationReceiptTitle.
  ///
  /// In en, this message translates to:
  /// **'Donation receipt'**
  String get fundraisingDonationReceiptTitle;

  /// No description provided for @fundraisingDonationReceiptReference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get fundraisingDonationReceiptReference;

  /// No description provided for @fundraisingDonationReceiptDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get fundraisingDonationReceiptDate;

  /// No description provided for @fundraisingDonationReceiptVisibility.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get fundraisingDonationReceiptVisibility;

  /// No description provided for @fundraisingDonationReceiptMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get fundraisingDonationReceiptMessage;

  /// No description provided for @fundraisingDonationViewReceipt.
  ///
  /// In en, this message translates to:
  /// **'View receipt'**
  String get fundraisingDonationViewReceipt;

  /// No description provided for @fundraisingDonationShareCampaign.
  ///
  /// In en, this message translates to:
  /// **'Share campaign'**
  String get fundraisingDonationShareCampaign;

  /// No description provided for @fundraisingDonationRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry payment'**
  String get fundraisingDonationRetry;

  /// No description provided for @fundraisingDonationDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get fundraisingDonationDone;

  /// No description provided for @fundraisingDonationMissingRecord.
  ///
  /// In en, this message translates to:
  /// **'This donation record is no longer available on this device.'**
  String get fundraisingDonationMissingRecord;

  /// No description provided for @fundraisingDonationCampaignLabel.
  ///
  /// In en, this message translates to:
  /// **'Campaign'**
  String get fundraisingDonationCampaignLabel;

  /// No description provided for @fundraisingDonationHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'My donations'**
  String get fundraisingDonationHistoryTitle;

  /// No description provided for @fundraisingDonationHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No donation history is available yet on this device.'**
  String get fundraisingDonationHistoryEmpty;

  /// No description provided for @fundraisingDonationFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get fundraisingDonationFilterAll;

  /// No description provided for @fundraisingDonationFilterPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get fundraisingDonationFilterPending;

  /// No description provided for @fundraisingDonationFilterSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Succeeded'**
  String get fundraisingDonationFilterSucceeded;

  /// No description provided for @fundraisingDonationFilterFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get fundraisingDonationFilterFailed;
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
