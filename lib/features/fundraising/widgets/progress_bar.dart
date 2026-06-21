import 'package:flutter/material.dart';

class FundraisingProgressBar extends StatelessWidget {
  final int raised;
  final int target;

  const FundraisingProgressBar({
    super.key,
    required this.raised,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    final pct = target <= 0 ? 0.0 : (raised / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(value: pct, minHeight: 10),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              '৳${_fmt(raised)} raised',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Spacer(),
            Text(
              '৳${_fmt(target)} target',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ],
    );
  }

  String _fmt(int v) => v.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => ',',
  );
}
