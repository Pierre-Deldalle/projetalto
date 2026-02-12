import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/pairing_service.dart';
import '../widgets/common/FooterWidget.dart';
import '../widgets/common/PrimaryButton.dart';

class InitPairingScreen extends StatefulWidget {
  const InitPairingScreen({super.key});

  @override
  State<InitPairingScreen> createState() => _InitPairingScreenState();
}
class _InitPairingScreenState extends State<InitPairingScreen> {
  final PairingService _pairingService = PairingService();
  String? relationCode;
  bool showQr = false; // ← nouveau booléen

  @override
  void initState() {
    super.initState();
    relationCode = _pairingService.generateRelationCode();
  }

  @override
  Widget build(BuildContext context) {
    if (relationCode == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Scanne ce QR code",
              style: TextStyle(
                fontFamily: 'PoliceNormale',
                fontSize: 32,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            // ← Ici on affiche soit le bouton, soit le QR code
            if (!showQr)
              PrimaryButton(
                width: 200,
                height: 50,
                text: "Afficher le QR code",
                backgroundColor: Colors.lightBlue,
                foregroundColor: Colors.white,
                onPressed: () {
                  setState(() {
                    showQr = true; // affiche le QR
                  });
                },
              )
            else
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.1),
                      offset: const Offset(0, 3),
                      blurRadius: 3,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: relationCode!,
                  size: 250,
                  foregroundColor: Colors.lightBlue,
                ),
              ),
          ],
        ),
      ),
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
