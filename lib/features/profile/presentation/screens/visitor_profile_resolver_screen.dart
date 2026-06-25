import 'dart:async';
import 'package:flutter/material.dart';

import 'package:furtail_app/features/profile/data/models/visitor_profile_model.dart';
import 'package:furtail_app/services/social_service.dart';
import 'package:furtail_app/core/storage/local_storage.dart';
import 'user_profile_screen.dart';
import 'visitor_profile_screen.dart';

/// Resolves a username to a numeric userId, then replaces itself with
/// [VisitorProfileScreen]. Shows a spinner while the network call is in flight
/// and a "not found" page if the username lookup fails.
class VisitorProfileResolverScreen extends StatefulWidget {
  final String username;

  const VisitorProfileResolverScreen({super.key, required this.username});

  @override
  State<VisitorProfileResolverScreen> createState() => _VisitorProfileResolverScreenState();
}

class _VisitorProfileResolverScreenState extends State<VisitorProfileResolverScreen> {
  String? _error;

  String get _cleanUsername => widget.username.replaceFirst(RegExp(r'^@'), '');

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_resolve);
  }

  Future<void> _resolve() async {
    try {
      final raw = await SocialService().getVisitorProfileByUsername(widget.username);
      final profile = VisitorProfileModel.fromApi(raw);
      if (!mounted) return;
      if (profile.id <= 0) {
        setState(() => _error = 'Profile not found');
        return;
      }
      final currentUserId = await LocalStorage.getUserId();
      if (!mounted) return;
      if (currentUserId != null && profile.id == currentUserId) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const UserProfileScreen(),
          ),
        );
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => VisitorProfileScreen(userId: profile.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');
      final isNotFound = msg.contains('404') || msg.toLowerCase().contains('not found');
      setState(() => _error = isNotFound ? 'Profile not found' : msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_off_outlined,
                    size: 72, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 20),
                Text(
                  'Profile not found',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '@$_cleanUsername',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 28),
                TextButton.icon(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Go back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'Finding @$_cleanUsername…',
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
