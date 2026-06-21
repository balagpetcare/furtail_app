import 'package:flutter/material.dart';

import 'certificate_wallet_screen.dart';

/// Legacy entry — redirects to Certificate Wallet.
@Deprecated('Use CertificateWalletScreen')
class VaccineCardScreen extends StatelessWidget {
  const VaccineCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CertificateWalletScreen();
  }
}
