import 'package:flutter/material.dart';

// Classe du bouton Home
class HomeFloatingButton extends StatelessWidget {
  // Attributs
  final VoidCallback onPressed;

  const HomeFloatingButton({
    // Paramètres
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Création du HomeFloatingButton
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
            boxShadow: [
              BoxShadow(
                color: Colors.lightBlue.withOpacity(0.6),
                blurRadius: 12,
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