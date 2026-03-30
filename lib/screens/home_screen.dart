import 'package:flutter/material.dart';

// Classe de la page d'accueil
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Création de la page d'accueil
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Bienvenue sur',
            style: TextStyle(
              fontFamily: 'PoliceGras',
              fontSize: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 50),
          // Logo de l'application
          Image.asset(
            'assets/images/logoComplet.png',
            width: 200,
          ),
        ],
      ),
    );
  }
}