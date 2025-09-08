import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:myoffice_sunshine/utils/snackbar_message.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:myoffice_sunshine/controllers/user_controller.dart';

class OtpPage extends StatefulWidget {
  const OtpPage({super.key});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  int _secondsRemaining = 180;
  Timer? _timer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsRemaining = 180;
    _canResend = false;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        setState(() => _canResend = true);
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final String? email = prefs.getString('emp_email_id');
    final String otp = _otpController.text.trim();

    final response = await http.post(
      Uri.parse("https://1.sunshineiot.in/api/v2/hr/employee/auth/verify-otp"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"emp_email_id": email, "otp": otp}),
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['token'] != null) {
        final token = data['token'];
        await prefs.setString('jwt_token', token);

        /// 🔹 Fetch profile
        final profileResponse = await http.get(
          Uri.parse('https://1.sunshineiot.in/api/v2/hr/employee/profile'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (profileResponse.statusCode == 200) {
          final profileJson = jsonDecode(profileResponse.body);
          final empData = profileJson['employee'] ?? profileJson;

          final userController = Get.find<UserController>();
          await userController.setUser(empData);

          await userController.fetchEmployeeDetailsWithUserId();

          if (userController.currentUser.value != null) {
            if (mounted) {
              Get.offAllNamed('/dashboard');
            }
          }
        } else {
          _showError("Failed to load profile after OTP.");
        }
      } else {
        _showError(data['message'] ?? "Invalid OTP. Please try again!");
      }
    } else {
      _showError("Invalid OTP. Please try again!");
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("OTP Verification Failed"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _resendOtp() async {
    setState(() {
      _canResend = false;
      _secondsRemaining = 30;
    });
    _startTimer();

    final prefs = await SharedPreferences.getInstance();
    final String? email = prefs.getString('emp_email_id');

    await http.post(
      Uri.parse("https://1.sunshineiot.in/api/v2/hr/employee/auth/send-otp"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"emp_email_id": email}),
    );

    if (mounted) {
      SnackbarUtils.showSuccess("A new OTP has been sent to your email.");
      await Future.delayed(const Duration(milliseconds: 1000));
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
                      'Enter OTP',
                      style: TextStyle(fontSize: 28, color: Colors.black),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _otpController,
                      decoration: const InputDecoration(labelText: 'OTP'),
                    ),
                    const SizedBox(height: 20),
                    if (!_canResend)
                      Text(
                        'Resend OTP in ${_secondsRemaining ~/ 60}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    if (_canResend)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _resendOtp,
                          child: const Text('Resend OTP'),
                        ),
                      ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verifyOtp,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Verify & Proceed'),
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
