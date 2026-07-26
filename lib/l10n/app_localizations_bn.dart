// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appTitle => 'Furtail অ্যাপ';

  @override
  String get authWelcomeTitle => 'Furtail-এ স্বাগতম';

  @override
  String get authSignInSubtitle => 'চালিয়ে যেতে সাইন ইন করুন';

  @override
  String get authIdentifierHint => 'ইমেইল, ফোন নম্বর বা ইউজারনেম';

  @override
  String get authPasswordHint => 'পাসওয়ার্ড';

  @override
  String get authConfirmPasswordHint => 'পাসওয়ার্ড নিশ্চিত করুন';

  @override
  String get authForgotPassword => 'পাসওয়ার্ড ভুলে গেছেন?';

  @override
  String get authLogin => 'লগ ইন';

  @override
  String get authNoAccount => 'অ্যাকাউন্ট নেই? ';

  @override
  String get authRegister => 'রেজিস্টার';

  @override
  String get authOrContinueWith => 'অথবা চালিয়ে যান';

  @override
  String get authMore => 'আরও';

  @override
  String authProviderPending(String provider) {
    return '$provider দিয়ে সাইন-ইন এখনো উপলব্ধ নয়।';
  }

  @override
  String get authCreateAccountTitle => 'অ্যাকাউন্ট তৈরি করুন';

  @override
  String get authCreateAccountSubtitle => 'আজই Furtail কমিউনিটিতে যোগ দিন';

  @override
  String get authFullNameHint => 'পুরো নাম';

  @override
  String get authEmailHint => 'ইমেইল';

  @override
  String get authPhoneHint => 'ফোন নম্বর';

  @override
  String get authCreateAccountButton => 'অ্যাকাউন্ট তৈরি করুন';

  @override
  String get authHaveAccount => 'আগে থেকে অ্যাকাউন্ট আছে? ';

  @override
  String get authLoginLink => 'লগ ইন';

  @override
  String get authFieldRequired => 'এই ঘরটি আবশ্যক';

  @override
  String authPasswordTooShort(int minLength) {
    return 'পাসওয়ার্ড কমপক্ষে $minLength অক্ষরের হতে হবে';
  }

  @override
  String get authPasswordMismatch => 'পাসওয়ার্ড মিলছে না';

  @override
  String get authInvalidEmail => 'একটি সঠিক ইমেইল ঠিকানা লিখুন';

  @override
  String get authRegisteredSuccess => 'অ্যাকাউন্ট তৈরি হয়েছে। এখন লগ ইন করুন।';

  @override
  String get otpTitle => 'ওয়ান-টাইম কোড দিয়ে সাইন ইন করুন';

  @override
  String get otpChannelEmail => 'ইমেইল';

  @override
  String get otpChannelPhone => 'এসএমএস';

  @override
  String get otpChannelWhatsapp => 'হোয়াটসঅ্যাপ';

  @override
  String get otpRecipientHint => 'ইমেইল বা ফোন নম্বর';

  @override
  String get otpSendCode => 'কোড পাঠান';

  @override
  String otpEnterCodeSentTo(String destination) {
    return '$destination-এ পাঠানো কোডটি লিখুন';
  }

  @override
  String get otpCodeHint => 'ভেরিফিকেশন কোড';

  @override
  String get otpVerify => 'যাচাই করুন';

  @override
  String get otpResend => 'আবার কোড পাঠান';

  @override
  String otpResendIn(int seconds) {
    return '$seconds সেকেন্ডে আবার পাঠানো যাবে';
  }

  @override
  String get otpChangeRecipient => 'ভিন্ন ইমেইল/ফোন ব্যবহার করুন';

  @override
  String get otpErrorExpired =>
      'কোডের মেয়াদ শেষ হয়ে গেছে। নতুন কোড অনুরোধ করুন।';

  @override
  String get otpErrorMaxAttempts => 'অনেকবার ভুল হয়েছে। নতুন কোড অনুরোধ করুন।';

  @override
  String get otpErrorInvalid => 'ভুল কোড। আবার চেষ্টা করুন।';

  @override
  String get otpErrorCooldown => 'আবার অনুরোধ করার আগে একটু অপেক্ষা করুন।';

  @override
  String get resetPasswordTitle => 'পাসওয়ার্ড রিসেট করুন';

  @override
  String get resetPasswordTokenHint => 'ইমেইল থেকে পাওয়া রিসেট কোড';

  @override
  String get resetPasswordNewPasswordHint => 'নতুন পাসওয়ার্ড';

  @override
  String get resetPasswordConfirmHint => 'নতুন পাসওয়ার্ড নিশ্চিত করুন';

  @override
  String get resetPasswordSubmit => 'পাসওয়ার্ড রিসেট করুন';

  @override
  String get resetPasswordSuccess =>
      'পাসওয়ার্ড রিসেট হয়েছে। নতুন পাসওয়ার্ড দিয়ে লগ ইন করুন।';

  @override
  String resetPasswordPolicyMinLength(int minLength) {
    return 'কমপক্ষে $minLength অক্ষর';
  }

  @override
  String get resetPasswordPolicyUppercase => 'কমপক্ষে একটি বড় হাতের অক্ষর';

  @override
  String get resetPasswordPolicyNumber => 'কমপক্ষে একটি সংখ্যা';

  @override
  String get resetPasswordPolicySymbol => 'কমপক্ষে একটি প্রতীক';

  @override
  String get resetPasswordTokenExplainer =>
      'আমরা আপনাকে যে ইমেইল পাঠিয়েছি তা থেকে রিসেট কোডটি পেস্ট করুন।';

  @override
  String get settings => 'সেটিংস';

  @override
  String get appearance => 'অ্যাপিয়ারেন্স';

  @override
  String get themeLight => 'লাইট';

  @override
  String get themeLightDesc => 'সবসময় লাইট থিম';

  @override
  String get themeDark => 'ডার্ক';

  @override
  String get themeDarkDesc => 'সবসময় ডার্ক থিম';

  @override
  String get themeSystem => 'সিস্টেম';

  @override
  String get themeSystemDesc => 'ডিভাইসের লাইট/ডার্ক সেটিং অনুযায়ী';

  @override
  String get darkMode => 'ডার্ক মোড';

  @override
  String get nightModeDayMode => 'রাত/দিন মোড';

  @override
  String get mediaPlayback => 'মিডিয়া প্লেব্যাক';

  @override
  String get playVideosOneByOneWifiOnly =>
      'ভিডিও একটার পর একটা চালাও (শুধু WiFi)';

  @override
  String get playVideosOneByOneWifiOnlyDesc =>
      'ON থাকলে একবারে একটি ভিডিও/রিল চলবে। পরেরটাতে গেলে আগেরটা pause হবে।';

  @override
  String get muteAllVideos => 'সব ভিডিও মিউট';

  @override
  String get muteAllVideosDesc => 'সব ভিডিও/রিল একসাথে mute/unmute হবে।';

  @override
  String get language => 'ভাষা';

  @override
  String get selectLanguage => 'ভাষা নির্বাচন করুন';

  @override
  String get continueLabel => 'কন্টিনিউ';

  @override
  String get english => 'English';

  @override
  String get bangla => 'বাংলা';

  @override
  String get delete => 'ডিলিট';

  @override
  String get cancel => 'ক্যানসেল';

  @override
  String get deletePet => 'পোষা প্রাণী ডিলিট';

  @override
  String get deletePetConfirm =>
      'আপনি কি নিশ্চিতভাবে এই পোষা প্রাণীটি ডিলিট করতে চান? এটি আর ফেরত আনা যাবে না।';

  @override
  String get deleted => 'ডিলিট করা হয়েছে';

  @override
  String get notificationPreferences => 'নোটিফিকেশন পছন্দ';

  @override
  String get notificationPreferencesDesc => 'পুশ, ইমেইল ও ইন-অ্যাপ অ্যালার্ট';

  @override
  String get privacySettings => 'প্রাইভেসি';

  @override
  String get privacySettingsDesc => 'প্রোফাইল দৃশ্যমানতা ও মেসেজ';

  @override
  String get blockedUsers => 'ব্লক করা ব্যবহারকারী';

  @override
  String get blockedUsersDesc => 'যাদের আপনি ব্লক করেছেন';

  @override
  String get storageAndCache => 'স্টোরেজ ও ক্যাশ';

  @override
  String get storageAndCacheDesc => 'ব্যবহার ও ক্যাশ মুছুন';

  @override
  String get logout => 'লগ আউট';

  @override
  String get logoutConfirmTitle => 'লগ আউট করবেন?';

  @override
  String get logoutConfirmMessage => 'আবার ব্যবহার করতে সাইন ইন করতে হবে।';

  @override
  String get pushNotifications => 'পুশ নোটিফিকেশন';

  @override
  String get pushNotificationsDesc => 'ডিভাইস অ্যালার্টের মাস্টার সুইচ';

  @override
  String get campaignReminders => 'ক্যাম্পেইন রিমাইন্ডার';

  @override
  String get vaccineReminders => 'ভ্যাকসিন রিমাইন্ডার';

  @override
  String get donationUpdates => 'দান আপডেট';

  @override
  String get communityActivity => 'কমিউনিটি কার্যকলাপ';

  @override
  String get commentsNotif => 'মন্তব্য';

  @override
  String get likesNotif => 'লাইক';

  @override
  String get followsNotif => 'নতুন ফলোয়ার';

  @override
  String get announcementsNotif => 'ঘোষণা';

  @override
  String get emergencyNotif => 'জরুরি অ্যালার্ট';

  @override
  String get emergencyNotifDesc =>
      'গুরুত্বপূর্ণ স্বাস্থ্য ও নিরাপত্তা (চালু রাখা ভালো)';

  @override
  String get allowEmailNotif => 'ইমেইল নোটিফিকেশন';

  @override
  String get allowSmsNotif => 'এসএমএস নোটিফিকেশন';

  @override
  String get profileVisible => 'পাবলিক প্রোফাইল';

  @override
  String get profileVisibleDesc => 'যেকোনো ব্যক্তি আপনার প্রোফাইল দেখতে পারবে';

  @override
  String get showOnlineStatus => 'অনলাইন স্ট্যাটাস দেখান';

  @override
  String get messagesFollowersOnly => 'শুধু ফলোয়ারদের মেসেজ';

  @override
  String get showActivityInFeed => 'ফিডে কার্যকলাপ দেখান';

  @override
  String get allowTagging => 'ট্যাগ করার অনুমতি';

  @override
  String get noBlockedUsers => 'কেউ ব্লক নেই';

  @override
  String get noBlockedUsersDesc => 'ব্লক করা ব্যবহারকারী এখানে দেখা যাবে';

  @override
  String get unblock => 'আনব্লক';

  @override
  String get blockUser => 'ব্যবহারকারী ব্লক';

  @override
  String get blockUserHint => 'ইউজার আইডি ও নাম লিখুন';

  @override
  String get userId => 'ইউজার আইডি';

  @override
  String get displayName => 'ডিসপ্লে নাম';

  @override
  String get storageUsage => 'স্টোরেজ ব্যবহার';

  @override
  String get cacheSize => 'ক্যাশ';

  @override
  String get tempSize => 'অস্থায়ী ফাইল';

  @override
  String get totalSize => 'মোট';

  @override
  String get clearCache => 'ক্যাশ মুছুন';

  @override
  String get clearCacheConfirm => 'ক্যাশ করা ছবি ও অস্থায়ী ফাইল মুছবেন?';

  @override
  String get cacheCleared => 'ক্যাশ মুছে ফেলা হয়েছে';

  @override
  String get refresh => 'রিফ্রেশ';

  @override
  String get save => 'সেভ';

  @override
  String get comingSoon => 'শীঘ্রই আসছে';

  @override
  String get account => 'অ্যাকাউন্ট';

  @override
  String get accountDesc => 'প্রোফাইল, ইমেইল, পাসওয়ার্ড, সেশন';

  @override
  String get accountSettings => 'অ্যাকাউন্ট সেটিংস';

  @override
  String get editProfile => 'প্রোফাইল সম্পাদনা';

  @override
  String get editProfileDesc => 'নাম, বায়ো, অবতার, কভার ফটো';

  @override
  String get changeEmail => 'ইমেইল পরিবর্তন';

  @override
  String get changeEmailDesc => 'আপনার ইমেইল ঠিকানা আপডেট করুন';

  @override
  String get changePassword => 'পাসওয়ার্ড পরিবর্তন';

  @override
  String get changePasswordDesc => 'আপনার লগইন পাসওয়ার্ড আপডেট করুন';

  @override
  String get connectedAccounts => 'সংযুক্ত অ্যাকাউন্ট';

  @override
  String get connectedAccountsDesc => 'গুগল, ফেসবুক ও অন্যান্য সংযোগ';

  @override
  String get activeSessions => 'সক্রিয় সেশন';

  @override
  String get activeSessionsDesc => 'বর্তমানে সাইন ইন করা ডিভাইস';

  @override
  String get downloadMyData => 'আমার ডেটা ডাউনলোড';

  @override
  String get downloadMyDataDesc => 'Furtail ডেটার কপি পান';

  @override
  String get deactivateAccount => 'অ্যাকাউন্ট নিষ্ক্রিয়';

  @override
  String get deactivateAccountDesc => 'সাময়িকভাবে অ্যাকাউন্ট লুকান';

  @override
  String get deleteAccount => 'অ্যাকাউন্ট ডিলিট';

  @override
  String get deleteAccountDesc => 'সমস্ত ডেটা স্থায়ীভাবে মুছুন';

  @override
  String get helpAndSupport => 'সাহায্য ও সহায়তা';

  @override
  String get faq => 'প্রায়শই জিজ্ঞাসিত প্রশ্ন';

  @override
  String get faqDesc => 'সাধারণ প্রশ্নের উত্তর';

  @override
  String get contactSupport => 'সাপোর্টে যোগাযোগ';

  @override
  String get contactSupportDesc => 'Furtail টিমের সাহায্য নিন';

  @override
  String get reportBug => 'বাগ রিপোর্ট';

  @override
  String get reportBugDesc => 'অ্যাপ উন্নত করতে সাহায্য করুন';

  @override
  String get about => 'সম্পর্কে';

  @override
  String get communityGuidelines => 'কমিউনিটি নির্দেশিকা';

  @override
  String get communityGuidelinesDesc => 'নিরাপদ ও সদয় কমিউনিটির নিয়ম';

  @override
  String get communityGuidelinesShort => 'নির্দেশিকা';

  @override
  String get termsOfService => 'সেবার শর্তাবলী';

  @override
  String get termsOfServiceDesc => 'Furtail ব্যবহারের আইনি শর্ত';

  @override
  String get privacyPolicy => 'গোপনীয়তা নীতি';

  @override
  String get privacyPolicyDesc => 'আমরা আপনার ডেটা কীভাবে ব্যবহার করি';

  @override
  String get appVersion => 'অ্যাপ ভার্সন';

  @override
  String get mediaAndStorage => 'মিডিয়া ও স্টোরেজ';

  @override
  String get mediaAndStorageDesc => 'আপলোড মান, অটো-প্লে, ক্যাশ';

  @override
  String get uploadQuality => 'আপলোড মান';

  @override
  String get uploadQualityDataSaver => 'ডেটা সেভার';

  @override
  String get uploadQualityStandard => 'স্ট্যান্ডার্ড';

  @override
  String get uploadQualityHigh => 'উচ্চ মান';

  @override
  String get autoPlayVideos => 'ভিডিও অটো-প্লে';

  @override
  String get autoPlayAlways => 'সবসময়';

  @override
  String get autoPlayWifiOnly => 'শুধু Wi-Fi';

  @override
  String get autoPlayNever => 'কখনো না';

  @override
  String get compressImages => 'ছবি সংকুচিত করুন';

  @override
  String get compressImagesDesc => 'আপলোডের আগে ছবির আকার কমান';

  @override
  String get compressVideos => 'ভিডিও সংকুচিত করুন';

  @override
  String get compressVideosDesc => 'আপলোডের আগে ভিডিওর আকার কমান';

  @override
  String get saveUploadedMedia => 'আপলোড করা মিডিয়া সেভ করুন';

  @override
  String get saveUploadedMediaDesc => 'পোস্ট করার পর লোকাল কপি রাখুন';

  @override
  String get clearMediaCache => 'মিডিয়া ক্যাশ মুছুন';

  @override
  String get clearMediaCacheDesc => 'ক্যাশ করা মিডিয়ার স্টোরেজ খালি করুন';

  @override
  String get mediaCacheCleared => 'মিডিয়া ক্যাশ মুছে ফেলা হয়েছে';

  @override
  String get whoCanComment => 'কে মন্তব্য করতে পারবে';

  @override
  String get whoCanCommentDesc => 'আপনার পোস্টে মন্তব্য নিয়ন্ত্রণ করুন';

  @override
  String get everyone => 'সবাই';

  @override
  String get followersOnly => 'শুধু ফলোয়ার';

  @override
  String get noOne => 'কেউ না';

  @override
  String get mentionsNotif => 'মেনশন';

  @override
  String get messagesNotif => 'সরাসরি বার্তা';

  @override
  String get marketingNotif => 'প্রচার ও টিপস';

  @override
  String get marketingNotifDesc => 'পণ্য আপডেট ও সহায়ক টিপস';

  @override
  String get reportAProblem => 'সমস্যা রিপোর্ট';

  @override
  String get reportAProblemDesc => 'ক্ষতিকর বা অনুপযুক্ত কন্টেন্ট ফ্ল্যাগ করুন';

  @override
  String get somethingWentWrong => 'কিছু একটা ভুল হয়েছে';

  @override
  String get tryAgain => 'আবার চেষ্টা করুন';

  @override
  String get noContentYet => 'এখানে কিছু নেই';

  @override
  String get youAreOffline => 'আপনি অফলাইন';

  @override
  String get offlineDesc => 'ইন্টারনেট সংযোগ পরীক্ষা করুন';

  @override
  String get interactions => 'ইন্টারঅ্যাকশন';

  @override
  String get safety => 'নিরাপত্তা';

  @override
  String get uploadPreferences => 'আপলোড পছন্দ';

  @override
  String get dangerZone => 'বিপদ জোন';

  @override
  String get fundraisingWizardTitle => 'ফান্ডরেইজার তৈরি করুন';

  @override
  String get fundraisingVerificationWizardTitle => 'ফান্ডরেইজিং যাচাইকরণ';

  @override
  String fundraisingWizardStepOf(int current, int total) {
    return 'ধাপ $current এর $total';
  }

  @override
  String get fundraisingVerificationStepAccountLocation =>
      'অ্যাকাউন্ট ও অবস্থান';

  @override
  String get fundraisingVerificationStepIdentityDetails => 'পরিচয় বিবরণ';

  @override
  String get fundraisingVerificationStepDocuments => 'ডকুমেন্ট';

  @override
  String get fundraisingVerificationStepReviewConsent => 'পর্যালোচনা ও সম্মতি';

  @override
  String get fundraisingVerificationStepSubmissionStatus => 'জমা ও অবস্থা';

  @override
  String get fundraisingCancel => 'বাতিল';

  @override
  String get fundraisingStatusReady => 'প্রস্তুত';

  @override
  String get fundraisingStatusActionRequired => 'পদক্ষেপ প্রয়োজন';

  @override
  String get fundraisingStateCompleted => 'সম্পন্ন';

  @override
  String get fundraisingStateIncomplete => 'অসম্পূর্ণ';

  @override
  String get fundraisingStatePending => 'পর্যালোচনাধীন';

  @override
  String get fundraisingViewAction => 'দেখুন';

  @override
  String get fundraisingActionComplete => 'সম্পন্ন করুন';

  @override
  String get fundraisingActionEdit => 'সম্পাদনা করুন';

  @override
  String get fundraisingActionUpload => 'আপলোড করুন';

  @override
  String get fundraisingActionViewDocuments => 'ডকুমেন্ট দেখুন';

  @override
  String get fundraisingActionReview => 'পর্যালোচনা করুন';

  @override
  String get fundraisingEligibilityHelperText =>
      'চালিয়ে যেতে প্রয়োজনীয় বিষয়গুলো সম্পন্ন করুন।';

  @override
  String get fundraisingEligibilityLoadingHelper =>
      'আপনার যোগ্যতা যাচাই করা হচ্ছে…';

  @override
  String get fundraisingEligibilityErrorHelper =>
      'যোগ্যতা যাচাই করা যায়নি। আবার চেষ্টা করুন।';

  @override
  String get fundraisingEligibilityErrorTitle => 'যোগ্যতা যাচাই করা যাচ্ছে না';

  @override
  String get fundraisingEligibilityErrorMessage =>
      'আমরা আপনার ফান্ডরেইজিং যাচাইকরণ অবস্থা লোড করতে পারিনি। আপনার সংযোগ পরীক্ষা করে আবার চেষ্টা করুন।';

  @override
  String get fundraisingEligibilitySummaryTitle => 'ফান্ডরেইজিং যোগ্যতা';

  @override
  String get fundraisingEligibilitySummaryReady =>
      'সব প্রস্তুত। আপনি আপনার ফান্ডরেইজার তৈরি চালিয়ে যেতে পারেন।';

  @override
  String get fundraisingEligibilitySummaryActionRequired =>
      'ফান্ডরেইজার তৈরি করার আগে নিচের বিষয়গুলো সম্পন্ন করুন।';

  @override
  String get fundraisingEligibilitySummaryPending =>
      'আপনার অ্যাকাউন্ট পর্যালোচনাধীন থাকা অবস্থায়ও আপনি ফান্ডরেইজার তৈরি করতে পারেন। তহবিল তুলতে ভেরিফিকেশন অনুমোদন প্রয়োজন।';

  @override
  String get fundraisingEligibilitySummaryVerified =>
      'আপনার ফান্ডরেইজিং অ্যাকাউন্ট যাচাই করা হয়েছে।';

  @override
  String get fundraisingEligibilitySummaryRejected =>
      'আপনার যাচাইকরণ প্রত্যাখ্যান করা হয়েছে। বিস্তারিত দেখে তথ্য হালনাগাদ করুন।';

  @override
  String get fundraisingEligibilitySummaryRestricted =>
      'আপনার ফান্ডরেইজিং অ্যাকাউন্ট সীমাবদ্ধ। ফান্ডরেইজার তৈরি করার আগে ভেরিফিকেশন সম্পন্ন করুন বা পর্যালোচনার জন্য অপেক্ষা করুন।';

  @override
  String get fundraisingEligibilityProfileRowTitle => 'ফান্ডরেইজিং প্রোফাইল';

  @override
  String get fundraisingEligibilityDocumentsRowTitle => 'যাচাইকরণ ডকুমেন্ট';

  @override
  String get fundraisingWizardStepDetails => 'ফান্ডরেইজার বিস্তারিত';

  @override
  String get fundraisingWizardStepMediaLocation => 'মিডিয়া ও অবস্থান';

  @override
  String get fundraisingWizardDetailsDescription =>
      'প্রথমে মূল ফান্ডরেইজার তথ্য দিন, তারপর সময়সীমা এবং প্রয়োজনে অতিরিক্ত সহায়তার তথ্য যোগ করুন।';

  @override
  String get fundraisingWizardMediaLocationDescription =>
      'সহায়ক মিডিয়া যোগ করুন এবং প্রকাশ্য ক্যাম্পেইনের অবস্থান নির্বাচন করুন। চাইলে ব্যক্তিগত GPS অবস্থান গোপন রেখে সংগ্রহ করা যাবে।';

  @override
  String get fundraisingFundingModeField => 'ফান্ডিং মোড';

  @override
  String get fundraisingFundingModeOneTime => 'এককালীন ফান্ডরেইজার';

  @override
  String get fundraisingFundingModeOngoing => 'চলমান সহায়তা';

  @override
  String get fundraisingDurationField => 'সময়সীমা';

  @override
  String fundraisingDurationPresetDays(int days) {
    return '$days দিন';
  }

  @override
  String get fundraisingDurationCustom => 'কাস্টম';

  @override
  String get fundraisingMonthlyGoalField => 'ঐচ্ছিক মাসিক লক্ষ্য (BDT)';

  @override
  String get fundraisingOptionalEstimatedTotalField =>
      'ঐচ্ছিক মোট আনুমানিক (BDT)';

  @override
  String get fundraisingExpenseNotesField => 'সহজ খরচের নোট';

  @override
  String get fundraisingAddExpenseBreakdown => 'খরচের বিভাজন যোগ করুন';

  @override
  String get fundraisingHideExpenseBreakdown => 'খরচের বিভাজন লুকান';

  @override
  String get fundraisingPrivacyLocationCopy =>
      'শুধু ব্যক্তিগত নিরাপত্তা অবস্থান সংরক্ষণ করতে চাইলে বর্তমান অবস্থান ব্যবহার করুন। এটি প্রকাশ্য ক্যাম্পেইনের অবস্থান বদলাবে না।';

  @override
  String get fundraisingUseCurrentLocation => 'বর্তমান অবস্থান ব্যবহার করুন';

  @override
  String get fundraisingCurrentLocationCaptured =>
      'বর্তমান অবস্থান গোপনে সংরক্ষিত হয়েছে';

  @override
  String get fundraisingLocationPermissionFailed =>
      'আপনার বর্তমান অবস্থান সংগ্রহ করা যায়নি।';

  @override
  String get fundraisingOngoingSupportLabel => 'চলমান সহায়তা';

  @override
  String get fundraisingNoEndDate => 'কোনো বাধ্যতামূলক শেষ তারিখ নেই।';

  @override
  String get fundraisingNextReviewField => 'পরবর্তী পর্যালোচনা';

  @override
  String get fundraisingWizardStepEligibility => 'যোগ্যতা';

  @override
  String get fundraisingWizardStepBeneficiary => 'ধরন ও উপকারভোগী';

  @override
  String get fundraisingWizardStepStory => 'গল্প ও লক্ষ্য';

  @override
  String get fundraisingWizardStepCase => 'কেসের বিস্তারিত';

  @override
  String get fundraisingWizardStepLocation => 'অবস্থান';

  @override
  String get fundraisingWizardStepEvidence => 'প্রমাণ ও মিডিয়া';

  @override
  String get fundraisingWizardStepPayout => 'পেআউট';

  @override
  String get fundraisingWizardStepPreview => 'প্রিভিউ';

  @override
  String get fundraisingWizardEligibilityDescription =>
      'আগে আপনার ফান্ডরেইজিং প্রোফাইল ও ভেরিফিকেশন অবস্থা নিশ্চিত করুন।';

  @override
  String get fundraisingWizardBeneficiaryDescription =>
      'কার জন্য ফান্ডরেইজার এবং কোন ধরনের প্রয়োজন তা নির্বাচন করুন।';

  @override
  String get fundraisingWizardStoryDescription =>
      'পরিষ্কারভাবে গল্প লিখুন এবং বাস্তবসম্মত লক্ষ্য নির্ধারণ করুন।';

  @override
  String get fundraisingWizardCaseDescription =>
      'পোষা প্রাণী বা কেসের বিস্তারিত এবং সম্ভাব্য খরচ যোগ করুন।';

  @override
  String get fundraisingWizardLocationDescription =>
      'এই ফান্ডরেইজারের সাথে সংশ্লিষ্ট বাংলাদেশের অবস্থান নির্বাচন করুন।';

  @override
  String get fundraisingWizardEvidenceDescription =>
      'যাচাইয়ের জন্য সহায়ক ছবি, ভিডিও এবং অনুমোদিত ডকুমেন্ট আপলোড করুন।';

  @override
  String get fundraisingWizardPayoutDescription =>
      'জমা দেওয়ার আগে অন্তত একটি সক্রিয় পেআউট পদ্ধতি আছে কি না নিশ্চিত করুন।';

  @override
  String get fundraisingWizardPreviewDescription =>
      'রিভিউতে পাঠানোর আগে পুরো ক্যাম্পেইন দেখে নিন।';

  @override
  String get fundraisingBack => 'পেছনে';

  @override
  String get fundraisingSaveDraft => 'ড্রাফট সেভ করুন';

  @override
  String get fundraisingDraftSaved => 'ড্রাফট সেভ হয়েছে';

  @override
  String get fundraisingContinueToFundraiser => 'ফান্ডরেইজারে এগিয়ে যান';

  @override
  String get fundraisingRequired => 'প্রয়োজনীয়';

  @override
  String get fundraisingUploaded => 'আপলোড হয়েছে';

  @override
  String get fundraisingOptional => 'ঐচ্ছিক';

  @override
  String get fundraisingAddPhotos => 'ছবি যোগ করুন';

  @override
  String get fundraisingAddVideo => 'ভিডিও যোগ করুন';

  @override
  String get fundraisingAddDocuments => 'ডকুমেন্ট যোগ করুন';

  @override
  String get fundraisingCategoryField => 'ফান্ডরেইজার ক্যাটাগরি';

  @override
  String get fundraisingCategoryTreatment => 'চিকিৎসা';

  @override
  String get fundraisingCategoryRescue => 'রেসকিউ';

  @override
  String get fundraisingCategoryShelter => 'শেল্টার সহায়তা';

  @override
  String get fundraisingCategoryFood => 'খাদ্য ও যত্ন';

  @override
  String get fundraisingCategoryEquipment => 'ইকুইপমেন্ট';

  @override
  String get fundraisingCategoryOther => 'অন্যান্য';

  @override
  String get fundraisingBeneficiaryTypeField => 'উপকারভোগীর ধরন';

  @override
  String get fundraisingBeneficiaryPet => 'পোষা প্রাণী';

  @override
  String get fundraisingBeneficiaryPerson => 'ব্যক্তি';

  @override
  String get fundraisingBeneficiaryShelter => 'শেল্টার';

  @override
  String get fundraisingBeneficiaryOrganization => 'প্রতিষ্ঠান';

  @override
  String get fundraisingBeneficiaryCommunity => 'কমিউনিটি';

  @override
  String get fundraisingBeneficiaryOther => 'অন্যান্য';

  @override
  String get fundraisingBeneficiaryNameField => 'উপকারভোগীর নাম';

  @override
  String get fundraisingTitleField => 'ক্যাম্পেইনের শিরোনাম';

  @override
  String get fundraisingStoryField => 'গল্প';

  @override
  String get fundraisingGoalField => 'লক্ষ্যমাত্রা (BDT)';

  @override
  String get fundraisingSelectDeadline => 'শেষ তারিখ নির্বাচন করুন';

  @override
  String get fundraisingPetField => 'সংশ্লিষ্ট পোষা প্রাণী';

  @override
  String get fundraisingNoPetSelected => 'কোনো পোষা প্রাণী নির্বাচন করা হয়নি';

  @override
  String get fundraisingUrgencyField => 'জরুরিতা';

  @override
  String get fundraisingUrgencyLow => 'কম';

  @override
  String get fundraisingUrgencyMedium => 'মাঝারি';

  @override
  String get fundraisingUrgencyHigh => 'উচ্চ';

  @override
  String get fundraisingUrgencyCritical => 'অত্যন্ত জরুরি';

  @override
  String get fundraisingTreatmentProviderField => 'চিকিৎসা প্রদানকারী';

  @override
  String get fundraisingExpenseSummaryTitle => 'খরচের সারসংক্ষেপ';

  @override
  String get fundraisingSuggestedGoalTitle => 'প্রস্তাবিত লক্ষ্য';

  @override
  String get fundraisingSuggestedGoalBody =>
      'খরচের বিবরণ অনুযায়ী এই লক্ষ্য পরিমাণটি প্রস্তাব করা হচ্ছে।';

  @override
  String get fundraisingUseSuggestedTarget => 'প্রস্তাবিত লক্ষ্য ব্যবহার করুন';

  @override
  String get fundraisingLocationNoteField => 'অবস্থানের বিস্তারিত';

  @override
  String get fundraisingLocationPreviewTitle => 'নির্বাচিত অবস্থান';

  @override
  String get fundraisingLocationPlaceholder =>
      'এখনও কোনো অবস্থান নির্বাচন করা হয়নি';

  @override
  String get fundraisingMediaEmptyTitle => 'এই ক্যাম্পেইনের প্রমাণ যোগ করুন';

  @override
  String get fundraisingMediaEmptyBody =>
      'রিভিউয়াররা যেন অনুরোধটি যাচাই করতে পারেন, সে জন্য ছবি, ভিডিও এবং অনুমোদিত ডকুমেন্ট দিন।';

  @override
  String get fundraisingEligibilityStatusTitle =>
      'ফান্ডরেইজিং অ্যাকাউন্টের অবস্থা';

  @override
  String get fundraisingEligibilityVerified => 'ভেরিফায়েড';

  @override
  String get fundraisingEligibilityPending => 'ভেরিফিকেশন অপেক্ষমান';

  @override
  String get fundraisingEligibilityRejected => 'প্রত্যাখ্যাত';

  @override
  String get fundraisingEligibilityDraft => 'অসম্পূর্ণ';

  @override
  String get fundraisingEligibilityRestricted => 'ভেরিফিকেশন সীমাবদ্ধ';

  @override
  String get fundraisingEligibilityProfileTitle =>
      'আপনার প্রোফাইল সম্পূর্ণ করুন';

  @override
  String get fundraisingEligibilityProfileBody =>
      'ফান্ডরেইজার তৈরির আগে ঠিকানা ও পরিচয় সম্পর্কিত তথ্য যোগ করুন।';

  @override
  String get fundraisingEligibilityDocumentsTitle =>
      'ভেরিফিকেশন ডকুমেন্ট আপলোড করুন';

  @override
  String get fundraisingEligibilityDocumentsBody =>
      'ক্যাম্পেইন অনুমোদনের আগে প্রয়োজনীয় ডকুমেন্ট রিভিউয়ারদের দরকার হবে।';

  @override
  String get fundraisingEligibilityRejectedTitle =>
      'ভেরিফিকেশনে সংশোধন প্রয়োজন';

  @override
  String get fundraisingEligibilityRejectedBody =>
      'আপনার ভেরিফিকেশন প্রত্যাখ্যাত হয়েছে। কারণ দেখে তথ্য আপডেট করুন।';

  @override
  String get fundraisingEligibilityChecklistTitle => 'এগিয়ে যাওয়ার আগে';

  @override
  String get fundraisingEligibilityChecklistProfile =>
      'ফান্ডরেইজিং প্রোফাইল সম্পূর্ণ';

  @override
  String get fundraisingEligibilityChecklistDocuments =>
      'প্রয়োজনীয় ডকুমেন্ট আপলোড করা হয়েছে';

  @override
  String get fundraisingEligibilityChecklistStatus =>
      'ভেরিফিকেশন স্ট্যাটাস জমা দেওয়ার উপযোগী';

  @override
  String get fundraisingCompleteVerification => 'ভেরিফিকেশন সম্পূর্ণ করুন';

  @override
  String get fundraisingOpenDocuments => 'ডকুমেন্ট খুলুন';

  @override
  String get fundraisingFixNow => 'এখনই ঠিক করুন';

  @override
  String get fundraisingReviewProfile => 'প্রোফাইল দেখুন';

  @override
  String get fundraisingPayoutStatusTitle => 'পেআউট প্রস্তুতি';

  @override
  String get fundraisingPayoutStatusMissing =>
      'রিভিউতে পাঠানোর আগে একটি সক্রিয় পেআউট পদ্ধতি যোগ করুন।';

  @override
  String get fundraisingPayoutStatusReady =>
      'এই ফান্ডরেইজারের জন্য একটি সক্রিয় পেআউট পদ্ধতি প্রস্তুত আছে।';

  @override
  String get fundraisingManagePayout => 'পেআউট পদ্ধতি পরিচালনা করুন';

  @override
  String get fundraisingPreviewSubmitTitle => 'চূড়ান্ত পর্যালোচনা';

  @override
  String get fundraisingPreviewSubmitBody =>
      'জমা দিলে এই ফান্ডরেইজারটি PENDING_REVIEW অবস্থায় রিভিউ কিউতে যাবে।';

  @override
  String get fundraisingGoalLabel => 'লক্ষ্য';

  @override
  String get fundraisingBeneficiaryLabel => 'উপকারভোগী';

  @override
  String get fundraisingBeneficiaryPlaceholder => 'এখনও দেওয়া হয়নি';

  @override
  String get fundraisingLocationLabel => 'অবস্থান';

  @override
  String get fundraisingEvidenceLabel => 'প্রমাণ';

  @override
  String get fundraisingPendingReviewBadge => 'রিভিউ চলছে';

  @override
  String get fundraisingPreviewTitlePlaceholder =>
      'আপনার ক্যাম্পেইনের শিরোনাম এখানে দেখা যাবে';

  @override
  String get fundraisingPreviewStoryPlaceholder =>
      'বিস্তারিত যোগ করলে আপনার গল্পের প্রিভিউ এখানে দেখা যাবে।';

  @override
  String get fundraisingSubmitForReview => 'রিভিউতে জমা দিন';

  @override
  String get fundraisingSubmittedTitle => 'রিভিউতে জমা হয়েছে';

  @override
  String get fundraisingSubmittedBody =>
      'আপনার ক্যাম্পেইন ড্রাফট এখন PENDING_REVIEW অবস্থায় রিভিউ কিউতে আছে।';

  @override
  String get fundraisingDone => 'সম্পন্ন';

  @override
  String get fundraisingLeaveTitle => 'ফান্ডরেইজার ড্রাফট ছেড়ে যাবেন?';

  @override
  String get fundraisingLeaveBody =>
      'আপনার কিছু আনসেভড পরিবর্তন আছে। বের হওয়ার আগে ড্রাফট সেভ করুন অথবা সাম্প্রতিক পরিবর্তন বাতিল করুন।';

  @override
  String get fundraisingStay => 'থাকুন';

  @override
  String get fundraisingDiscard => 'বাতিল করুন';

  @override
  String get fundraisingSaveAndLeave => 'সেভ করে বের হন';

  @override
  String get fundraisingMissingLocalFile =>
      'নির্বাচিত ফাইলটি আর এই ডিভাইসে পাওয়া যাচ্ছে না।';

  @override
  String get fundraisingErrorSessionExpired =>
      'আপনার সেশন মেয়াদোত্তীর্ণ হয়েছে। আবার সাইন ইন করুন।';

  @override
  String get fundraisingErrorTimeout =>
      'রিকোয়েস্টের সময়সীমা শেষ হয়েছে। আবার চেষ্টা করুন।';

  @override
  String get fundraisingErrorOffline =>
      'আপনি অফলাইনে আছেন। সংযোগ পরীক্ষা করে আবার চেষ্টা করুন।';

  @override
  String get fundraisingErrorVerificationRejected =>
      'আপনার ফান্ডরেইজিং ভেরিফিকেশন আপডেট না করা পর্যন্ত আপনি এগোতে পারবেন না।';

  @override
  String get fundraisingErrorMediaFailed =>
      'এক বা একাধিক আপলোড ব্যর্থ হয়েছে। আবার চেষ্টা করুন অথবা ব্যর্থ আইটেম সরিয়ে দিন।';

  @override
  String get fundraisingMediaNeedsAttention => 'মনোযোগ প্রয়োজন';

  @override
  String get fundraisingMediaRetry => 'আবার চেষ্টা করুন';

  @override
  String get fundraisingMediaRemove => 'সরান';

  @override
  String get fundraisingNeedsAttentionFix => 'ঠিক করুন';

  @override
  String get fundraisingErrorSaveFailed =>
      'এখন ড্রাফট সেভ করা যায়নি। আপনার লোকাল রিকভারি কপি সংরক্ষিত আছে।';

  @override
  String get fundraisingErrorSubmitFailed =>
      'ফান্ডরেইজারটি রিভিউতে জমা দেওয়া যায়নি। আবার চেষ্টা করুন।';

  @override
  String get fundraisingErrorValidation => 'এই ধাপের প্রয়োজনীয় তথ্য পূরণ করুন।';

  @override
  String get fundraisingErrorUnknown =>
      'ফান্ডরেইজার প্রস্তুত করার সময় একটি সমস্যা হয়েছে।';

  @override
  String get fundraisingValidationCompleteProfile =>
      'আগে আপনার ফান্ডরেইজিং প্রোফাইল সম্পূর্ণ করুন।';

  @override
  String get fundraisingValidationUploadDocuments =>
      'প্রয়োজনীয় ভেরিফিকেশন ডকুমেন্ট আপলোড করুন।';

  @override
  String get fundraisingValidationResolveRejection =>
      'এগিয়ে যাওয়ার আগে ভেরিফিকেশন প্রত্যাখ্যানের কারণ ঠিক করুন।';

  @override
  String get fundraisingValidationCategory =>
      'একটি ফান্ডরেইজার ক্যাটাগরি নির্বাচন করুন।';

  @override
  String get fundraisingValidationBeneficiaryType =>
      'একটি উপকারভোগীর ধরন নির্বাচন করুন।';

  @override
  String get fundraisingValidationBeneficiaryName => 'উপকারভোগীর নাম লিখুন।';

  @override
  String get fundraisingValidationTitle =>
      'কমপক্ষে ৬ অক্ষরের একটি শিরোনাম লিখুন।';

  @override
  String get fundraisingValidationStory =>
      'কমপক্ষে ৪০ অক্ষরের একটি পরিষ্কার গল্প লিখুন।';

  @override
  String get fundraisingValidationTargetAmount =>
      '০-এর বেশি একটি লক্ষ্য পরিমাণ দিন।';

  @override
  String get fundraisingValidationDeadline => 'একটি শেষ তারিখ নির্বাচন করুন।';

  @override
  String get fundraisingValidationEstimatedExpense =>
      'সম্ভাব্য খরচের পরিমাণ যোগ করুন।';

  @override
  String get fundraisingValidationUrgency => 'জরুরিতার মাত্রা নির্বাচন করুন।';

  @override
  String get fundraisingValidationLocation =>
      'ক্যাম্পেইনের অবস্থান নির্বাচন করুন।';

  @override
  String get fundraisingValidationMedia =>
      'অন্তত একটি মিডিয়া বা প্রমাণ আপলোড করুন।';

  @override
  String get fundraisingValidationMediaBlocking =>
      'এগিয়ে যাওয়ার আগে ব্যর্থ বা অসম্পূর্ণ মিডিয়া আইটেম সমাধান করুন।';

  @override
  String get fundraisingValidationPayout =>
      'জমা দেওয়ার আগে একটি সক্রিয় পেআউট পদ্ধতি যোগ করুন।';

  @override
  String get fundraisingDonationCheckoutTitle => 'ডোনেশন সম্পূর্ণ করুন';

  @override
  String get fundraisingDonationCheckoutSubtitle =>
      'পরিমাণ পর্যালোচনা করে সুরক্ষিত চেকআউটে এগিয়ে যান।';

  @override
  String get fundraisingDonationAmountLabel => 'ডোনেশনের পরিমাণ';

  @override
  String get fundraisingDonationVisibilityPublic => 'সর্বজনীন';

  @override
  String get fundraisingDonationVisibilityAnonymous => 'গোপন';

  @override
  String get fundraisingDonationMessageLabel => 'সহায়তার বার্তা';

  @override
  String get fundraisingDonationMessageHint =>
      'ফান্ডরেইজারের জন্য একটি ঐচ্ছিক উৎসাহবার্তা';

  @override
  String get fundraisingDonationPaymentMethodTitle => 'পেমেন্ট পদ্ধতি';

  @override
  String get fundraisingDonationPaymentMethodOnline => 'অনলাইন পেমেন্ট';

  @override
  String get fundraisingDonationPaymentMethodSubtitle =>
      'সুরক্ষিত প্রোভাইডার উইন্ডোতে পেমেন্ট সম্পন্ন হবে।';

  @override
  String get fundraisingDonationSummaryTitle => 'সারসংক্ষেপ';

  @override
  String get fundraisingDonationSummaryAmount => 'পরিমাণ';

  @override
  String get fundraisingDonationSummaryFee => 'ফি';

  @override
  String get fundraisingDonationSummaryTotal => 'মোট';

  @override
  String get fundraisingDonationConsent =>
      'আমি বুঝি যে প্রোভাইডারের ফলাফল সার্ভার যাচাই করার পরে তবেই পেমেন্ট নিশ্চিত হবে।';

  @override
  String get fundraisingDonationValidationAmount =>
      '০-এর বেশি একটি ডোনেশন পরিমাণ লিখুন।';

  @override
  String get fundraisingDonationValidationConsent =>
      'এগিয়ে যাওয়ার আগে নিশ্চিতকরণ শর্ত মেনে নিন।';

  @override
  String get fundraisingDonationContinue => 'এগিয়ে যান';

  @override
  String get fundraisingDonationCancel => 'বাতিল';

  @override
  String get fundraisingDonationProcessingTitle => 'ডোনেশন প্রক্রিয়াধীন';

  @override
  String get fundraisingDonationProcessingHeadline =>
      'আমরা আপনার ডোনেশন নিশ্চিত করছি';

  @override
  String get fundraisingDonationOpenProvider => 'পেমেন্ট প্রোভাইডার খুলুন';

  @override
  String get fundraisingDonationCheckStatus => 'স্ট্যাটাস দেখুন';

  @override
  String get fundraisingDonationStatusCreated =>
      'চেকআউট তৈরি হয়েছে। প্রোভাইডার উইন্ডোতে পেমেন্ট সম্পন্ন করুন।';

  @override
  String get fundraisingDonationStatusPending =>
      'পেমেন্ট অপেক্ষমান। প্রোভাইডারের ধাপ শেষ করে ফিরে আসুন।';

  @override
  String get fundraisingDonationStatusProcessing =>
      'পেমেন্ট পাওয়া গেছে। সার্ভার নিশ্চিতকরণের অপেক্ষায় আছে।';

  @override
  String get fundraisingDonationStatusSucceeded => 'ডোনেশন নিশ্চিত হয়েছে।';

  @override
  String get fundraisingDonationStatusFailed => 'পেমেন্ট ব্যর্থ হয়েছে।';

  @override
  String get fundraisingDonationStatusCancelled => 'পেমেন্ট বাতিল হয়েছে।';

  @override
  String get fundraisingDonationStatusExpired => 'চেকআউটের সময় শেষ হয়েছে।';

  @override
  String get fundraisingDonationStatusOnHold => 'ডোনেশন পর্যালোচনায় আছে।';

  @override
  String get fundraisingDonationResultTitle => 'ডোনেশনের ফলাফল';

  @override
  String get fundraisingDonationSuccessTitle => 'ডোনেশন নিশ্চিত হয়েছে';

  @override
  String get fundraisingDonationSuccessSubtitle =>
      'ধন্যবাদ। সার্ভার আপনার ডোনেশন নিশ্চিত করেছে।';

  @override
  String get fundraisingDonationHoldTitle => 'ডোনেশন পর্যালোচনায় আছে';

  @override
  String get fundraisingDonationHoldSubtitle =>
      'পেমেন্ট পাওয়া গেছে, তবে ডোনেশনটি অতিরিক্ত পর্যালোচনা প্রয়োজন।';

  @override
  String get fundraisingDonationFailedTitle => 'ডোনেশন সম্পন্ন হয়নি';

  @override
  String get fundraisingDonationFailedSubtitle =>
      'ডোনেশন সম্পন্ন করা যায়নি। নতুন পেমেন্ট প্রচেষ্টায় আবার চেষ্টা করতে পারেন।';

  @override
  String get fundraisingDonationReceiptTitle => 'ডোনেশন রসিদ';

  @override
  String get fundraisingDonationReceiptReference => 'রেফারেন্স';

  @override
  String get fundraisingDonationReceiptDate => 'তারিখ';

  @override
  String get fundraisingDonationReceiptVisibility => 'দৃশ্যমানতা';

  @override
  String get fundraisingDonationReceiptMessage => 'বার্তা';

  @override
  String get fundraisingDonationViewReceipt => 'রসিদ দেখুন';

  @override
  String get fundraisingDonationShareCampaign => 'ক্যাম্পেইন শেয়ার করুন';

  @override
  String get fundraisingDonationRetry => 'পেমেন্ট আবার চেষ্টা করুন';

  @override
  String get fundraisingDonationDone => 'সম্পন্ন';

  @override
  String get fundraisingDonationMissingRecord =>
      'এই ডোনেশন রেকর্ডটি আর এই ডিভাইসে পাওয়া যাচ্ছে না।';

  @override
  String get fundraisingDonationCampaignLabel => 'ক্যাম্পেইন';

  @override
  String get fundraisingDonationHistoryTitle => 'আমার ডোনেশন';

  @override
  String get fundraisingDonationHistoryEmpty =>
      'এই ডিভাইসে এখনো কোনো ডোনেশন ইতিহাস নেই।';

  @override
  String get fundraisingDonationFilterAll => 'সব';

  @override
  String get fundraisingDonationFilterPending => 'অপেক্ষমান';

  @override
  String get fundraisingDonationFilterSucceeded => 'সফল';

  @override
  String get fundraisingDonationFilterFailed => 'ব্যর্থ';
}
