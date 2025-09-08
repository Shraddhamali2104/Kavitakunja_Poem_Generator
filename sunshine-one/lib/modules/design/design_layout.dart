import 'package:flutter/material.dart';

class DesignLayoutWrapper extends StatelessWidget {
  const DesignLayoutWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F5F5),
      child: const DesignLayout(),
    );
  }
}

class DesignLayout extends StatelessWidget {
  const DesignLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                colors: [
                  Color(0xFF43cea2), // green
                  Color(0xFF185a9d), // blue
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds);
            },
            child: const Text(
              'Welcome to Design',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
                letterSpacing: 2,
                color: Colors.white,
                shadows: [
                  Shadow(
                    blurRadius: 12,
                    color: Colors.black26,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your smart purchase dashboard',
            style: TextStyle(
              fontSize: 18,
              color: Colors.black54,
              fontStyle: FontStyle.italic,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
