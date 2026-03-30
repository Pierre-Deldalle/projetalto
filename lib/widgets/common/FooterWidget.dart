import 'package:flutter/material.dart';

// Classe de la barre de navigation présente dans chaque page
class FooterWidget extends StatelessWidget {
  // Attributs
  final VoidCallback onQrCode;
  final VoidCallback onScanner;
  final VoidCallback onChat;

  const FooterWidget({
    // Paramètres nécessaires à la création de la barre
    super.key,
    // Fonctions des boutons à passer en paramètres
    required this.onQrCode,
    required this.onScanner,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    // Création de la barre de navigation
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        // Border radius uniquement sur les coins supérieurs
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.lightBlue.withOpacity(0.5),
            offset: const Offset(0, -3),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        // Espace égal entre les boutons de la barre
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Boutons de la barre de navigation accompagné d'icônes et textes
          _buildItem(
            icon: Icons.qr_code_2,
            label: 'Générer',
            onTap: onQrCode,
          ),
          _buildItem(
            icon: Icons.qr_code_scanner,
            label: 'Scanner',
            onTap: onScanner,
          ),
          _buildItem(
            icon: Icons.chat_bubble_outline,
            label: 'Discuter',
            onTap: onChat,
          ),
        ],
      ),
    );
  }

  // Bouton personnalisé pour la barre
  Widget _buildItem({
    // Une icône, un texte et une fonction nécessaire
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    // Les éléments sont placés en colonne
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: Colors.white),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'PoliceGras',
            fontSize: 12,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}