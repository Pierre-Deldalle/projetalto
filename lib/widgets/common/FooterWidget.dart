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
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.lightBlue.withOpacity(0.5),
            offset: const Offset(0, -3),
            blurRadius: 6,
          )
        ]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // QR Code
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onQrCode,
                icon: const Icon(Icons.qr_code_2, color: Colors.white),
              ),
              const Text(
                'Générer',
                style: TextStyle(
                  fontFamily: 'PoliceGras',
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          // Scanner
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onScanner,
                icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
              ),
              const Text(
                'Scanner',
                style: TextStyle(
                  fontFamily: 'PoliceGras',
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          // Chat
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onChat,
                icon: const Icon(
                    Icons.chat_bubble_outline, color: Colors.white),
              ),
              const Text(
                'Discuter',
                style: TextStyle(
                  fontFamily: 'PoliceGras',
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}