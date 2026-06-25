import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/connectivity_service.dart';

/// Slim banner shown at the top of the home screen when the device is offline.
/// Renders nothing when online.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(connectivityStatusProvider);

    return statusAsync.when(
      data: (status) {
        if (status == ConnectivityStatus.online) return const SizedBox.shrink();
        return _BannerBar(
          isOffline: status == ConnectivityStatus.offline,
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _BannerBar extends StatelessWidget {
  final bool isOffline;
  const _BannerBar({required this.isOffline});

  @override
  Widget build(BuildContext context) {
    final color = isOffline ? const Color(0xFFB71C1C) : const Color(0xFFE65100);
    final icon = isOffline ? Icons.wifi_off_rounded : Icons.signal_wifi_statusbar_connected_no_internet_4_rounded;
    final message = isOffline
        ? 'You\'re offline · Showing cached feed'
        : 'Slow connection · Showing cached feed';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
