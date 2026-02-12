import 'package:flutter/material.dart';
import 'package:projetalto/widgets/common/FooterWidget.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
      bottomNavigationBar: FooterWidget(
        onQrCode: () {},
        onScanner: () {},
        onChat: () {},
      ),
    );
  }


}
