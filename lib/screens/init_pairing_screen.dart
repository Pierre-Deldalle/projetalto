import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/pairing_service.dart';

class InitPairingScreen extends StatefulWidget {
  const InitPairingScreen({super.key});

  @override
  State<InitPairingScreen> createState() => _InitPairingScreenState();
}

class _InitPairingScreenState extends State<InitPairingScreen> {

  final PairingService _pairingService = PairingService();
  String? relationCode;

  @override
  void initState() {
    super.initState();
    relationCode = _pairingService.generateRelationCode();
  }

  @override
  Widget build(BuildContext context) {
    if (relationCode == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Initialiser le pairing")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Scanne ce QR code"),
            const SizedBox(height: 20),
            QrImageView(
              data: relationCode!,
              size: 250,
            ),
          ],
        ),
      ),
    );
  }
}