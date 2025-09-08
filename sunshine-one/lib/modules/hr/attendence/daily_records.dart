import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:myoffice_sunshine/modules/hr/attendence/widgets/attendance_dropdown.dart';
import 'package:myoffice_sunshine/utils/snackbar_message.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../routes/app_routes.dart';
import 'package:get/get.dart';

class DailyRecord extends StatefulWidget {
  const DailyRecord({super.key});

  @override
  State<DailyRecord> createState() => _DailyRecordState();
}

class _DailyRecordState extends State<DailyRecord> {
  DateTime selectedDate = DateTime.now();
  List<Map<String, dynamic>> presentEmployees = [];
  List<Map<String, dynamic>> absentEmployees = [];
  bool isLoading = true;
  late SharedPreferences prefs;

  @override
  void initState() {
    super.initState();
    _initializePrefs();
  }

  Future<void> _initializePrefs() async {
    prefs = await SharedPreferences.getInstance();
    fetchAttendanceData(selectedDate);
  }

  Future<void> fetchAttendanceData(DateTime date) async {
    setState(() {
      isLoading = true;
    });

    try {
      // Get the JWT token from SharedPreferences
      final String? token = prefs.getString('jwt_token');

      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.post(
        Uri.parse(
          'https://1.sunshineiot.in/api/v2/hr/attendance/present_absent',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'attendance_date': DateFormat('yyyy-MM-dd').format(date),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          presentEmployees = List<Map<String, dynamic>>.from(data['present']);
          absentEmployees = List<Map<String, dynamic>>.from(data['absent']);
          isLoading = false;
        });
      } else if (response.statusCode == 401) {
        // Handle unauthorized access
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception('Failed to load attendance data');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (!mounted) return;
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Error: ${e.toString()}'),
      //     backgroundColor: Colors.red,
      //     action: e.toString().contains('Session expired')
      //         ? SnackBarAction(
      //             label: 'Login',
      //             onPressed: () {
      //               // Navigate to login screen
      //               Get.offAllNamed(AppRoutes.login);
      //             },
      //           )
      //         : null,
      //   ),
      // );
      final errorMessage = 'Error: ${e.toString()}';

      if (e.toString().contains('Session expired')) {
        SnackbarUtils.showError('Session expired. Tap to login.');
        Future.delayed(Duration(milliseconds: 100), () {
          Get.snackbar(
            'Session expired',
            'Please log in again',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
            margin: EdgeInsets.all(16),
            onTap: (_) => Get.offAllNamed(AppRoutes.login),
            isDismissible: true,
          );
        });
      } else {
        SnackbarUtils.showError(errorMessage);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      fetchAttendanceData(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        color: Colors.white,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Navigation buttons for attendance subpages
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Attendance',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    AttendanceDropdown(),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                // Optionally set a minHeight or constraints if needed
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(26),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _selectDate(context),
                          icon: const Icon(
                            Icons.calendar_today,
                            color: Colors.black,
                          ),
                          label: Text(
                            DateFormat('dd MMM yyyy').format(selectedDate),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildAttendanceCard(
                              'Present',
                              presentEmployees.length,
                              presentEmployees,
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildAttendanceCard(
                              'Absent',
                              absentEmployees.length,
                              absentEmployees,
                              Colors.red,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceCard(
    String title,
    int count,
    List<Map<String, dynamic>> employees,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(77)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withAlpha(51),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (employees.isEmpty)
            Center(
              child: Text(
                'No one is $title',
                style: const TextStyle(
                  color: Colors.black54,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: employees.length,
              itemBuilder: (context, index) {
                final employee = employees[index];
                return Card(
                  elevation: 0,
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: Text(
                      employee['emp_name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      'ID: ${employee['emp_id']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// class _AttendanceDropdown extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withAlpha((0.08 * 255).toInt()),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//         border: Border.all(color: Colors.grey.shade200),
//       ),
//       child: PopupMenuButton<_AttendanceMenuItem>(
//         tooltip: 'Attendance Sections',
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         offset: const Offset(0, 40),
//         color: Colors.white,
//         elevation: 8,
//         onSelected: (item) => Get.toNamed(item.route),
//         itemBuilder: (context) => [
//           _buildMenuItem(
//             context,
//             _AttendanceMenuItem(
//               label: 'Daily Records',
//               icon: Icons.calendar_today,
//               route: '/dashboard/hr/attendance/daily',
//             ),
//           ),
//           _buildMenuItem(
//             context,
//             _AttendanceMenuItem(
//               label: 'Monthly by Employee',
//               icon: Icons.person,
//               route: '/dashboard/hr/attendance/monthly_employee',
//             ),
//           ),
//           _buildMenuItem(
//             context,
//             _AttendanceMenuItem(
//               label: 'Monthly Reports',
//               icon: Icons.assessment,
//               route: '/dashboard/hr/attendance/monthly_report',
//             ),
//           ),
//           _buildMenuItem(
//             context,
//             _AttendanceMenuItem(
//               label: 'Yearly Report',
//               icon: Icons.bar_chart,
//               route: '/dashboard/hr/attendance/yearly_report',
//             ),
//           ),
//         ],
//         child: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
//           decoration: BoxDecoration(
//             color: Colors.black,
//             borderRadius: BorderRadius.circular(10),
//           ),
//           child: Row(
//             mainAxisSize: MainAxisSize.min,
//             children: const [
//               Icon(Icons.menu, color: Colors.white, size: 22),
//               SizedBox(width: 8),
//               Text(
//                 'Sections',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontWeight: FontWeight.w600,
//                   fontSize: 15,
//                   letterSpacing: 0.2,
//                 ),
//               ),
//               SizedBox(width: 4),
//               Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   PopupMenuItem<_AttendanceMenuItem> _buildMenuItem(
//     BuildContext context,
//     _AttendanceMenuItem item,
//   ) {
//     return PopupMenuItem<_AttendanceMenuItem>(
//       value: item,
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(8),
//             decoration: BoxDecoration(
//               color: Colors.grey.shade100,
//               borderRadius: BorderRadius.circular(8),
//               border: Border.all(color: Colors.grey.shade200),
//             ),
//             child: Icon(item.icon, size: 20, color: Colors.black),
//           ),
//           const SizedBox(width: 14),
//           Text(
//             item.label,
//             style: const TextStyle(
//               fontWeight: FontWeight.w600,
//               fontSize: 15,
//               color: Colors.black,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _AttendanceMenuItem {
//   final String label;
//   final IconData icon;
//   final String route;
//   const _AttendanceMenuItem({
//     required this.label,
//     required this.icon,
//     required this.route,
//   });
// }
