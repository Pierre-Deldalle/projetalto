import 'package:flutter/material.dart';

/// Bouton flottant de retour à l'accueil.
/// Conçu pour être utilisé dans un Stack ou un Scaffold, il offre une navigation
/// rapide vers la page d'accueil avec une esthétique cohérente.
class HomeFloatingButton extends StatelessWidget {
  /// Callback déclenché lors du tap sur le bouton.
  final VoidCallback onPressed;

  const HomeFloatingButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      right: 20,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.lightBlue,
            // Ombre diffuse pour donner un effet de profondeur
            boxShadow: [
              BoxShadow(
                color: Colors.lightBlue.withOpacity(0.4),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.home,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    );
  }
}
