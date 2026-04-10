import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:projetalto/screens/home_screen.dart';
import 'package:projetalto/screens/init_pairing_screen.dart';
import 'package:projetalto/screens/relation_screen.dart';
import 'package:projetalto/screens/scan_pairing_screen.dart';
import 'package:projetalto/widgets/common/FooterWidget.dart';
import 'package:projetalto/widgets/common/HomeFloatingButton.dart';

/// Point d'entrée principal de l'application.
void main() {
  runApp(const MyApp());
}

/// Configuration du routage avec GoRouter.
/// Utilise un ShellRoute pour conserver le Footer personnalisé sur tous les écrans.
final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        // Détermine si nous sommes sur la page d'accueil pour afficher le bouton flottant
        final bool isHome = state.uri.path == '/';

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // L'écran actuel
              child,

              // Le HomeFloatingButton apparaît uniquement hors de l'accueil
              if (!isHome)
                HomeFloatingButton(
                  onPressed: () => context.go('/'),
                ),
            ],
          ),
          // Rétablissement du Footer personnalisé avec ses paramètres de navigation
          bottomNavigationBar: FooterWidget(
            onQrCode: () => context.go('/init_pairing'),
            onScanner: () => context.go('/scan_pairing'),
            onChat: () => context.go('/relation'),
          ),
        );
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/init_pairing',
          builder: (context, state) => const InitPairingScreen(),
        ),
        GoRoute(
          path: '/scan_pairing',
          builder: (context, state) => const ScanPairingScreen(),
        ),
        GoRoute(
          path: '/relation',
          builder: (context, state) => RelationScreen(
            initialLocalRelationCode:
                state.uri.queryParameters['localCode'] ??
                state.uri.queryParameters['relationCode'],
            initialRemoteRelationCode: state.uri.queryParameters['remoteCode'],
          ),
        ),
      ],
    ),
  ],
);

/// Racine de l'application.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Alto Project',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
    );
  }
}
