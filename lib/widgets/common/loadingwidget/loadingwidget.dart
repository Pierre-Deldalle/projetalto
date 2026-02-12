import 'package:flutter/material.dart';

class Loadingwidget extends StatefullWidget {
  @override
  _SpinningLogoState() => _SpinningLogoState();
}

class _SpinningLogoState extends State<_SpinningLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Image.asset(
        "loadingwidget/logo_cadena.jpg",
        width: 80,
      ),
    );
  }
