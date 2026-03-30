import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/pairing_service.dart';

class ScanPairingScreen extends StatefulWidget {
  const ScanPairingScreen({super.key});

  @override
  State<ScanPairingScreen> createState() => _ScanPairingScreenState();
}

class _ScanPairingScreenState extends State<ScanPairingScreen> {
  final MobileScannerController controller = MobileScannerController();
  final PairingService _pairingService = PairingService();

  bool isProcessing = false;

  Future<void> _handleQrCode(String relationCodeA) async {
    if (isProcessing) return;

    setState(() {
      isProcessing = true;
    });

    try {
      controller.stop();

      final relationCodeB = _pairingService.generateRelationCode();
      final publicKeyB =
          "publicKey_dummy_${DateTime.now().millisecondsSinceEpoch}";

      await _pairingService.completePairing(
        relationCodeA: relationCodeA,
        relationCodeB: relationCodeB,
        publicKeyB: publicKeyB,
      );

      await _pairingService.saveLastRelationCode(relationCodeA);

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text("Connexion réussie !"),
          content: const Text("Les appareils sont maintenant connectés."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (!mounted) return;
                context.go(
                  '/relation?relationCode=${Uri.encodeComponent(relationCodeA)}',
                );
              },
              child: const Text("OK"),
            )
          ],
        ),
      );
    } catch (e) {
      controller.start();

      setState(() {
        isProcessing = false;
      });

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Erreur"),
          content: Text("Échec de la connexion : $e"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("OK"),
            )
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (BarcodeCapture capture) {
              final String? code = capture.barcodes.first.rawValue;
              if (code != null) {
                _handleQrCode(code);
              }
            },
          ),
          if (isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
