import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myoffice_sunshine/routes/app_routes.dart';
import 'package:myoffice_sunshine/utils/snackbar_message.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendOtp() async {
    setState(() => _isLoading = true);
    final String email = _emailController.text.trim();
    final response = await http.post(
      Uri.parse("https://1.sunshineiot.in/api/v2/hr/employee/auth/send-otp"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"emp_email_id": email}),
    );
    setState(() => _isLoading = false);
    // print("Response status: ${response.statusCode}");
    // print("Response body: ${response.body}");
    if (!mounted) return;

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('emp_email_id', email);
        if (!mounted) return;
        SnackbarUtils.showSuccess("Otp sent to your email.");

        if (mounted) {
          Get.toNamed('/otp');
        }
      } else {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Failed to send OTP"),
            content: Text(
              data['message'] ?? "Please check your email and try again!",
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
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Failed to send OTP"),
          content: const Text("Please check your email and try again!"),
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
                      'Login',
                      style: TextStyle(fontSize: 28, color: Colors.black),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _sendOtp,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Send OTP'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Get.toNamed(AppRoutes.adminlogin);
                        },
                        child: const Text(
                          'Sign in as Admin',
                          style: TextStyle(color: Colors.black),
                        ),
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
