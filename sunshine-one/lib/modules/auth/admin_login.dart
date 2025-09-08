import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:myoffice_sunshine/utils/snackbar_message.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:logger/logger.dart';
import 'package:myoffice_sunshine/controllers/user_controller.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  final Logger _logger = Logger();

  Future<void> _loginAdmin() async {
    setState(() => _isLoading = true);
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;

    // Input validation
    if (email.isEmpty || password.isEmpty) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Validation Error"),
          content: const Text("Please enter both email and password."),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse("https://1.sunshineiot.in/api/v2/admin/auth/signin"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"admin_email": email, "admin_password": password}),
      );
      setState(() => _isLoading = false);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        if (token != null) {
          try {
            Map<String, dynamic> decodedToken = JwtDecoder.decode(token);

            // Debug: Log token contents
            _logger.d('Decoded token: $decodedToken');

            // Check if the user is admin based on rpm value (15) or email
            // rpm: "15" corresponds to admin role based on the permissions system
            bool isAdmin = false;
            if (decodedToken['rpm'] == '15' || decodedToken['rpm'] == 15) {
              isAdmin = true;
            } else if (decodedToken['email'] == 'admin@sunshine.com') {
              isAdmin = true;
            }

            _logger.d('Is admin: $isAdmin');

            if (isAdmin) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('jwt_token', token);

              // Fetch profile
              final profileResponse = await http.get(
                Uri.parse(
                  'https://1.sunshineiot.in/api/v2/hr/employee/profile',
                ),
                headers: {'Authorization': 'Bearer $token'},
              );

              if (profileResponse.statusCode == 200) {
                final profileJson = jsonDecode(profileResponse.body);
                final empData = profileJson['employee'] ?? profileJson;

                final userController = Get.find<UserController>();
                await userController.setUser(empData);
                await userController.fetchEmployeeDetailsWithUserId();

                // Wait until isLoading is false
                if (userController.currentUser.value != null) {
                  SnackbarUtils.showSuccess("Admin login successful.");
                  Get.offAllNamed('/dashboard');
                  return;
                }
              }
            }
          } catch (jwtError) {
            _logger.e('JWT decoding error: $jwtError');
            if (!mounted) return;
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text("Token Error"),
                content: const Text("Invalid authentication token received."),
                actions: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text("OK"),
                  ),
                ],
              ),
            );
            return;
          }
        }
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Login Failed"),
            content: const Text("Invalid admin credentials or role."),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      } else if (response.statusCode == 500) {
        // Handle server error specifically
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Error"),
            content: const Text(
              "Check your internet connection or try again later.",
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      } else if (response.statusCode == 401) {
        // Handle unauthorized
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Authentication Failed"),
            content: const Text("Invalid email or password."),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      } else {
        // Handle other status codes
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Login Failed"),
            content: Text(
              "Server returned status code: ${response.statusCode}",
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Network Error"),
          content: Text("Connection error: $e"),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/new.jpg', fit: BoxFit.cover),
          SafeArea(
            child: Center(
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[100]?.withAlpha((0.95 * 255).toInt()),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/sunshine_logo.png',
                      width: 120,
                      height: 120,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Admin Login',
                      style: TextStyle(fontSize: 28, color: Colors.black),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Admin Email',
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _loginAdmin,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Sign In'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
