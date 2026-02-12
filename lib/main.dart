import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:projetalto/screens/home_screen.dart';
import 'package:projetalto/screens/init_pairing_screen.dart';
import 'package:projetalto/screens/relation_screen.dart';
import 'package:projetalto/screens/scan_pairing_screen.dart';

void main() {
  runApp(const MyApp());
}

final GoRouter _router = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const HomeScreen();
      },
    ),
    GoRoute(
      path: '/init_pairing',
      builder: (BuildContext context, GoRouterState state) {
        return const InitPairingScreen();
      },
    ),
    GoRoute(
      path: '/scan_paring',
      builder: (BuildContext context, GoRouterState state) {
        return const ScanPairingScreen();
      },
    ),
    GoRoute(
      path: '/relation',
      builder: (BuildContext context, GoRouterState state) {
        return const RelationScreen();
      },
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(routerConfig: _router);
  }
}