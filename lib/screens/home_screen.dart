import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/common/FooterWidget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _State();
}

class _State extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Texte de Bienvenue
            Text(
              'Bienvenue sur',
              style: TextStyle(
                fontFamily: 'PoliceGras',
                fontSize: 32,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 50),
            //Image du logo
            Image.asset(
              'assets/images/logoComplet.png',
              width: 200,
            ),
          ],
        ),
      ),
      //Footer
      bottomNavigationBar: FooterWidget(),
    );
  }
}

