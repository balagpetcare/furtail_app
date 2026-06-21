import 'package:flutter/material.dart';

import 'package:furtail_app/core/theme/typography.dart';
class PetStepHeader extends StatelessWidget {
  final int current;
  final List<String> titles;

  const PetStepHeader({super.key, required this.current, required this.titles});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: List.generate(titles.length, (i) {
          final active = i == current;
          return Expanded(
            child: Column(
              children: [
                Container(
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: active
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade300,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  titles[i],
                  style: context.appText.bodySmall!.copyWith(
                    color: active
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade600,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
