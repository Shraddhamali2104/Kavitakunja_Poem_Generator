import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/employee_model.dart';

class EmployeeService {
  static final EmployeeService _instance = EmployeeService._internal();
  factory EmployeeService() => _instance;
  EmployeeService._internal();

  List<Employee>? _employees;
  bool _isLoading = false;
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  // Getters
  List<Employee>? get employees => _employees;
  bool get isLoading => _isLoading;
  bool get hasData => _employees != null;
  bool get isCacheValid => _lastFetchTime != null && 
      DateTime.now().difference(_lastFetchTime!) < _cacheDuration;

  // Fetch employees from API
  Future<List<Employee>?> fetchEmployees() async {
    // Return cached data if it's still valid
    if (isCacheValid && _employees != null) {
      return _employees;
    }

    if (_isLoading) {
      // Wait for ongoing request to complete
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _employees;
    }

    _isLoading = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('https://1.sunshineiot.in/api/v2/hr/employee/all'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _employees = data.map((e) => Employee.fromJson(e)).toList();
        _lastFetchTime = DateTime.now();
        return _employees;
      } else {
        throw Exception('Failed to fetch employees: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch employees: $e');
    } finally {
      _isLoading = false;
    }
  }

  // Force refresh employees (ignores cache)
  Future<List<Employee>?> refreshEmployees() async {
    _lastFetchTime = null;
    return await fetchEmployees();
  }

  // Clear cache
  void clearCache() {
    _employees = null;
    _lastFetchTime = null;
  }
} 