import 'package:flutter/material.dart';

class FooterWidget extends StatelessWidget {
  final VoidCallback onQrCode;
  final VoidCallback onScanner;
  final VoidCallback onChat;

  const FooterWidget({
    super.key,
    required this.onQrCode,
    required this.onScanner,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: Color.fromRGBO(26, 27, 38, 1.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(onPressed: onQrCode, icon: const Icon(Icons.qr_code_2, color: Colors.white,)),
          IconButton(
            onPressed: onScanner,
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white,),
          ),
          IconButton(
            onPressed: onChat,
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white,),
          ),
        ],
      ),
    );
  }
}
