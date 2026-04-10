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
final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        final String location = state.uri.path;
        final bool isHome = location == '/';
        final bool isRelation = location == '/relation';

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              child,

              // HomeFloatingButton positionné dynamiquement pour éviter les chevauchements
              if (!isHome)
                HomeFloatingButton(
                  onPressed: () => context.go('/'),
                  // Si on est sur la page de discussion, on remonte le bouton (80 au lieu de 20)
                  bottom: isRelation ? 85 : 20,
                ),
            ],
          ),
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
