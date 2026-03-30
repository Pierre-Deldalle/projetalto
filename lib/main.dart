import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:projetalto/screens/home_screen.dart';
import 'package:projetalto/screens/init_pairing_screen.dart';
import 'package:projetalto/screens/relation_screen.dart';
import 'package:projetalto/screens/scan_pairing_screen.dart';
import 'package:projetalto/widgets/common/FooterWidget.dart';
import 'package:projetalto/widgets/common/HomeFloatingButton.dart';

void main() {
  runApp(const MyApp());
}

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        final bool isHome = state.uri.path == '/';

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              child,

              if (!isHome)
                HomeFloatingButton(
                  onPressed: () => context.go('/'),
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
            initialRelationCode: state.uri.queryParameters['relationCode'],
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