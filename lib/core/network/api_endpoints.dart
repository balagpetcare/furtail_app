import 'api_config.dart';

class ApiEndpoints {
  // ---------- NOTIFICATIONS / PUSH ----------
  /// Register FCM device token with backend.
  static String registerDeviceToken() => "${ApiConfig.apiV1}/notifications/device-token";
  /// Unregister / deactivate device token on logout.
  static String unregisterDeviceToken() => "${ApiConfig.apiV1}/notifications/device-token";
  static String notificationSettings() => "${ApiConfig.apiV1}/notifications/settings";
  static String notificationsList({int limit = 20, int? cursor}) {
    String url = "${ApiConfig.apiV1}/notifications?limit=$limit";
    if (cursor != null) url += "&cursor=$cursor";
    return url;
  }
  static String markNotificationRead(int id) =>
      "${ApiConfig.apiV1}/notifications/$id/read";
  static String markAllNotificationsRead() =>
      "${ApiConfig.apiV1}/notifications/read-all";
  static String notificationsUnreadCount() =>
      "${ApiConfig.apiV1}/notifications/unread-count";

  // ---------- AUTH ----------
  static String login() => "${ApiConfig.apiV1}/auth/login";
  static String register() => "${ApiConfig.apiV1}/auth/register";
  static String socialGoogle() => "${ApiConfig.apiV1}/auth/social/google";
  static String socialFacebook() => "${ApiConfig.apiV1}/auth/social/facebook";

  // ---------- PROFILE ----------
  static String myProfile() => "${ApiConfig.userApi}/profile";
  static String updateMyProfile() => "${ApiConfig.userApi}/profile"; // PATCH

  // ---------- PETS ----------
  static String allPets() => "${ApiConfig.userApi}/pets/all";
  static String registerPet() => "${ApiConfig.userApi}/pets/register";
  static String updatePet(int petId) => "${ApiConfig.userApi}/pets/$petId";
  static String deletePet(int petId) =>
      "${ApiConfig.userApi}/pets/$petId"; // DELETE
  /// Deprecated: backend uses media/upload + updatePet(profilePicId)
  static String uploadPetPhoto(int petId) => ApiEndpoints.mediaUpload();

  // ---------- MEDIA ----------
  static String mediaUpload() => "${ApiConfig.apiV1}/media/upload";

  // ---------- POSTS / FEED ----------
  static String postsFeed({int limit = 50}) =>
      "${ApiConfig.apiV1}/posts/feed?limit=$limit";
  static String postsUserFeed({required int userId, int limit = 50}) =>
      "${ApiConfig.apiV1}/posts/user/$userId?limit=$limit";
  static String postsUserPhotos({required int userId, int limit = 50}) =>
      "${ApiConfig.apiV1}/posts/user/$userId/photos?limit=$limit";
  static String postsUserVideos({required int userId, int limit = 50}) =>
      "${ApiConfig.apiV1}/posts/user/$userId/videos?limit=$limit";
  static String postById({required int postId}) =>
      "${ApiConfig.apiV1}/posts/$postId";
  static String postsCreate() => "${ApiConfig.apiV1}/posts";
  static String postsUpdate({required int postId}) =>
      "${ApiConfig.apiV1}/posts/$postId"; // PATCH
  static String postsDelete({required int postId}) =>
      "${ApiConfig.apiV1}/posts/$postId"; // DELETE
  // Backwards compatible (older code may call postLike/postComments)
  static String postLike(int postId) => "${ApiConfig.apiV1}/posts/$postId/like";
  static String postComments(int postId) =>
      "${ApiConfig.apiV1}/posts/$postId/comments";

  // Newer, explicit helpers
  static String postsLike({required int postId}) =>
      "${ApiConfig.apiV1}/posts/$postId/like";
  static String postsUnlike({required int postId}) =>
      "${ApiConfig.apiV1}/posts/$postId/like"; // DELETE
  static String postsComments({required int postId, int limit = 100}) =>
      "${ApiConfig.apiV1}/posts/$postId/comments?limit=$limit";
  static String postsAddComment({required int postId}) =>
      "${ApiConfig.apiV1}/posts/$postId/comments";

  // Comments (likes + replies)
  static String postsCommentLike({
    required int postId,
    required int commentId,
  }) => "${ApiConfig.apiV1}/posts/$postId/comments/$commentId/like";
  static String postsCommentUnlike({
    required int postId,
    required int commentId,
  }) => "${ApiConfig.apiV1}/posts/$postId/comments/$commentId/like"; // DELETE
  static String postsCommentReply({
    required int postId,
    required int commentId,
  }) => "${ApiConfig.apiV1}/posts/$postId/comments/$commentId/replies";

  // ---------- COMMON ----------
  static String animalTypes() => "${ApiConfig.apiV1}/common/animal-types";
  static String breedsByType(int typeId) =>
      "${ApiConfig.apiV1}/common/breeds/$typeId";

  // ---------- BD LOCATIONS ----------
  static String bdDivisions() => "${ApiConfig.apiV1}/common/bd/divisions";
  static String bdDistricts({required int divisionId}) =>
      "${ApiConfig.apiV1}/common/bd/districts?divisionId=$divisionId";
  static String bdUpazilas({required int districtId}) =>
      "${ApiConfig.apiV1}/common/bd/upazilas?districtId=$districtId";
  static String bdAreas({required int upazilaId}) =>
      "${ApiConfig.apiV1}/common/bd/areas?upazilaId=$upazilaId";

  // ---------- CENTRALIZED LOCATION MASTER ----------
  static String locationMasterDivisions({String locale = 'en', int pageSize = 64, String? q}) {
    final qp = <String, String>{'locale': locale, 'pageSize': '$pageSize'};
    if (q != null && q.trim().isNotEmpty) qp['q'] = q.trim();
    final query = qp.entries
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return "${ApiConfig.apiV1}/location-master/divisions?$query";
  }

  static String locationMasterDistricts({
    required int divisionId,
    String locale = 'en',
    int pageSize = 64,
    String? q,
  }) {
    final qp = <String, String>{
      'divisionId': '$divisionId',
      'locale': locale,
      'pageSize': '$pageSize',
    };
    if (q != null && q.trim().isNotEmpty) qp['q'] = q.trim();
    final query = qp.entries
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return "${ApiConfig.apiV1}/location-master/districts?$query";
  }

  static String locationMasterUpazilas({
    required int districtId,
    String locale = 'en',
    int pageSize = 64,
    String? q,
  }) {
    final qp = <String, String>{
      'districtId': '$districtId',
      'locale': locale,
      'pageSize': '$pageSize',
    };
    if (q != null && q.trim().isNotEmpty) qp['q'] = q.trim();
    final query = qp.entries
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return "${ApiConfig.apiV1}/location-master/upazilas?$query";
  }

  static String locationMasterUnions({
    required int upazilaId,
    String locale = 'en',
    int pageSize = 64,
    String? q,
  }) {
    final qp = <String, String>{
      'upazilaId': '$upazilaId',
      'locale': locale,
      'pageSize': '$pageSize',
    };
    if (q != null && q.trim().isNotEmpty) qp['q'] = q.trim();
    final query = qp.entries
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return "${ApiConfig.apiV1}/location-master/unions?$query";
  }

  // ---------- BD CITY CORPORATION LOCATIONS ----------
  static String bdCityCorporations({required int districtId}) =>
      "${ApiConfig.apiV1}/common/bd/city-corporations?districtId=$districtId";
  static String bdZones({required int cityCorporationId}) =>
      "${ApiConfig.apiV1}/common/bd/zones?cityCorporationId=$cityCorporationId";
  static String bdCcAreas({required int zoneId}) =>
      "${ApiConfig.apiV1}/common/bd/cc-areas?zoneId=$zoneId";


  // ---------- SHARE ----------
  /// Backend-generated share link + deep link + message
  static String shareLink({required String type, required int id}) =>
      "${ApiConfig.apiV1}/common/share-link?type=${Uri.encodeQueryComponent(type)}&id=$id";

  // ---------- SOCIAL ----------
  static String visitorProfile(int userId) =>
      "${ApiConfig.userApi}/$userId"; // GET
  static String visitorProfileByUsername(String username) =>
      "${ApiConfig.userApi}/by-username/${Uri.encodeComponent(username)}";
  static String socialStatus(int userId) =>
      "${ApiConfig.apiV1}/social/status/$userId";
  static String followUser(int userId) =>
      "${ApiConfig.apiV1}/social/follow/$userId";
  static String likeUserProfile(int userId) =>
      "${ApiConfig.apiV1}/social/like/$userId";
  static String friendRequestSend(int userId) =>
      "${ApiConfig.apiV1}/social/friend-request/$userId";
  static String friendRequestAccept(int requestId) =>
      "${ApiConfig.apiV1}/social/friend-request/$requestId/accept";
  static String friendRequestReject(int requestId) =>
      "${ApiConfig.apiV1}/social/friend-request/$requestId/reject";
  static String friendRequestCancel(int requestId) =>
      "${ApiConfig.apiV1}/social/friend-request/$requestId/cancel";

  // ---------- FUNDRAISING (PHASE A) ----------
  /// Fundraising feed with optional filters
  /// Supported params (server): limit, verified, category, location, sort
  static String fundraisingFeed({
    int limit = 50,
    bool? verified,
    String? category,
    String? location,
    String? sort,
  }) {
    final qp = <String, String>{'limit': '$limit'};
    if (verified != null) qp['verified'] = verified.toString();
    if (category != null && category.trim().isNotEmpty) {
      qp['category'] = category.trim();
    }
    if (location != null && location.trim().isNotEmpty) {
      qp['location'] = location.trim();
    }
    if (sort != null && sort.trim().isNotEmpty) qp['sort'] = sort.trim();
    final query = qp.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');
    return "${ApiConfig.apiV1}/fundraising/feed?$query";
  }

  // ✅ Unified withdraw hub needs: list only my campaigns
  static String fundraisingMyCampaigns({int limit = 100}) =>
      "${ApiConfig.apiV1}/fundraising/my/campaigns?limit=$limit";

  // Fundraising account (verification profile)
  static String fundraisingAccountMe() =>
      "${ApiConfig.apiV1}/fundraising/account/me";
  static String fundraisingAccountUpdate() =>
      "${ApiConfig.apiV1}/fundraising/account";
  static String fundraisingAccountSubmit() =>
      "${ApiConfig.apiV1}/fundraising/account/submit";
  static String fundraisingAccountDocuments() =>
      "${ApiConfig.apiV1}/fundraising/account/documents";
  static String fundraisingAccountDocumentDelete(int id) =>
      "${ApiConfig.apiV1}/fundraising/account/documents/$id";
  static String fundraisingCampaign(int id) =>
      "${ApiConfig.apiV1}/fundraising/campaigns/$id";
  static String fundraisingCreateCampaign() =>
      "${ApiConfig.apiV1}/fundraising/campaigns";
  static String fundraisingUpdateCampaign(int id) =>
      "${ApiConfig.apiV1}/fundraising/campaigns/$id";
  static String fundraisingDeleteCampaign(int id) =>
      "${ApiConfig.apiV1}/fundraising/campaigns/$id";
  static String fundraisingDonate(int id) =>
      "${ApiConfig.apiV1}/fundraising/campaigns/$id/donate";

  static String fundraisingCampaignDonations(int id, {int limit = 50, int? cursor}) {
    final q = <String, String>{'limit': '$limit'};
    if (cursor != null) q['cursor'] = '$cursor';
    final qs = q.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return "${ApiConfig.apiV1}/fundraising/campaigns/$id/donations?$qs";
  }

  static String fundraisingCampaignUpdates(int id, {int limit = 50, int? cursor}) {
    final q = <String, String>{'limit': '$limit'};
    if (cursor != null) q['cursor'] = '$cursor';
    final qs = q.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return "${ApiConfig.apiV1}/fundraising/campaigns/$id/updates?$qs";
  }

  static String fundraisingCreateUpdate(int campaignId) =>
      "${ApiConfig.apiV1}/fundraising/campaigns/$campaignId/updates";
  static String fundraisingUpdateUpdate(int updateId) =>
      "${ApiConfig.apiV1}/fundraising/updates/$updateId";
  static String fundraisingDeleteUpdate(int updateId) =>
      "${ApiConfig.apiV1}/fundraising/updates/$updateId";

  // ---------- Fundraising: Payout + Withdraw (Phase C) ----------
  static String fundraisingPayoutCatalog({bool all = false}) =>
      "${ApiConfig.apiV1}/fundraising/payout/catalog${all ? '?all=1' : ''}";

  static String fundraisingPayoutMethods() =>
      "${ApiConfig.apiV1}/fundraising/payout/methods";
  static String fundraisingPayoutMethodUpdate(int id) =>
      "${ApiConfig.apiV1}/fundraising/payout/methods/$id";

  static String fundraisingWithdrawRequests({int? campaignId, int limit = 50, int? cursor}) {
    final q = <String, String>{'limit': '$limit'};
    if (campaignId != null) q['campaignId'] = '$campaignId';
    if (cursor != null) q['cursor'] = '$cursor';
    final qs = q.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return "${ApiConfig.apiV1}/fundraising/withdraw/requests?$qs";
  }

  // ---------- WALLET (V1) ----------
  static String walletMe() => "${ApiConfig.apiV1}/wallet/me";

  static String walletTransactions({int limit = 20, int? cursor, String? type, String? status, String? sourceType}) {
    final q = <String, String>{'limit': '$limit'};
    if (cursor != null) q['cursor'] = '$cursor';
    if (type != null && type.trim().isNotEmpty) q['type'] = type.trim();
    if (status != null && status.trim().isNotEmpty) q['status'] = status.trim();
    if (sourceType != null && sourceType.trim().isNotEmpty) q['sourceType'] = sourceType.trim();
    final qs = q.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return "${ApiConfig.apiV1}/wallet/transactions?$qs";
  }


  static String walletWithdrawRequests({int limit = 20, int? cursor, String? status}) {
    final q = <String, String>{'limit': '$limit'};
    if (cursor != null) q['cursor'] = '$cursor';
    if (status != null && status.trim().isNotEmpty) q['status'] = status.trim();
    final qs = q.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return "${ApiConfig.apiV1}/wallet/withdraw/requests?$qs";
  }

  static String walletWithdrawCancel(int id) => "${ApiConfig.apiV1}/wallet/withdraw/requests/$id/cancel";

  static String walletWithdrawCreate() => "${ApiConfig.apiV1}/wallet/withdraw/requests";

  static String fundraisingCreateWithdrawRequest(int campaignId) =>
      "${ApiConfig.apiV1}/fundraising/campaigns/$campaignId/withdraw";

  // ---------- REPORTS ----------
  static String reportReasons({required String type}) =>
      "${ApiConfig.apiV1}/reports/reasons?type=${Uri.encodeQueryComponent(type)}";
  static String createReport() => "${ApiConfig.apiV1}/reports";

  // ---------- COMMENTS (Phase 1: Edit, Delete, Cursor) ----------
  /// PATCH /api/v1/posts/:postId/comments/:commentId — edit a comment
  static String postsCommentEdit({
    required int postId,
    required int commentId,
  }) => "${ApiConfig.apiV1}/posts/$postId/comments/$commentId";
  /// DELETE /api/v1/posts/:postId/comments/:commentId — delete a comment
  static String postsCommentDelete({
    required int postId,
    required int commentId,
  }) => "${ApiConfig.apiV1}/posts/$postId/comments/$commentId";

  // ---------- POST SHARE & VIEW (Phase 1) ----------
  /// POST /api/v1/posts/:postId/share — record a share
  static String postsShare({required int postId}) =>
      "${ApiConfig.apiV1}/posts/$postId/share";
  /// POST /api/v1/posts/:postId/view — record a view
  static String postsView({required int postId}) =>
      "${ApiConfig.apiV1}/posts/$postId/view";

  // ---------- BOOKMARKS ----------
  static String bookmarkPost({required int postId}) => "${ApiConfig.apiV1}/posts/$postId/bookmark";
  static String unbookmarkPost({required int postId}) => "${ApiConfig.apiV1}/posts/$postId/bookmark";
  static String bookmarkedPosts({int limit = 50}) => "${ApiConfig.apiV1}/posts/bookmarked?limit=$limit";

  // ---------- VACCINATION CAMPAIGN (2026) ----------
  static String campaignLinkSummary() => "${ApiConfig.apiV1}/campaign-link/summary";
  static String campaignLinkMyBookings() => "${ApiConfig.apiV1}/campaign-link/my-bookings";
  static String campaignLinkVaccinations() => "${ApiConfig.apiV1}/campaign-link/vaccinations";
  static String campaignLinkUpcoming() => "${ApiConfig.apiV1}/campaign-link/upcoming";
  static String campaignLinkBenefits({String? slug}) {
    if (slug != null && slug.trim().isNotEmpty) {
      return "${ApiConfig.apiV1}/campaign-link/benefits?slug=${Uri.encodeQueryComponent(slug.trim())}";
    }
    return "${ApiConfig.apiV1}/campaign-link/benefits";
  }
  static String campaignLinkImport() => "${ApiConfig.apiV1}/campaign-link/import";
  static String campaignLinkPet(int campaignPetId) =>
      "${ApiConfig.apiV1}/campaign-link/pet/$campaignPetId";
  static String campaignLinkClaimCertificate(String token) =>
      "${ApiConfig.apiV1}/campaign-link/certificate/$token/claim";
  static String campaignLinkCertificate(String token) =>
      "${ApiConfig.apiV1}/campaign-link/certificates/$token";
  static String campaignLinkCertificatePdf(String token) =>
      "${ApiConfig.apiV1}/campaign-link/certificates/$token/pdf";
  static String campaignPublicCampaigns() => "${ApiConfig.apiV1}/campaign/public/campaigns";
  static String campaignPublicCampaignBySlug(String slug) =>
      "${ApiConfig.apiV1}/campaign/public/campaigns/${Uri.encodeComponent(slug)}";
  static String campaignPublicCountdown(String slug) =>
      "${ApiConfig.apiV1}/campaign/public/campaigns/${Uri.encodeComponent(slug)}/countdown";
  static String campaignDiscoveryUpcoming({String window = 'this_week'}) =>
      "${ApiConfig.apiV1}/campaign/public/discovery/upcoming?window=${Uri.encodeQueryComponent(window)}";
  static String campaignDiscoveryLiveStats({String? slug}) {
    final qs = slug != null && slug.isNotEmpty
        ? '?slug=${Uri.encodeQueryComponent(slug)}'
        : '';
    return "${ApiConfig.apiV1}/campaign/public/discovery/live-stats$qs";
  }
  static String campaignPublicLocations(String slug, {bool onlyAvailable = true}) =>
      "${ApiConfig.apiV1}/campaign/public/campaigns/${Uri.encodeComponent(slug)}/locations?onlyAvailable=$onlyAvailable";
  static String campaignPublicLocationSlots(int locationId, {required String startDate, required String endDate}) =>
      "${ApiConfig.apiV1}/campaign/public/locations/$locationId/slots?startDate=${Uri.encodeQueryComponent(startDate)}&endDate=${Uri.encodeQueryComponent(endDate)}";
  static String campaignCheckoutInit() => "${ApiConfig.apiV1}/campaign/public/checkout/init";
  static String campaignCheckoutStatus(String checkoutId) =>
      "${ApiConfig.apiV1}/campaign/public/checkout/${Uri.encodeComponent(checkoutId)}/status";
  static String campaignCheckoutConfirmFree() =>
      "${ApiConfig.apiV1}/campaign/public/checkout/confirm-free";
  static String campaignCouponValidate() => "${ApiConfig.apiV1}/campaign/public/coupons/validate";
  static String campaignPublicVerify(String token) =>
      "${ApiConfig.apiV1}/campaign/public/verify/$token";
  static String campaignDhakaCityCorporations() =>
      "${ApiConfig.apiV1}/campaign/public/dhaka/city-corporations";
  static String campaignDhakaBookingAreas(String corpCode) =>
      "${ApiConfig.apiV1}/campaign/public/dhaka/city-corporations/${Uri.encodeComponent(corpCode)}/booking-areas";
  static String campaignBookingTickets(String bookingRef, {bool includeQr = true}) {
    final qr = includeQr ? '?qr=1' : '';
    return "${ApiConfig.apiV1}/campaign/public/bookings/${Uri.encodeComponent(bookingRef)}/tickets$qr";
  }
  static String campaignTicketQr(String ticketToken) =>
      "${ApiConfig.apiV1}/campaign/public/tickets/${Uri.encodeComponent(ticketToken)}/qr";

  // ---------- STORIES / MY DAY ----------
  /// GET /api/v1/stories/feed — story feed (own + friends)
  static String storiesFeed({int limit = 50}) =>
      "${ApiConfig.apiV1}/stories/feed?limit=$limit";
  /// POST /api/v1/stories — create a story
  static String storiesCreate() => "${ApiConfig.apiV1}/stories";
  /// POST /api/v1/stories/:id/view — mark as viewed
  static String storiesView(int storyId) =>
      "${ApiConfig.apiV1}/stories/$storyId/view";
  /// DELETE /api/v1/stories/:id — delete a story
  static String storiesDelete(int storyId) =>
      "${ApiConfig.apiV1}/stories/$storyId";
}