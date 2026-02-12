import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double width;
  final double height;
  final String text;
  final VoidCallback? onPressed;

  const PrimaryButton({
    super.key,
    this.backgroundColor = Colors.blueAccent,
    this.foregroundColor = Colors.black,
    required this.width,
    required this.height,
    required this.text,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        shadowColor: Colors.black,
        elevation: 5,
        minimumSize: Size(width, height),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(height/2)),
      ),
      child: Text(text),
    );
  }
}
