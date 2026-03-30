import 'package:flutter/material.dart';

// Classe d'un bouton réutilisable et personnalisable pour toute l'appli
class PrimaryButton extends StatelessWidget {
  // Attributs
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double width;
  final double height;
  final String text;
  final VoidCallback? onPressed;

  const PrimaryButton({
    // Paramètres nécessaires à la création du bouton
    super.key,
    // Couleurs par défaut
    this.backgroundColor = Colors.blueAccent,
    this.foregroundColor = Colors.black,
    required this.width,
    required this.height,
    required this.text,
    // Fonction décrivant l'action du bouton à passer en paramètre
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Création du ElevatedButton
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        // Couleur du fond
        backgroundColor: backgroundColor,
        // Couleur du texte ou autre à l'intérieur
        foregroundColor: foregroundColor,
        shadowColor: Colors.black,
        // Taille de l'ombre
        elevation: 5,
        minimumSize: Size(width, height),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        // Border radius permettant de toujours avoir des arcs de cerlcles sur les côtés
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(height/2)),
      ),
      child: Text(text),
    );
  }
}
