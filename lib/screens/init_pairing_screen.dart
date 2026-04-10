import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/pairing_service.dart';
import '../widgets/common/PrimaryButton.dart';

/// Écran d'initialisation de l'appairage.
/// Cet écran génère un QR Code que l'autre appareil devra scanner.
class InitPairingScreen extends StatefulWidget {
  const InitPairingScreen({super.key});

  @override
  State<InitPairingScreen> createState() => _InitPairingScreenState();
}

class _InitPairingScreenState extends State<InitPairingScreen> {
  // Services et État
  final PairingService _pairingService = PairingService();
  
  String? _relationCode;           // Code unique pour la liaison actuelle
  bool _isShowingQr = false;       // État d'affichage du QR Code
  Timer? _pollingTimer;            // Timer pour le rafraîchissement et le polling
  DateTime? _pairingStartTime;     // Heure de début pour calculer l'expiration
  int _secondsRemaining = 120;     // Compte à rebours (2 minutes)

  @override
  void initState() {
    super.initState();
    _prepareNewPairing();
  }

  /// Prépare une nouvelle session d'appairage en générant un code
  /// et en l'enregistrant sur le serveur.
  void _prepareNewPairing() {
    _pollingTimer?.cancel();

    final newCode = _pairingService.generateRelationCode();
    debugPrint("Nouveau code généré : $newCode");

    setState(() {
      _isShowingQr = false;
      _relationCode = newCode;
      _secondsRemaining = 120;
    });

    // Enregistrement silencieux sur le serveur
    _pairingService.initPairing(newCode).catchError((error) {
      debugPrint('Erreur lors de l\'initialisation du pairing: $error');
    });
  }

  /// Démarre le cycle de vie du QR Code :
  /// 1. Décrémentation du timer toutes les secondes.
  /// 2. Vérification du statut du serveur toutes les 3 secondes.
  void _startPairingProcess() {
    _pairingStartTime = DateTime.now();
    _pollingTimer?.cancel();

    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_relationCode == null) return;

      // Calcul du temps écoulé et restant
      final elapsed = DateTime.now().difference(_pairingStartTime!);
      final remaining = 120 - elapsed.inSeconds;

      // Gestion de l'expiration
      if (remaining <= 0) {
        timer.cancel();
        setState(() {
          _secondsRemaining = 0;
          _isShowingQr = false; // Retour à l'état initial (bouton visible)
        });
        return;
      }

      setState(() {
        _secondsRemaining = remaining;
      });

      // Polling serveur : on vérifie si l'autre appareil a complété le scan
      // On le fait toutes les 3 secondes pour économiser les ressources réseau
      if (remaining % 3 == 0) {
        try {
          final status = await _pairingService.checkPairingStatus(_relationCode!);
          if (status == 'completed') {
            timer.cancel();
            _onPairingSuccess();
          }
        } catch (error) {
          debugPrint('Erreur lors du polling : $error');
        }
      }
    });
  }

  /// Action effectuée lorsque l'appairage est confirmé par le serveur.
  void _onPairingSuccess() {
    final code = _relationCode;
    if (code == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Connexion réussie !'),
        content: const Text('Vos appareils sont maintenant connectés.'),
        actions: [
          TextButton(
            onPressed: () async {
              // Sauvegarde locale des informations de session
              await _pairingService.saveLastRelationCode(code);
              await _pairingService.saveDiscussionContext(
                localRelationCode: code,
                remoteRelationCode: null,
              );
              
              if (!mounted) return;
              Navigator.of(dialogContext).pop();
              
              // Navigation vers l'écran de relation
              context.go(
                '/relation?localCode=${Uri.encodeComponent(code)}',
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Formate les secondes en chaîne de caractères mm:ss
  String _formatTimeDisplay(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _pollingTimer?.cancel(); // Nettoyage du timer pour éviter les fuites mémoire
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

            // État 1 : QR Code non affiché ou expiré
            if (!_isShowingQr) ...[
              PrimaryButton(
                width: 200,
                height: 50,
                text: "Afficher le QR code",
                backgroundColor: Colors.lightBlue,
                foregroundColor: Colors.white,
                onPressed: () {
                  if (_relationCode == null) return;
                  setState(() => _isShowingQr = true);
                  _startPairingProcess();
                },
              ),
              if (_secondsRemaining == 0) ...[
                const SizedBox(height: 20),
                const Text(
                  "Le QR code a expiré.",
                  style: TextStyle(color: Colors.redAccent, fontSize: 16),
                ),
              ]
            ],

            // État 2 : QR Code actif avec timer
            if (_isShowingQr && _relationCode != null) ...[
              QrImageView(
                data: _relationCode!,
                size: 250,
                foregroundColor: Colors.lightBlue,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Expire dans : ${_formatTimeDisplay(_secondsRemaining)}",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
