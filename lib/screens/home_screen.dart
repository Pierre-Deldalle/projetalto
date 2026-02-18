import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          Image.asset(
            'assets/images/logoComplet.png',
            width: 200,
          ),
        ],
      ),
    );
  }
}