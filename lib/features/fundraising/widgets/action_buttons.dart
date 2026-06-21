import 'package:flutter/material.dart';

class FundraisingActionButtons extends StatelessWidget {
  final VoidCallback onAdopt;
  final VoidCallback onVolunteer;
  final VoidCallback onShare;

  const FundraisingActionButtons({
    super.key,
    required this.onAdopt,
    required this.onVolunteer,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        _Pill(label: 'ADOPT', icon: Icons.pets, onTap: onAdopt),
        _Pill(label: 'VOLUNTEER', icon: Icons.favorite, onTap: onVolunteer),
        _Pill(label: 'SHARE', icon: Icons.share, onTap: onShare),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _Pill({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
