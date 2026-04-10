import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/pairing_service.dart';

/// Écran permettant de scanner le QR Code d'un autre appareil
/// pour finaliser le processus d'appairage.
class ScanPairingScreen extends StatefulWidget {
  const ScanPairingScreen({super.key});

  @override
  State<ScanPairingScreen> createState() => _ScanPairingScreenState();
}

class _ScanPairingScreenState extends State<ScanPairingScreen> {
  // Contrôleur de la caméra
  final MobileScannerController controller = MobileScannerController();
  final PairingService _pairingService = PairingService();

  // État pour éviter les scans multiples pendant le traitement
  bool _isProcessing = false;

  /// Gère la détection d'un QR code.
  /// [scannedCode] correspond au code de relation (relationCodeA) de l'initiateur.
  Future<void> _handleScannedQrCode(String scannedCode) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // 1. Arrête la caméra pour économiser les ressources et éviter les détections multiples
      controller.stop();

      // 2. Génère nos propres identifiants pour la liaison retour (handshake)
      final ourRelationCode = _pairingService.generateRelationCode();
      final ourDeviceId = await _pairingService.getOrCreateDeviceId();

      // 3. Initialise notre session localement
      await _pairingService.initPairing(ourRelationCode);

      // 4. Informe le serveur que nous lions notre code au sien
      await _pairingService.completePairing(
        relationCodeA: scannedCode,
        relationCodeB: ourRelationCode,
        publicKeyB: ourDeviceId,
      );

      // 5. Sauvegarde le contexte pour la navigation future
      await _pairingService.saveLastRelationCode(scannedCode);
      await _pairingService.saveDiscussionContext(
        localRelationCode: ourRelationCode,
        remoteRelationCode: scannedCode,
      );

      // 6. Envoie un message système ("CHANNEL") pour donner notre code retour à l'initiateur
      await _pairingService.sendDiscussionMessage(
        relationCode: scannedCode,
        senderId: ourDeviceId,
        type: 'CHANNEL',
        content: jsonEncode({
          'replyCode': ourRelationCode,
          'senderId': ourDeviceId,
        }),
      );

      if (!mounted) return;

      // 7. Affiche la réussite et navigue vers l'écran de relation
      _showSuccessAndNavigate(ourRelationCode, scannedCode);

    } catch (e) {
      // En cas d'erreur, on relance la caméra pour permettre un nouvel essai
      controller.start();
      setState(() {
        _isProcessing = false;
      });
      _showErrorDialog(e.toString());
    }
  }

  /// Affiche le dialogue de succès et gère la navigation.
  void _showSuccessAndNavigate(String localCode, String remoteCode) {
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
                '/relation?localCode=${Uri.encodeComponent(localCode)}&remoteCode=${Uri.encodeComponent(remoteCode)}',
              );
            },
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  /// Affiche une erreur à l'utilisateur.
  void _showErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Erreur"),
        content: Text("Échec de la connexion : $errorMessage"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose(); // Très important pour libérer la caméra
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double scanAreaSize = 250.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Couche 1 : Le flux caméra
          MobileScanner(
            controller: controller,
            onDetect: (BarcodeCapture capture) {
              final String? code = capture.barcodes.first.rawValue;
              if (code != null) {
                _handleScannedQrCode(code);
              }
            },
          ),

          // Couche 2 : Overlay d'assombrissement avec trou central
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.6),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    height: scanAreaSize,
                    width: scanAreaSize,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Couche 3 : Cadre de visée (coins bleus)
          Align(
            alignment: Alignment.center,
            child: CustomPaint(
              size: const Size(scanAreaSize, scanAreaSize),
              painter: ScannerOverlayPainter(),
            ),
          ),

          // Couche 4 : Texte d'instruction
          const Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Text(
              "Placez le QR Code dans le cadre",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                shadows: [Shadow(blurRadius: 10, color: Colors.black)],
              ),
            ),
          ),

          // Couche 5 : Indicateur de chargement pendant le traitement
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.blueAccent),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dessinateur personnalisé pour les coins du scanner.
class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerSize = 30.0;
    final path = Path();

    // Coin haut gauche
    path.moveTo(0, cornerSize);
    path.lineTo(0, 0);
    path.lineTo(cornerSize, 0);

    // Coin haut droite
    path.moveTo(size.width - cornerSize, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, cornerSize);

    // Coin bas droite
    path.moveTo(size.width, size.height - cornerSize);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width - cornerSize, size.height);

    // Coin bas gauche
    path.moveTo(cornerSize, size.height);
    path.lineTo(0, size.height);
    path.lineTo(0, size.height - cornerSize);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
