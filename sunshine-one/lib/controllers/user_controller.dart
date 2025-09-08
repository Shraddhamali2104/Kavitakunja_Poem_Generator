import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myoffice_sunshine/models/employee_profile_model.dart';
import 'package:myoffice_sunshine/models/employee_model.dart';

class UserController extends GetxController {
  var currentUser = Rxn<EmployeeProfile>();
  final Rxn<Employee> currentEmployee = Rxn<Employee>();
  final RxBool isLoadingEmployee = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadUserFromPrefs(); // 🔁 Auto-load on app launch
  }

  /// ✅ Called after login or app start to load user using stored token
  Future<void> loadUserFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token != null) {
      try {
        final response = await http.get(
          Uri.parse('https://1.sunshineiot.in/api/v2/hr/employee/profile'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          final profileJson = jsonDecode(response.body);
          final empData = profileJson['employee'] ?? profileJson;

          setUser(empData);
          await fetchEmployeeDetailsWithUserId();
        } else {
          debugPrint("Failed to load profile: ${response.statusCode}");
        }
      } catch (e) {
        debugPrint(" Error loading profile from token: $e");
      }
    } else {
      debugPrint("⚠️ No token found in SharedPreferences");
    }
  }

  // Set user from API response and persist emp_id
  Future<void> setUser(Map<String, dynamic> json) async {
    currentUser.value = EmployeeProfile.fromJson(json);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('emp_id', currentUser.value!.empId);
  }

  // Clears user data and shared preferences
  void clearUser() async {
    currentUser.value = null;
    currentEmployee.value = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('emp_id');
    await prefs.remove('jwt_token');
  }

  int? get empId => currentUser.value?.empId;
  String get empName => currentUser.value?.empName ?? '';
  String get empProfilePic => currentUser.value?.empProfilePic ?? '';

  Future<void> fetchEmployeeDetailsWithUserId() async {
    try {
      final empId = currentUser.value?.empId;
      if (empId == null) {
        debugPrint('⚠️ empId is null. User not set.');
        return;
      }

      debugPrint('🔄 Fetching employee details for emp_id: $empId');
      isLoadingEmployee.value = true;

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        debugPrint(' Token not found in fetchEmployeeDetails');
        return;
      }

      final Uri url = Uri.parse(
        'https://1.sunshineiot.in/api/v2/hr/employee/all/',
      );
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          final matched = data.firstWhere(
            (e) => e['emp_id'].toString() == empId.toString(),
            orElse: () => null,
          );

          if (matched != null) {
            currentEmployee.value = Employee.fromJson(matched);
            debugPrint('✅ Employee details loaded for emp_id $empId');
            debugPrint('📋 Employee name: ${currentEmployee.value?.empName}');
            debugPrint('📋 Employee email: ${currentEmployee.value?.empEmailId}');
          } else {
            debugPrint('❌ Employee not found in list for emp_id $empId');
          }
        } else {
          debugPrint(' Unexpected data format: ${data.runtimeType}');
        }
      } else {
        debugPrint(' API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint(' Failed to fetch employee details: $e');
    } finally {
      isLoadingEmployee.value = false;
    }
  }
}