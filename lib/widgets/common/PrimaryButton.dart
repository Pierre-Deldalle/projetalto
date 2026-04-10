import 'package:flutter/material.dart';

/// Composant bouton personnalisé réutilisable dans toute l'application.
/// Il permet de maintenir une cohérence visuelle sur tous les boutons d'action.
class PrimaryButton extends StatelessWidget {
  // Attributs de personnalisation
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double width;
  final double height;
  final String text;
  final VoidCallback? onPressed;

  const PrimaryButton({
    super.key,
    // Configuration par défaut (Bleu accentué, texte noir)
    this.backgroundColor = Colors.blueAccent,
    this.foregroundColor = Colors.black,
    required this.width,
    required this.height,
    required this.text,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        // Fond du bouton
        backgroundColor: backgroundColor,
        // Couleur du texte ou de l'icône interne
        foregroundColor: foregroundColor,
        shadowColor: Colors.black,
        
        // Ombre portée
        elevation: 5,
        
        // Dimensions minimales
        minimumSize: Size(width, height),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        
        // Forme arrondie (calculée pour être une demi-hauteur -> bords arrondis parfaits)
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
