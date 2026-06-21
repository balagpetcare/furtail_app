import 'package:flutter/material.dart';

import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/typography.dart';
class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color titleColor;
  final double logoHeight;

  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.titleColor,
    this.logoHeight = 120,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: logoHeight,
          // ✅ Login/Home logo (doctor)
          child: Image.asset('assets/images/doctor.png', fit: BoxFit.contain),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: context.appText.headlineMedium!.copyWith(color: titleColor, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        Text(
          subtitle,
          style: context.appText.bodyMedium!.copyWith(color: context.mutedTextColor),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
