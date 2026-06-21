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
  /// **'BPA App'**
  String get appTitle;

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
