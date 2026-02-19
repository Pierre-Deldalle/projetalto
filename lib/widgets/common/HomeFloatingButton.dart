import 'package:flutter/material.dart';

class HomeFloatingButton extends StatelessWidget {
  final VoidCallback onPressed;

  const HomeFloatingButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 110,
      right: 20,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.lightBlue,
            boxShadow: [
              BoxShadow(
                color: Colors.lightBlue.withOpacity(0.6),
                blurRadius: 12,
              ),
            ],
          ),
          child: const Icon(
            Icons.home,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    );
  }
}