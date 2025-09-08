import 'package:flutter/material.dart';

class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: Colors.black,
      alignment: Alignment.center,
      child: const Text(
        '© 2025 Sunshsine Powertronics. All rights reserved.',
        style: TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}