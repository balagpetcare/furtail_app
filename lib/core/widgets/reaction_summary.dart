import 'package:flutter/material.dart';
import 'package:furtail_app/core/widgets/reaction_control.dart';
import 'package:furtail_app/features/posts/data/models/post_model.dart';

class ReactionSummary extends StatelessWidget {
  final Map<String, int>? summary;
  final int totalCount;
  final List<PostAuthorModel> topReactors;

  const ReactionSummary({
    super.key,
    required this.summary,
    required this.totalCount,
    this.topReactors = const [],
  });

  @override
  Widget build(BuildContext context) {
    if (totalCount == 0 && (summary == null || summary!.isEmpty)) {
      return const SizedBox.shrink();
    }

    final entries =
        (summary ?? const <String, int>{}).entries
            .where((e) => e.value > 0)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final displayReactions = entries.take(3).map((e) => e.key).toList();

    String textSummary;
    if (topReactors.isNotEmpty) {
      final names = topReactors
          .take(2)
          .map((r) => r.name.split(' ')[0])
          .where((n) => n.isNotEmpty)
          .toList();
      final remaining = totalCount - names.length;
      if (names.length == 1) {
        textSummary = remaining > 0
            ? '${names[0]} and $remaining other${remaining > 1 ? 's' : ''}'
            : names[0];
      } else if (names.length == 2) {
        textSummary = remaining > 0
            ? '${names[0]}, ${names[1]} and $remaining other${remaining > 1 ? 's' : ''}'
            : '${names[0]} and ${names[1]}';
      } else {
        textSummary = '$totalCount reaction${totalCount != 1 ? 's' : ''}';
      }
    } else {
      textSummary = '$totalCount like${totalCount != 1 ? 's' : ''}';
    }

    if (displayReactions.isEmpty) {
      return Text(
        textSummary,
        style: const TextStyle(fontSize: 12, color: Colors.black54),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 16,
          width: 16.0 + (displayReactions.length - 1) * 12.0,
          child: Stack(
            clipBehavior: Clip.none,
            children: List.generate(displayReactions.length, (index) {
              final rType = displayReactions[index];
              final rDef = reactionDefFor(rType) ?? reactions.first;
              return Positioned(
                left: index * 12.0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: rDef.color,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Transform.scale(scale: 0.6, child: rDef.icon),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          textSummary,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}
