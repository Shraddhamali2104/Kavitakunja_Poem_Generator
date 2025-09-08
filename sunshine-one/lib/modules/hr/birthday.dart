import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BirthdayPage extends StatefulWidget {
  const BirthdayPage({super.key});

  @override
  BirthdayPageState createState() => BirthdayPageState();
}

class BirthdayPageState extends State<BirthdayPage> {
  List<Employee> employees = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchEmployeeData();
  }

  String getCurrentMonthName() {
    const monthNames = [
      "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December"
    ];
    return monthNames[DateTime.now().month - 1];
  }

  Future<void> fetchEmployeeData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwtToken = prefs.getString('jwt_token');

      if (jwtToken == null) {
        setState(() {
          errorMessage = 'Authentication token not found. Please login again.';
          isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('https://1.sunshineiot.in/api/v2/hr/employee/birthdays'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          employees = data.map((json) => Employee.fromJson(json)).toList()
            ..sort((a, b) => a.empDocel.compareTo(b.empDocel));
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Error fetching data. Status: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        errorMessage = 'Error fetching employee data: $error';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color bgColor = Colors.blueGrey[50]!;
    final Color cardColor = Colors.white;
    final Color borderColor = Colors.blueGrey[100]!;
    final Color textColor = Colors.blueGrey[900]!;
    final Color subTextColor = Colors.blueGrey[600]!;
    final Color accentColor = Colors.blueGrey[700]!;

    final int currentMonth = DateTime.now().month;
    final List<Employee> thisMonthEmployees = employees.where((emp) {
      try {
        // Parse emp_docel as dd-MM-yyyy
        final parts = emp.empDocel.split('-');
        if (parts.length == 3) {
          final month = int.tryParse(parts[1]);
          return month == currentMonth;
        }
        return false;
      } catch (_) {
        return false;
      }
    }).toList();

    return Container(
      width: double.infinity,
      color: bgColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Birthdays of Our Employees - ${getCurrentMonthName()}',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (isLoading)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ))
                else if (errorMessage.isNotEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Material(
                        color: Colors.blueGrey,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            errorMessage,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                  )
                else if (thisMonthEmployees.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text('No birthdays this month', style: TextStyle(fontSize: 18, color: subTextColor)),
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // Modern, minimal grid: more columns, less spacing, smaller cards
                      int crossAxisCount = 1;
                      if (constraints.maxWidth > 1200) {
                        crossAxisCount = 6;
                      } else if (constraints.maxWidth > 900) {
                        crossAxisCount = 5;
                      } else if (constraints.maxWidth > 700) {
                        crossAxisCount = 4;
                      } else if (constraints.maxWidth > 500) {
                        crossAxisCount = 3;
                      } else if (constraints.maxWidth > 350) {
                        crossAxisCount = 2;
                      }
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 0.78,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: thisMonthEmployees.length,
                        itemBuilder: (context, index) {
                          final employee = thisMonthEmployees[index];
                          return _buildEmployeeCardMinimal(employee, cardColor, borderColor, textColor, subTextColor, accentColor);
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool isValidImageUrl(String url) {
    final lowerUrl = url.toLowerCase();
    return url.isNotEmpty &&
        (lowerUrl.endsWith('.jpg') ||
         lowerUrl.endsWith('.jpeg') ||
         lowerUrl.endsWith('.png')) &&
        url.startsWith('http');
  }

  // Minimal, modern card
  Widget _buildEmployeeCardMinimal(Employee employee, Color cardColor, Color borderColor, Color textColor, Color subTextColor, Color accentColor) {
    return Material(
      elevation: 1,
      color: cardColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        hoverColor: Colors.blueGrey[50],
        child: Container(
          height: 180,
          width: 140,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 1.2),
                ),
                child: ClipOval(
                  child: isValidImageUrl(employee.empPassportSizePhoto)
                      ? Image.network(
                          employee.empPassportSizePhoto,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.person, size: 72, color: subTextColor);
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(child: CircularProgressIndicator(strokeWidth: 2, color: accentColor));
                          },
                        )
                      : Icon(Icons.person, size: 72, color: subTextColor),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                employee.empName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  letterSpacing: 0.1,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                '🎉 ${employee.empDocel}',
                style: TextStyle(
                  fontSize: 12,
                  color: subTextColor,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Employee {
  final int empId;
  final String empName;
  final String empPassportSizePhoto;
  final String empDocel;

  Employee({
    required this.empId,
    required this.empName,
    required this.empPassportSizePhoto,
    required this.empDocel,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      empId: json['emp_id'] ?? 0,
      empName: json['emp_name'] ?? '',
      empPassportSizePhoto: json['emp_passport_size_photo'] ?? '',
      empDocel: json['emp_docel'] ?? '',
    );
  }
}