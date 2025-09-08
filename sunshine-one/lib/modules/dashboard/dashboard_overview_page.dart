import 'package:flutter/material.dart';

class DashboardOverviewPage extends StatelessWidget {
  const DashboardOverviewPage({super.key});

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
                  Color(0xFFffb347), // orange
                  Color(0xFFffcc33), // yellow
                  Color(0xFFf7971e), // deep orange
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds);
            },
            child: const Text(
              'Welcome to Sunshine',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 40,
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
            'Your smart office dashboard',
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