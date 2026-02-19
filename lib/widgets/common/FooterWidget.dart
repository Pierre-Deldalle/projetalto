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
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.lightBlue.withOpacity(0.5),
            offset: const Offset(0, -3),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildItem(
            icon: Icons.qr_code_2,
            label: 'Générer',
            onTap: onQrCode,
          ),
          _buildItem(
            icon: Icons.qr_code_scanner,
            label: 'Scanner',
            onTap: onScanner,
          ),
          _buildItem(
            icon: Icons.chat_bubble_outline,
            label: 'Discuter',
            onTap: onChat,
          ),
        ],
      ),
    );
  }

  Widget _buildItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: Colors.white),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'PoliceGras',
            fontSize: 12,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}