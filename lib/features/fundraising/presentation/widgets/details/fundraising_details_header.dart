import 'package:flutter/material.dart';

import 'package:furtail_app/core/constants/app_colors.dart';
import 'package:furtail_app/core/theme/app_typography.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/widgets/furtail_network_image.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_models.dart';
import 'package:furtail_app/features/fundraising/presentation/utils/fundraising_time_ago.dart';

class FundraisingDetailsHeader extends StatelessWidget {
  final FundraisingAuthor author;
  final DateTime createdAt;
  final bool isOwner;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onReport;
  final VoidCallback onEdit;
  final VoidCallback onPostUpdate;
  final VoidCallback onDelete;
  final VoidCallback? onPayoutMethods;
  final VoidCallback? onWithdraw;

  const FundraisingDetailsHeader({
    super.key,
    required this.author,
    required this.createdAt,
    required this.isOwner,
    required this.onBack,
    required this.onShare,
    required this.onReport,
    required this.onEdit,
    required this.onPostUpdate,
    required this.onDelete,
    this.onPayoutMethods,
    this.onWithdraw,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
          FurtailNetworkAvatar(
            imageUrl: author.avatarUrl,
            displayName: author.displayName,
            radius: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  author.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.menuTitle(context),
                ),
                Text(
                  fundraisingTimeAgo(createdAt),
                  style: AppTypography.caption(context).copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share_outlined),
            onPressed: onShare,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'update') onPostUpdate();
              if (v == 'payout_methods') onPayoutMethods?.call();
              if (v == 'withdraw') onWithdraw?.call();
              if (v == 'delete') onDelete();
              if (v == 'report') onReport();
            },
            itemBuilder: (_) => [
              if (isOwner)
                const PopupMenuItem(value: 'edit', child: Text('Edit Post')),
              if (isOwner)
                const PopupMenuItem(
                  value: 'update',
                  child: Text('Post Update'),
                ),
              if (isOwner && onPayoutMethods != null)
                const PopupMenuItem(
                  value: 'payout_methods',
                  child: Text('Payout Methods'),
                ),
              if (isOwner && onWithdraw != null)
                const PopupMenuItem(
                  value: 'withdraw',
                  child: Text('Withdraw Request'),
                ),
              if (isOwner)
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete Post'),
                ),
              const PopupMenuItem(value: 'report', child: Text('Report')),
            ],
          ),
        ],
      ),
    );
  }
}
