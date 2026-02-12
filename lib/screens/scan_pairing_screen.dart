import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/common/FooterWidget.dart';

class ScanPairingScreen extends StatefulWidget {
  const ScanPairingScreen({super.key});

  @override
  State<ScanPairingScreen> createState() => _ScanPairingScreenState();
}

class _ScanPairingScreenState extends State<ScanPairingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: FooterWidget(
        onQrCode: () {
          GoRouter.of(context).go('/init_pairing');
        },
        onScanner: () {
          GoRouter.of(context).go('/scan_paring');
        },
        onChat: () {
          GoRouter.of(context).go('/relation');
        },
      ),
    );
  }
}