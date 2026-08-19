import 'package:flutter/material.dart';
import 'package:furtail_app/core/widgets/reaction_control.dart';
import 'package:furtail_app/features/posts/data/models/post_model.dart';

void showReactionListSheet(BuildContext context, PostModel post) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: ReactionListSheet(post: post),
    ),
  );
}

class ReactionListSheet extends StatefulWidget {
  final PostModel post;

  const ReactionListSheet({super.key, required this.post});

  @override
  State<ReactionListSheet> createState() => _ReactionListSheetState();
}

class _ReactionListSheetState extends State<ReactionListSheet> {
  String _activeTab = 'ALL';
  List<PostAuthorModel> _reactors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReactors();
  }

  Future<void> _fetchReactors() async {
    setState(() => _isLoading = true);
    // In a real implementation this hits the API. For now, we mock the
    // topReactors + some delay.
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _reactors = widget.post.topReactors;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.post.reactionSummary;
    final totalCount = widget.post.totalReactionCount > 0
        ? widget.post.totalReactionCount
        : widget.post.likeCount;
    final availableTabs = [
      'ALL',
      ...summary.entries.where((e) => e.value > 0).map((e) => e.key),
    ];

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.all(Radius.circular(2)),
              ),
            ),
          ),
        ),

        // Tabs
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: availableTabs.length,
            itemBuilder: (context, index) {
              final tab = availableTabs[index];
              final count = tab == 'ALL' ? totalCount : (summary[tab] ?? 0);
              final isSelected = _activeTab == tab;
              final rDef = tab == 'ALL' ? null : reactionDefFor(tab);

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (rDef != null) ...[
                        Transform.scale(scale: 0.6, child: rDef.icon),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        tab == 'ALL' ? 'All $count' : '$count',
                        style: TextStyle(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.black87,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _activeTab = tab);
                      _fetchReactors();
                    }
                  },
                ),
              );
            },
          ),
        ),
        const Divider(),

        // List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _reactors.isEmpty
              ? const Center(
                  child: Text(
                    'No reactions yet',
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              : ListView.builder(
                  itemCount: _reactors.length,
                  itemBuilder: (context, index) {
                    final reactor = _reactors[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: reactor.avatarUrl != null
                            ? NetworkImage(reactor.avatarUrl!)
                            : null,
                        child: reactor.avatarUrl == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(reactor.name),
                      trailing: const SizedBox.shrink(),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
