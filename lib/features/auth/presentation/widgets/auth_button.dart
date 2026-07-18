import 'package:flutter/material.dart';

import 'package:furtail_app/core/theme/typography.dart';

class AuthButton extends StatelessWidget {
  final String text;
  final bool loading;
  final VoidCallback? onPressed;
  final Color color;
  final double radius;
  final double height;
  final double elevation;

  const AuthButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.loading = false,
    required this.color,
    this.radius = 15,
    this.height = 55,
    this.elevation = 3,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          elevation: elevation,
        ),
        child: loading
            ? CircularProgressIndicator(
                color: Theme.of(context).colorScheme.onPrimary,
              )
            : Text(
                text,
                style: context.appText.titleMedium!.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
