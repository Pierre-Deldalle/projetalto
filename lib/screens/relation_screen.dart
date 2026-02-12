import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/common/FooterWidget.dart';

class RelationScreen extends StatefulWidget {
  const RelationScreen({super.key});

  @override
  State<RelationScreen> createState() => _RelationScreenState();
}

class _RelationScreenState extends State<RelationScreen> {
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
