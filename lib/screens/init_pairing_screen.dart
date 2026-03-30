import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/pairing_service.dart';
import '../widgets/common/PrimaryButton.dart';

class InitPairingScreen extends StatefulWidget {
  const InitPairingScreen({super.key});

  @override
  State<InitPairingScreen> createState() => _InitPairingScreenState();
}

class _InitPairingScreenState extends State<InitPairingScreen> {
  final PairingService _pairingService = PairingService();
  String? relationCode;
  bool showQr = false;
  Timer? _pollingTimer;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _resetPairing();
  }

  void _resetPairing() {
    _pollingTimer?.cancel();

    final newCode = _pairingService.generateRelationCode();

    debugPrint("RELATION CODE: $newCode");
    debugPrint("URL: https://alto.samyn.ovh/pairing/$newCode/status");

    setState(() {
      showQr = false;
      relationCode = newCode;
    });

    _pairingService.initPairing(newCode).catchError((e) {
      debugPrint('Erreur init pairing: $e');
    });
  }


  void _startPolling() {
    _startTime = DateTime.now();
    _pollingTimer?.cancel();

    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (relationCode == null) return;

      final elapsed = DateTime.now().difference(_startTime!);
      if (elapsed.inMinutes >= 2) {
        timer.cancel();
        _showTimeoutDialog();
        return;
      }

      try {
        final status = await _pairingService.checkPairingStatus(relationCode!);
        if (status == 'completed') {
          timer.cancel();
          _showSuccessDialog();
        }
      } catch (e) {
        print('Erreur polling : $e');
      }
    });
  }

  void _showTimeoutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Temps écoulé'),
        content: const Text(
          'Le pairing n\'a pas été complété dans le temps imparti.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetPairing();
            },
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Connexion réussie !'),
        content: const Text('Vos appareils sont maintenant connectés.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

            if (!showQr)
              PrimaryButton(
                width: 200,
                height: 50,
                text: "Afficher le QR code",
                backgroundColor: Colors.lightBlue,
                foregroundColor: Colors.white,
                onPressed: () {
                  if (relationCode == null) return;
                  setState(() {
                    showQr = true;
                  });
                  _startPolling();
                },
              ),

            if (showQr && relationCode != null)
              QrImageView(
                data: relationCode!,
                size: 250,
                foregroundColor: Colors.lightBlue,
              ),
          ],
        ),
      ),
    );
  }
}
