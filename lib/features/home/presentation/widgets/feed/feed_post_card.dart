import 'package:bpa_app/core/theme/app_typography.dart';
import 'package:bpa_app/core/theme/theme_extensions.dart';
import 'package:bpa_app/core/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bpa_app/core/constants/app_colors.dart';
import 'package:bpa_app/core/media/feed_video_player.dart';
import 'package:bpa_app/core/media/fullscreen_gallery_viewer.dart';
import 'package:bpa_app/core/services/share_service.dart';
import 'package:bpa_app/core/widgets/bpa_network_image.dart';
import 'package:bpa_app/core/widgets/fit_width_media.dart';
import 'package:bpa_app/app/router/app_routes.dart';

import 'package:bpa_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:bpa_app/features/posts/data/models/post_model.dart';
import 'package:bpa_app/features/posts/presentation/screens/post_details_screen.dart';
import 'package:bpa_app/features/posts/presentation/widgets/comments_sheet.dart';
import 'package:bpa_app/features/posts/presentation/widgets/report_bottom_sheet.dart';

import 'package:bpa_app/features/legacy/presentation/screens/edit_post_screen.dart';
import 'package:bpa_app/features/legacy/presentation/screens/donation_screen.dart';
import 'package:bpa_app/features/fundraising/presentation/screens/fundraising_details_screen.dart';

class PostCard extends StatefulWidget {
  final PostModel post;
  final int? meId; // ✅ current user id here
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
      );
    });
  }

  Future<void> _toggleLike() async {
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
              );
            });
          },
        ),
      ),
    );
  }

  void _openReport() {
    ReportBottomSheet.showPost(context, postId: _post.id);
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

  @override
  Widget build(BuildContext context) {
    final post = _post;
    final isVerified = post.author.name.toLowerCase().contains('bpa');

    final meId = widget.meId;
    final canEdit = meId != null && post.author.id == meId;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 6,
            ),
            leading: BpaNetworkAvatar(
              imageUrl: post.author.avatarUrl,
              displayName: post.author.name,
              radius: 20,
              backgroundColor: const Color(0xFFEFEFEF),
              foregroundColor: Colors.black45,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    post.author.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                if (isVerified) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.verified,
                    size: 16,
                    color: context.colorScheme.primary,
                  ),
                ],
              ],
            ),
            subtitle: Text(
              _timeAgo(post.createdAt),
              style: context.appText.bodySmall!.copyWith(color: Colors.black54),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') {
                  // Extra safety even though menu only shows for canEdit
                  if (!canEdit) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('You can only edit your own post.'),
                      ),
                    );
                    return;
                  }

                  Navigator.pushNamed(
                    context,
                    AppRoutes.postEdit,
                    arguments: {'post': post},
                  ).then((updated) {
                    if (updated != null) widget.onNeedRefresh?.call();
                  });
                }

                if (v == 'delete') {
                  if (!canEdit) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('You can only delete your own post.'),
                      ),
                    );
                    return;
                  }

                  showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete post?'),
                      content: const Text(
                        'This will remove the post from the feed.',
                      ),
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
                  ).then((ok) async {
                    if (ok != true) return;
                    try {
                      await PostsRemoteDs().deletePost(postId: post.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Post deleted ✅')),
                      );
                      widget.onNeedRefresh?.call();
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().replaceAll('Exception: ', ''),
                          ),
                        ),
                      );
                    }
                  });
                }

                if (v == 'report') _openReport();
              },
              itemBuilder: (_) => [
                if (canEdit)
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (canEdit)
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                const PopupMenuItem(value: 'report', child: Text('Report')),
              ],
            ),
            onTap: () {
              Navigator.pushNamed(
                context,
                AppRoutes.visitorProfile,
                arguments: {'userId': post.author.id},
              );
            },
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
                if ((post.caption ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: _ReadMoreText(
                      text: post.caption!,
                      trimLines: 3,
                      style: context.appText.bodyLarge!.copyWith(height: 1.35),
                    ),
                  ),
                if (post.media.isNotEmpty) _MediaBlock(post: post),

                if (post.category.toUpperCase() == 'FUNDRAISING')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                    child: _FundraisingEmbedBlock(post: post),
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                  child: Text(
                    '${post.likeCount} Paws · ${post.commentCount} comments · 0 shares',
                    style: context.appText.bodySmall!.copyWith(color: Colors.black54),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ReactionButton(
                          icon: post.isLikedByMe
                              ? Icons.pets
                              : Icons.pets_outlined,
                          label: 'Paw',
                          selected: post.isLikedByMe,
                          onTap: _toggleLike,
                        ),
                      ),
                      Expanded(
                        child: _ReactionButton(
                          icon: Icons.comment_outlined,
                          label: 'Comment',
                          onTap: _openComments,
                        ),
                      ),
                      Expanded(
                        child: _ReactionButton(
                          icon: Icons.share_outlined,
                          label: 'Share',
                          onTap: () {
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
                      ),
                    ],
                  ),
                ),

                Builder(
                  builder: (context) {
                    final recent = _safeRecentComments(post);
                    if (recent.isEmpty) return const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...recent.take(3).map((c) {
                            final author = _commentAuthor(c);
                            final text = _commentText(c);
                            final replies = _replyCount(c);

                            if (text.isEmpty) return const SizedBox.shrink();

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: RichText(
                                text: TextSpan(
                                  style: context.appText.bodySmall!.copyWith(color: Colors.black87),
                                  children: [
                                    TextSpan(
                                      text: '$author  ',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    TextSpan(text: text),
                                    if (replies > 0)
                                      TextSpan(
                                        text: '  ·  $replies replies',
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _openComments,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('View all comments'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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

  Widget _donorRow(BuildContext context, {required String title, required dynamic donor}) {
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
          BpaNetworkAvatar(
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
                  style: context.appText.labelLarge!.copyWith(fontWeight: FontWeight.w800),
                ),
                if (when.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    when,
                    style: context.appText.labelMedium!.copyWith(color: Colors.black45),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            amount > 0 ? '৳${_money(amount)}' : '',
            style: const TextStyle(fontWeight: FontWeight.w900),
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
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (embed?.isAccountVerified == true) ...[
                const SizedBox(width: 8),
                Icon(Icons.verified, size: 16, color: context.colorScheme.primary),
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
            _donorRow(context,
              title: 'Top donor',
              donor:
                  _embedDonor(embed, 'top') ??
                  (donors.isNotEmpty ? donors.first : null),
            ),
            const SizedBox(height: 6),
            _donorRow(context,
              title: 'First donor',
              donor:
                  _embedDonor(embed, 'first') ??
                  (donors.length > 1
                      ? donors[1]
                      : (donors.isNotEmpty ? donors.first : null)),
            ),
            const SizedBox(height: 6),
            _donorRow(context,
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
    // Card padding + safe margin বাদ দিয়ে width
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
              maxLines: 1, // 🔒 এক লাইনে
              overflow: TextOverflow.ellipsis, // … দেখাবে
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

class _ReactionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _ReactionButton({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? context.colorScheme.primary : Colors.black54;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
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
    final images = list.where((m) => m.type.toUpperCase() == 'IMAGE').toList();
    final files = list
        .where((m) => m.type.toUpperCase() == 'FILE')
        .where((m) => !_looksLikeVideoUrl(m.url))
        .toList();

    if (post.isVideo) {
      final video = list.firstWhere(
        (m) => m.type.toUpperCase() == 'VIDEO',
        orElse: () => list.first,
      );
      return FeedVideoPlayer(
        url: video.url,
        visibilityKey: 'post-${post.id}',
        startMuted: true,
        enableAutoplay: true,
      );
    }

    Widget? imageBlock;
    if (images.length == 1) {
      final urls = images.map((e) => e.url).toList();
      final tagPrefix = 'post-${post.id}-img';
      imageBlock = InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FullscreenGalleryViewer(
                urls: urls,
                initialIndex: 0,
                heroTagPrefix: tagPrefix,
              ),
            ),
          );
        },
        child: Hero(
          tag: '$tagPrefix-0',
          child: FitWidthNetworkImage(url: urls.first),
        ),
      );
    } else if (images.length > 1) {
      final urls = images.map((e) => e.url).toList();
      final tagPrefix = 'post-${post.id}-img';
      final count = urls.length.clamp(2, 4);
      imageBlock = GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: count,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          childAspectRatio: 1,
        ),
        itemBuilder: (itemContext, i) {
          final isLastVisible = i == 3 && urls.length > 4;
          final remaining = urls.length - 4;
          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullscreenGalleryViewer(
                    urls: urls,
                    initialIndex: i,
                    heroTagPrefix: tagPrefix,
                  ),
                ),
              );
            },
            child: Hero(
              tag: '$tagPrefix-$i',
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: isLastVisible ? 0.55 : 1,
                    child: CachedNetworkImage(
                      imageUrl: urls[i],
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (isLastVisible)
                    Container(
                      color: Colors.black.withOpacity(0.15),
                      alignment: Alignment.center,
                      child: Text(
                        '+$remaining',
                        style: itemContext.appText.displayMedium!.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
            ),
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
                color: Colors.grey.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withOpacity(0.08)),
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
        if (imageBlock != null) imageBlock,
        if (imageBlock == null && fileBlock != null)
          Container(
            height: 140,
            color: Colors.black.withOpacity(0.03),
            child: const Center(
              child: Icon(
                Icons.insert_drive_file_outlined,
                size: 48,
                color: Colors.black45,
              ),
            ),
          ),
        if (fileBlock != null) fileBlock,
      ],
    );
  }
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
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
      ellipsis: '…',
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
