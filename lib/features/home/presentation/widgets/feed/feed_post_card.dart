import 'package:furtail_app/core/theme/app_typography.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:furtail_app/core/constants/app_colors.dart';
import 'package:furtail_app/features/posts/presentation/widgets/post_media_grid.dart';
import 'package:furtail_app/core/services/share_service.dart';
import 'package:furtail_app/core/widgets/furtail_network_image.dart';
import 'package:furtail_app/app/router/app_routes.dart';
import 'package:furtail_app/core/navigation/profile_navigation.dart';
import 'package:furtail_app/features/settings/data/datasources/settings_local_datasource.dart';
import 'package:furtail_app/features/settings/data/models/blocked_user.dart';

import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:furtail_app/features/posts/data/models/post_model.dart';
import 'package:furtail_app/features/posts/presentation/screens/post_details_screen.dart';
import 'package:furtail_app/features/posts/presentation/widgets/comments_sheet.dart';
import 'package:furtail_app/features/posts/presentation/widgets/post_action_sheet.dart';

import 'package:furtail_app/features/posts/presentation/widgets/post_background_style.dart';
import 'package:furtail_app/features/posts/presentation/widgets/post_card_header.dart';
import 'package:furtail_app/features/posts/presentation/widgets/post_card_actions.dart';
import 'package:furtail_app/features/posts/presentation/widgets/post_card_comment_preview.dart';

class PostCard extends StatefulWidget {
  final PostModel post;
  final int? meId; // âœ… current user id here
  final VoidCallback? onNeedRefresh;

  const PostCard({
    super.key,
    required this.post,
    this.meId,
    this.onNeedRefresh,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final _ds = PostsRemoteDs();
  late PostModel _post;
  bool _hidden = false;
  bool _likeBusy = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  void _patchCounts(Map<String, dynamic> data) {
    final likeCount = (data['likeCount'] as num?)?.toInt() ?? _post.likeCount;
    final commentCount =
        (data['commentCount'] as num?)?.toInt() ?? _post.commentCount;
    final isLikedByMe = (data['isLikedByMe'] as bool?) ?? _post.isLikedByMe;

    setState(() {
      _post = PostModel(
        id: _post.id,
        type: _post.type,
        category: _post.category,
        fundraisingCampaignId: _post.fundraisingCampaignId,
        fundraisingEmbed: _post.fundraisingEmbed,
        caption: _post.caption,
        context: _post.context,
        createdAt: _post.createdAt,
        author: _post.author,
        media: _post.media,
        likeCount: likeCount,
        commentCount: commentCount,
        isLikedByMe: isLikedByMe,
        isBookmarkedByMe: _post.isBookmarkedByMe,
        privacy: _post.privacy,
        backgroundStyle: _post.backgroundStyle,
        feelingId: _post.feelingId,
        feelingLabel: _post.feelingLabel,
        feelingEmoji: _post.feelingEmoji,
        activityId: _post.activityId,
        activityLabel: _post.activityLabel,
        activityEmoji: _post.activityEmoji,
        shareCount: _post.shareCount,
        viewCount: _post.viewCount,
        isReportedByMe: _post.isReportedByMe,
        isFollowingAuthor: _post.isFollowingAuthor,
        sponsoredLabel: _post.sponsoredLabel,
        locationTag: _post.locationTag,
        postType: _post.postType,
        lostPetName: _post.lostPetName,
        lostPetLocation: _post.lostPetLocation,
        lostPetContactVisible: _post.lostPetContactVisible,
        taggedPetIds: _post.taggedPetIds,
        taggedPets: _post.taggedPets,
        songTitle: _post.songTitle,
        songArtist: _post.songArtist,
        songStartMs: _post.songStartMs,
        songDurationMs: _post.songDurationMs,
      );
    });
  }

  Future<void> _toggleLike() async {
    if (_likeBusy) return;
    setState(() => _likeBusy = true);
    final currentlyLiked = _post.isLikedByMe;
    try {
      final res = currentlyLiked
          ? await _ds.unlikePost(_post.id)
          : await _ds.likePost(_post.id);
      _patchCounts(res);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Like failed: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _likeBusy = false);
    }
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: CommentsSheet(
          postId: _post.id,
          onCountChanged: (n) {
            setState(() {
              _post = PostModel(
                id: _post.id,
                type: _post.type,
                caption: _post.caption,
                context: _post.context,
                createdAt: _post.createdAt,
                author: _post.author,
                media: _post.media,
                likeCount: _post.likeCount,
                commentCount: n,
                isLikedByMe: _post.isLikedByMe,
                category: _post.category,
                fundraisingCampaignId: _post.fundraisingCampaignId,
                fundraisingEmbed: _post.fundraisingEmbed,
                isBookmarkedByMe: _post.isBookmarkedByMe,
                privacy: _post.privacy,
                backgroundStyle: _post.backgroundStyle,
                feelingId: _post.feelingId,
                feelingLabel: _post.feelingLabel,
                feelingEmoji: _post.feelingEmoji,
                activityId: _post.activityId,
                activityLabel: _post.activityLabel,
                activityEmoji: _post.activityEmoji,
                shareCount: _post.shareCount,
                viewCount: _post.viewCount,
                isReportedByMe: _post.isReportedByMe,
                isFollowingAuthor: _post.isFollowingAuthor,
                sponsoredLabel: _post.sponsoredLabel,
                locationTag: _post.locationTag,
                postType: _post.postType,
                lostPetName: _post.lostPetName,
                lostPetLocation: _post.lostPetLocation,
                lostPetContactVisible: _post.lostPetContactVisible,
                taggedPetIds: _post.taggedPetIds,
                taggedPets: _post.taggedPets,
                songTitle: _post.songTitle,
                songArtist: _post.songArtist,
                songStartMs: _post.songStartMs,
                songDurationMs: _post.songDurationMs,
              );
            });
          },
        ),
      ),
    );
  }

  Future<void> _openEdit(PostModel post) async {
    final updated = await Navigator.pushNamed(
      context,
      AppRoutes.postEdit,
      arguments: {'post': post},
    );
    if (updated != null) widget.onNeedRefresh?.call();
  }

  Future<void> _deletePost(PostModel post) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This will remove the post from the feed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await PostsRemoteDs().deletePost(postId: post.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted âœ…')),
      );
      widget.onNeedRefresh?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  // ---- Comment preview helpers (runtime-safe) ----
  List<dynamic> _safeRecentComments(PostModel post) {
    try {
      final p = post as dynamic;
      final v =
          p.recentComments ??
          p.last3Comments ??
          p.commentsPreview ??
          p.latestComments;
      if (v is List) return v.cast<dynamic>();
    } catch (_) {}
    return const <dynamic>[];
  }

  String _commentAuthor(dynamic c) {
    try {
      final a = c?.author;
      final name = (a?.name ?? a?.fullName ?? c?.authorName ?? '')
          .toString()
          .trim();
      return name.isEmpty ? 'User' : name;
    } catch (_) {
      return 'User';
    }
  }

  String _commentText(dynamic c) {
    try {
      final t = (c?.text ?? c?.content ?? c?.message ?? '').toString().trim();
      return t;
    } catch (_) {
      return '';
    }
  }

  int _replyCount(dynamic c) {
    try {
      final v =
          c?.replyCount ??
          c?.repliesCount ??
          (c?.replies is List ? (c.replies as List).length : 0) ??
          0;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _blockUser() async {
    final post = _post;
    final authorId = post.author.id;
    if (authorId <= 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block user?'),
        content: Text(
          'Posts from ${post.author.name} will no longer appear in your feed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await SettingsLocalDatasource().blockUser(
      BlockedUser(
        userId: authorId,
        displayName: post.author.name,
        blockedAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    setState(() => _hidden = true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${post.author.name} blocked')));
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();

    final post = _post;
    final isVerified = post.author.name.toLowerCase().contains('furtail');

    final meId = widget.meId;
    final canEdit = meId != null && post.author.id == meId;

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PostCardHeader(
            post: _post,
            isVerified: isVerified,
            onProfileTap: () {
              final uid = post.author.id;
              if (uid <= 0) return;
              ProfileNavigation.openUserProfile(context, uid);
            },
            onMoreMenu: () => PostActionSheet.show(
              context,
              post: _post,
              isOwn: canEdit,
              onEdit: canEdit ? () => _openEdit(post) : null,
              onDelete: canEdit ? () => _deletePost(post) : null,
              onHide: canEdit ? null : () => setState(() => _hidden = true),
              onBlock: canEdit ? null : _blockUser,
              onPostChanged: (updated) {
                if (!mounted) return;
                setState(() => _post = updated);
              },
            ),
          ),
          InkWell(
            onTap: () {
              final cid = post.fundraisingCampaignId;
              final isFundraising =
                  post.category.toUpperCase() == 'FUNDRAISING';
              if (isFundraising && cid != null) {
                Navigator.pushNamed(
                  context,
                  AppRoutes.fundraisingDetails,
                  arguments: {'campaignId': cid},
                );
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PostDetailsScreen(post: post),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // â”€â”€ Post type badge â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                if (_shouldShowPostTypeBadge(post.postType))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                    child: _buildPostTypeBadge(post.postType!),
                  ),

                // â”€â”€ Lost Pet Alert highlight â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                if (post.postType == 'LOST_PET')
                  _buildLostPetDetails(post),

                if ((post.caption ?? '').isNotEmpty)
                  () {
                    if (_isBackgroundTextPost(post)) {
                      final style = PostBackgroundStyle.find(post.backgroundStyle);
                      return ShortPostBackgroundBox(
                        caption: cleanPostBodyForDisplay(post.caption!),
                        style: style,
                        fullWidth: true,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PostDetailsScreen(post: post),
                            ),
                          );
                        },
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: _ReadMoreText(
                        text: cleanPostBodyForDisplay(post.caption!),
                        trimLines: 3,
                        style: context.appText.bodyLarge!.copyWith(
                          height: 1.35,
                        ),
                      ),
                    );
                  }(),
                if (post.media.isNotEmpty) _MediaBlock(post: post),

                if (post.category.toUpperCase() == 'FUNDRAISING')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                    child: _FundraisingEmbedBlock(post: post),
                  ),

                PostCardActions(
                  post: post,
                  onLike: _toggleLike,
                  onOpenComments: _openComments,
                  onShare: () {
                    final fundraisingId = post.fundraisingCampaignId;
                    if (fundraisingId != null) {
                      ShareService.share(
                        context,
                        type: 'fundraising',
                        id: fundraisingId,
                      );
                    } else {
                      ShareService.share(
                        context,
                        type: 'post',
                        id: post.id,
                      );
                    }
                  },
                ),

                PostCardCommentPreview(
                  recentComments: _safeRecentComments(post),
                  onViewAll: _openComments,
                  commentAuthor: _commentAuthor,
                  commentText: _commentText,
                  replyCount: _replyCount,
                ),

                // Donate CTA is now inside _FundraisingEmbedBlock to keep
                // fundraising posts behaving like other post types.
              ],
            ),
          ),
          const Divider(thickness: 1, color: Color(0xFFEEEEEE), height: 1),
        ],
      ),
    );
  }

  // â”€â”€ Post type badge â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  bool _shouldShowPostTypeBadge(String? type) {
    if (type == null) return false;
    return type != 'GENERAL' && type != 'GENERAL_POST';
  }

  bool _isBackgroundTextPost(PostModel post) {
    final caption = post.caption;
    if (caption == null || caption.isEmpty) return false;

    final styleId = post.backgroundStyle;
    return post.media.isEmpty &&
        caption.length <= 220 &&
        styleId != null &&
        styleId != 'none';
  }

  Widget _buildPostTypeBadge(String type) {
    IconData icon;
    Color color;
    String label;
    switch (type) {
      case 'HEALTH_UPDATE':
        icon = Icons.favorite_outline; color = const Color(0xFFE91E63); label = 'Health Update'; break;
      case 'VACCINATION':
        icon = Icons.vaccines_outlined; color = const Color(0xFF4CAF50); label = 'Vaccination'; break;
      case 'LOST_PET':
        icon = Icons.report_problem_rounded; color = const Color(0xFFF44336); label = 'Lost Pet Alert'; break;
      case 'ADOPTION':
        icon = Icons.pets_rounded; color = const Color(0xFF9C27B0); label = 'Adoption'; break;
      case 'SERVICE_REVIEW':
        icon = Icons.star_outline; color = const Color(0xFFFF9800); label = 'Service Review'; break;
      default:
        return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  // â”€â”€ Lost Pet details â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildLostPetDetails(PostModel post) {
    final hasName = (post.lostPetName ?? '').isNotEmpty;
    final hasLocation = (post.lostPetLocation ?? '').isNotEmpty;
    if (!hasName && !hasLocation) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasName)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.pets, size: 16, color: Colors.red.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      post.lostPetName!,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red.shade800),
                    ),
                  ),
                ],
              ),
            ),
          if (hasLocation)
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: Colors.red.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Last seen: ${post.lostPetLocation!}',
                    style: TextStyle(fontSize: 13, color: Colors.red.shade700),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// =============================
// Fundraising summary block (for home feed fundraising posts)
// =============================
// =============================
// Fundraising summary block (for home feed fundraising posts)
// =============================
class _FundraisingEmbedBlock extends StatelessWidget {
  final PostModel post;
  const _FundraisingEmbedBlock({required this.post});

  String _money(int v) => v.toString(); // keep simple; you can localize later

  // ---- Donor helpers (runtime-safe: works even if fields vary) ----
  String _donorName(dynamic d) {
    try {
      final n = (d?.name ?? d?.fullName ?? '').toString().trim();
      return n.isEmpty ? 'Donor' : n;
    } catch (_) {
      return 'Donor';
    }
  }

  int _donorAmount(dynamic d) {
    try {
      final v =
          d?.amount ?? d?.donationAmount ?? d?.totalAmount ?? d?.value ?? 0;
      if (v is int) return v;
      if (v is double) return v.round();
      return int.tryParse(v.toString()) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  String? _donorAvatar(dynamic d) {
    try {
      final u = (d?.photoUrl ?? d?.avatarUrl ?? d?.imageUrl ?? '')
          .toString()
          .trim();
      return u.isEmpty ? null : u;
    } catch (_) {
      return null;
    }
  }

  DateTime? _donorWhen(dynamic d) {
    try {
      final v = d?.donatedAt ?? d?.createdAt ?? d?.at ?? d?.time;
      if (v is DateTime) return v;
      final s = v?.toString();
      if (s == null || s.trim().isEmpty) return null;
      return DateTime.tryParse(s);
    } catch (_) {
      return null;
    }
  }

  String _whenText(DateTime? dt) {
    if (dt == null) return '';
    // Simple readable format without intl dependency.
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  dynamic _embedDonor(dynamic embed, String key) {
    try {
      if (key == 'top') return embed?.topDonor ?? embed?.highestDonor;
      if (key == 'first') return embed?.firstDonor;
      if (key == 'last') return embed?.lastDonor ?? embed?.latestDonor;
      return null;
    } catch (_) {
      return null;
    }
  }

  Widget _donorRow(
    BuildContext context, {
    required String title,
    required dynamic donor,
  }) {
    final name = _donorName(donor);
    final amount = _donorAmount(donor);
    final when = _whenText(_donorWhen(donor));
    final avatar = _donorAvatar(donor);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.bpaCardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.outlineColor),
      ),
      child: Row(
        children: [
          FurtailNetworkAvatar(
            imageUrl: avatar,
            displayName: name,
            radius: 16,
            backgroundColor: context.colorScheme.surfaceContainerHighest,
            foregroundColor: context.mutedTextColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.caption(context).copyWith(
                    color: context.mutedTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.appText.labelLarge!.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (when.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    when,
                    style: context.appText.labelMedium!.copyWith(
                      color: Colors.black45,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            amount > 0 ? 'à§³${_money(amount)}' : '',
            style: context.appText.bodyLarge!.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final embed = post.fundraisingEmbed;
    final cid = post.fundraisingCampaignId;

    final title = (embed?.title?.trim().isNotEmpty ?? false)
        ? embed!.title!.trim()
        : 'Fundraising Campaign';

    final target = embed?.safeTarget ?? 0;
    final raised = embed?.safeRaised ?? 0;
    final hasAmounts = target > 0 || raised > 0;
    final progress = embed?.progress ?? 0;

    final remainingDays = embed?.remainingDays;
    final deadlineText = (remainingDays == null)
        ? null
        : (remainingDays <= 0 ? 'Ending today' : '$remainingDays days left');

    // Build locationText from DB-backed fields if available (district + area),
    // fallback to API-provided embed.locationText.
    String locationText = (embed?.locationText ?? '').toString().trim();
    if (locationText.isEmpty) {
      try {
        final e = embed as dynamic;
        final district =
            (e?.districtNameBn ?? e?.districtNameEn ?? e?.districtName ?? '')
                .toString()
                .trim();
        final area =
            (e?.areaNameBn ??
                    e?.areaNameEn ??
                    e?.areaName ??
                    e?.cityAreaNameBn ??
                    e?.cityAreaNameEn ??
                    e?.cityAreaName ??
                    '')
                .toString()
                .trim();
        if (district.isNotEmpty && area.isNotEmpty) {
          locationText = '$district, $area';
        } else if (district.isNotEmpty) {
          locationText = district;
        } else if (area.isNotEmpty) {
          locationText = area;
        }
      } catch (_) {}
    }

    final donors = embed?.last3Donors ?? const [];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3ECFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.appText.titleMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (embed?.isAccountVerified == true) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.verified,
                  size: 16,
                  color: context.colorScheme.primary,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Category + Deadline (wrap)
          if (embed?.category != null || deadlineText != null)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if ((embed?.category ?? '').trim().isNotEmpty)
                  _MiniPill(label: embed!.category!.trim()),
                if (deadlineText != null)
                  _MiniPill(label: deadlineText, icon: Icons.timer_outlined),
              ],
            ),

          // Location (single line, overflow-safe)
          if (locationText.isNotEmpty) ...[
            const SizedBox(height: 6),
            _MiniPill(
              label: embed!.locationText!.trim(),
              icon: Icons.place_outlined,
            ),
          ],

          if (hasAmounts) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFEAF0FF),
            ),
            const SizedBox(height: 6),
            Text(
              '${_money(raised)} raised / ${_money(target)} target',
              style: context.appText.bodySmall!.copyWith(color: Colors.black54),
            ),
          ],

          if (donors.isNotEmpty ||
              _embedDonor(embed, 'top') != null ||
              _embedDonor(embed, 'first') != null ||
              _embedDonor(embed, 'last') != null) ...[
            const SizedBox(height: 10),
            Text(
              'Donations',
              style: context.appText.labelMedium!.copyWith(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),

            // Priority: API-provided donors (top/first/last). Fallback: last3Donors list.
            _donorRow(
              context,
              title: 'Top donor',
              donor:
                  _embedDonor(embed, 'top') ??
                  (donors.isNotEmpty ? donors.first : null),
            ),
            const SizedBox(height: 6),
            _donorRow(
              context,
              title: 'First donor',
              donor:
                  _embedDonor(embed, 'first') ??
                  (donors.length > 1
                      ? donors[1]
                      : (donors.isNotEmpty ? donors.first : null)),
            ),
            const SizedBox(height: 6),
            _donorRow(
              context,
              title: 'Latest donor',
              donor:
                  _embedDonor(embed, 'last') ??
                  (donors.isNotEmpty ? donors.last : null),
            ),
          ],

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                if (cid != null) {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.fundraisingDetails,
                    arguments: {'campaignId': cid},
                  );
                  return;
                }
                Navigator.pushNamed(context, AppRoutes.donation);
              },
              icon: const Icon(Icons.volunteer_activism_outlined),
              label: const Text('Donate Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.donateBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  const _MiniPill({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    // Card padding + safe margin à¦¬à¦¾à¦¦ à¦¦à¦¿à§Ÿà§‡ width
    final maxWidth = MediaQuery.of(context).size.width * 0.70;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.black54),
            const SizedBox(width: 6),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Text(
              label,
              maxLines: 1, // ðŸ”’ à¦à¦• à¦²à¦¾à¦‡à¦¨à§‡
              overflow: TextOverflow.ellipsis, // â€¦ à¦¦à§‡à¦–à¦¾à¦¬à§‡
              softWrap: false,
              style: context.appText.labelMedium!.copyWith(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaBlock extends StatelessWidget {
  final PostModel post;
  const _MediaBlock({required this.post});

  bool _looksLikeVideoUrl(String url) {
    final u = url.toLowerCase();
    return RegExp(r'\.(mp4|mov|m4v|webm|mkv|avi)(\?|$)').hasMatch(u);
  }

  @override
  Widget build(BuildContext context) {
    final list = post.media;
    final mediaList = list.where((m) => m.type.toUpperCase() == 'IMAGE' || m.type.toUpperCase() == 'VIDEO').toList();
    final files = list
        .where((m) => m.type.toUpperCase() == 'FILE')
        .where((m) => !_looksLikeVideoUrl(m.url))
        .toList();

    Widget? mediaGrid;
    if (mediaList.isNotEmpty) {
      mediaGrid = PostMediaGrid(
        media: mediaList,
        onTap: (index) {
          Navigator.pushNamed(
            context,
            AppRoutes.postMediaDetail,
            arguments: {
              'post': post,
              'initialIndex': index,
            },
          );
        },
      );
    }

    Widget? fileBlock;
    if (files.isNotEmpty) {
      fileBlock = Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Column(
          children: files.take(6).map((f) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.attach_file,
                    size: 18,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.appText.bodyMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      final uri = Uri.tryParse(f.url);
                      if (uri == null) return;
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    icon: const Icon(Icons.open_in_new, size: 18),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mediaGrid != null) ...[mediaGrid],
        if (mediaGrid == null && fileBlock != null)
          Container(
            height: 140,
            color: Colors.black.withValues(alpha: 0.03),
            child: const Center(
              child: Icon(
                Icons.insert_drive_file_outlined,
                size: 48,
                color: Colors.black45,
              ),
            ),
          ),
        if (fileBlock != null) ...[fileBlock],
      ],
    );
  }
}

/// Read-more helper for any long text in posts.
/// Requirement: show 2-3 lines, then allow expanding to full.
class _ReadMoreText extends StatefulWidget {
  final String text;
  final int trimLines;
  final TextStyle? style;

  const _ReadMoreText({required this.text, this.trimLines = 3, this.style});

  @override
  State<_ReadMoreText> createState() => _ReadMoreTextState();
}

class _ReadMoreTextState extends State<_ReadMoreText> {
  bool _expanded = false;
  bool _overflow = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(covariant _ReadMoreText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.trimLines != widget.trimLines) {
      _expanded = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }
  }

  void _measure() {
    if (!mounted) return;
    final maxW = context.size?.width;
    if (maxW == null || maxW <= 0) return;

    final tp = TextPainter(
      text: TextSpan(
        text: widget.text,
        style: widget.style ?? DefaultTextStyle.of(context).style,
      ),
      maxLines: widget.trimLines,
      textDirection: TextDirection.ltr,
      ellipsis: 'â€¦',
    )..layout(maxWidth: maxW);

    final didOverflow = tp.didExceedMaxLines;
    if (didOverflow != _overflow) {
      setState(() => _overflow = didOverflow);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = widget.style ?? DefaultTextStyle.of(context).style;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          style: textStyle,
          maxLines: _expanded ? null : widget.trimLines,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        if (_overflow)
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _expanded ? 'Read less' : 'Read more',
                style: textStyle.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    );
  }
}


