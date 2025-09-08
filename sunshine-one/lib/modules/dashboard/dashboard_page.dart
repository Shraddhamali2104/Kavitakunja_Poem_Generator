// lib/modules/dashboard/dashboard_page.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'components/sidebar.dart';
import 'components/navbar.dart';
import 'package:get/get.dart';
import 'dashboard_controller.dart';

/// DashboardPage - Basic layout without animations
class DashboardPage extends StatefulWidget {
  final Widget? child;
  const DashboardPage({super.key, this.child});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    // Ensure the controller is available
    if (!Get.isRegistered<DashboardController>()) {
      Get.put(DashboardController());
    }
    final isWeb = kIsWeb;

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: isWeb ? null : Drawer(child: Sidebar()),
      appBar: isWeb ? null : AppBar(
        backgroundColor: Colors.black,
        title: const Text('Dashboard', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Row(
          children: [
            if (isWeb) Sidebar(),
            Expanded(
              child: Container(
                color: Colors.white,
                child: Column(
                  children: [
                    if (isWeb)
                      SizedBox(
                        width: double.infinity,
                        child: Navbar(),
                      ),
                    Expanded(
                      child: widget.child ?? Container(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
