import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'routes/app_routes.dart'; // Contains AppRoutes with routes
import 'theme/app_theme.dart'; // Theme definition
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'controllers/options_controller.dart';
import 'controllers/user_controller.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:toastification/toastification.dart';

// import 'services/employee_service.dart'; // No longer needed in main

void main() {
  tz.initializeTimeZones();
  setUrlStrategy(PathUrlStrategy());
  Get.put(OptionsController());
  Get.put(UserController()); // Register UserController globally
  runApp(ToastificationWrapper(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Utility to check if JWT is expired
  bool isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final exp = payload['exp'];
      if (exp == null) return true;
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expiry);
    } catch (_) {
      return true;
    }
  }

  Future<String> getInitialRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token != null && !isTokenExpired(token)) {
      // Check the browser URL for a deep link
      final uri = Uri.base;
      final path =
          uri.fragment; // For Flutter web, the route is in the fragment
      if (path.startsWith('/dashboard')) {
        // Always start at /dashboard, then navigate to the full path after build
        return AppRoutes.dashboard;
      }
      return AppRoutes.dashboard;
    }
    return AppRoutes.login;
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(1440, 1024),
      builder: (context, child) {
        return FutureBuilder<String>(
          future: getInitialRoute(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return GetMaterialApp(
              title: 'Sunshine Powertronics Pvt. Ltd.',
              theme: AppTheme.lightTheme,
              initialRoute: snapshot.data!,
              getPages: AppRoutes.pages,
              debugShowCheckedModeBanner: false,
              navigatorObservers: [
                GetObserver((routing) {
                  final uri = Uri.base;
                  final path = uri.fragment;
                  if (snapshot.data == AppRoutes.dashboard &&
                      path.startsWith('/dashboard') &&
                      path != '/dashboard') {
                    Future.microtask(() => Get.offAllNamed(path));
                  }
                }),
              ],
            );
          },
        );
      },
    );
  }
}
