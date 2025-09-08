import 'package:flutter/material.dart';
import 'package:myoffice_sunshine/utils/snackbar_message.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AttendanceRequest extends StatefulWidget {
  const AttendanceRequest({super.key});

  @override
  State<AttendanceRequest> createState() => _AttendanceRequestState();
}

class _AttendanceRequestState extends State<AttendanceRequest> {
  List<Map<String, dynamic>> attendanceRequests = [];
  String selectedFilter = 'all';
  String searchQuery = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAttendanceRequests();
  }

  Future<void> fetchAttendanceRequests() async {
    setState(() {
      isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        throw Exception('No token found');
      }

      final response = await http.get(
        Uri.parse('https://1.sunshineiot.in/api/v2/hr/services/all'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          attendanceRequests = List<Map<String, dynamic>>.from(data);
          attendanceRequests.sort((a, b) {
            final dateA = DateTime.parse(
              a['attendance_date'].split('-').reversed.join('-'),
            );
            final dateB = DateTime.parse(
              b['attendance_date'].split('-').reversed.join('-'),
            );
            return dateB.compareTo(dateA);
          });
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load attendance requests');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (!mounted) return;
      SnackbarUtils.showError(
        'Error fetching attendance requests: ${e.toString()}',
      );
    }
  }

  Future<void> refreshAfterAction() async {
    // Add a longer delay to ensure server has processed the action
    await Future.delayed(const Duration(seconds: 1));

    // Retry fetching up to 3 times with increasing delays
    for (int i = 0; i < 3; i++) {
      try {
        await fetchAttendanceRequests();
        break; // If successful, break the loop
      } catch (e) {
        if (i < 2) {
          // Don't wait after the last attempt
          await Future.delayed(Duration(milliseconds: 500 * (i + 1)));
        }
      }
    }
  }

  Future<void> handleRequest(int serviceId, int action) async {
    // Show loading indicator
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              action == 1
                  ? 'Processing acceptance...'
                  : 'Processing rejection...',
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        throw Exception('No token found');
      }

      final url = 'https://1.sunshineiot.in/api/v2/hr/services/action';
      final requestBody = {'service_id': serviceId, 'action': action};

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final message =
            data['message'] ??
            (action == 1 ? 'Request accepted' : 'Request rejected');
        final success = data['success'] == true;

        if (!mounted) return;

        // Clear the loading snackbar
        ScaffoldMessenger.of(context).clearSnackBars();

        // Show success/error message
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text(message),
        //     backgroundColor: success
        //         ? (action == 1 ? Colors.green : Colors.red)
        //         : Colors.orange,
        //     duration: const Duration(seconds: 3),
        //   ),
        // );

        if (success) {
          if (action == 1) {
            SnackbarUtils.showSuccess(message);
          } else {
            SnackbarUtils.showError(message);
          }
        } else {
          SnackbarUtils.showInfo(message);
        }

        // Always refresh the list after any response
        await fetchAttendanceRequests();
      } else {
        // Show the error message from the response if available
        String errorMsg = 'Failed to process request';
        try {
          final data = json.decode(response.body);
          if (data['message'] != null) errorMsg = data['message'];

          // Special handling for service not found error
          if (errorMsg.contains('service_id not in database')) {
            errorMsg =
                'This request has already been processed or is no longer available.';
            // Automatically refresh the list when this error occurs
            await fetchAttendanceRequests();
          }
        } catch (_) {}

        if (!mounted) return;

        // Clear the loading snackbar
        ScaffoldMessenger.of(context).clearSnackBars();

        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Error: $errorMsg'),
        //     backgroundColor: Colors.red,
        //     duration: const Duration(seconds: 4),
        //   ),
        // );
        SnackbarUtils.showError(errorMsg);
      }
    } catch (e) {
      if (!mounted) return;

      // Clear the loading snackbar
      ScaffoldMessenger.of(context).clearSnackBars();

      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Error: ${e.toString()}'),
      //     backgroundColor: Colors.red,
      //     duration: const Duration(seconds: 4),
      //   ),
      // );
      SnackbarUtils.showError('Error processing request: ${e.toString()}');
    }
  }

  String getServiceTypeText(int serviceType) {
    switch (serviceType) {
      case 4:
        return 'Extra Working Hour';
      case 3:
        return 'Work From Home';
      case 2:
        return 'Out Door Duty';
      case 1:
        return 'Applied for Missed Punch';
      default:
        return 'Missing Punch';
    }
  }

  List<Map<String, dynamic>> getFilteredRequests() {
    return attendanceRequests.where((request) {
      final matchesFilter =
          selectedFilter == 'all' ||
          request['service_type'].toString() == selectedFilter;
      final matchesSearch =
          searchQuery.isEmpty ||
          request['emp_id'].toString().toLowerCase().contains(
            searchQuery.toLowerCase(),
          ) ||
          request['emp_name'].toString().toLowerCase().contains(
            searchQuery.toLowerCase(),
          ) ||
          request['attendance_date'].toString().toLowerCase().contains(
            searchQuery.toLowerCase(),
          );
      return matchesFilter && matchesSearch;
    }).toList();
  }

  List<Widget> buildFilterSearchFields(bool isWide) {
    return [
      Expanded(
        child: DropdownButtonFormField<String>(
          value: selectedFilter,
          decoration: const InputDecoration(
            labelText: 'Filter Requests',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
            labelStyle: TextStyle(color: Colors.black),
          ),
          items: const [
            DropdownMenuItem(
              value: 'all',
              child: Text(
                'All Requests',
                style: TextStyle(color: Colors.black),
              ),
            ),
            DropdownMenuItem(
              value: '4',
              child: Text(
                'Extra Working Hours',
                style: TextStyle(color: Colors.black),
              ),
            ),
            DropdownMenuItem(
              value: '3',
              child: Text(
                'Work From Home',
                style: TextStyle(color: Colors.black),
              ),
            ),
            DropdownMenuItem(
              value: '2',
              child: Text(
                'Out Door Duty',
                style: TextStyle(color: Colors.black),
              ),
            ),
            DropdownMenuItem(
              value: '1',
              child: Text(
                'Applied for Missed Punch',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
          onChanged: (value) {
            setState(() {
              selectedFilter = value!;
            });
          },
          dropdownColor: Colors.white,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
          style: const TextStyle(color: Colors.black),
        ),
      ),
      SizedBox(width: isWide ? 16 : 0, height: isWide ? 0 : 16),
      Expanded(
        child: TextField(
          decoration: const InputDecoration(
            labelText: 'Search',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) {
            setState(() {
              searchQuery = value;
            });
          },
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        color: Colors.white,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(38),
                  spreadRadius: 2,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: RefreshIndicator(
                onRefresh: fetchAttendanceRequests,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 600;
                          return isWide
                              ? Row(children: buildFilterSearchFields(isWide))
                              : Column(
                                  children: buildFilterSearchFields(isWide),
                                );
                        },
                      ),
                      const SizedBox(height: 24),
                      if (isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (getFilteredRequests().isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Text(
                              'No Request from Employee Under you',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              Colors.grey.shade100,
                            ),
                            dataRowColor:
                                WidgetStateProperty.resolveWith<Color?>((
                                  Set<WidgetState> states,
                                ) {
                                  if (states.contains(WidgetState.selected)) {
                                    return Colors.grey.shade200;
                                  }
                                  return null;
                                }),
                            columnSpacing: 18,
                            horizontalMargin: 8,
                            columns: const [
                              DataColumn(
                                label: Text(
                                  'ID',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Employee Name',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Date',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'In Time',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Out Time',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Service',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Actions',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                            rows: getFilteredRequests().map((request) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      request['emp_id'].toString(),
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      request['emp_name'],
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      request['attendance_date'],
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      request['in_time'],
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      request['out_time'],
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      getServiceTypeText(
                                        request['service_type'],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () => handleRequest(
                                            request['service_id'],
                                            1,
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12.r),
                                            ),
                                            backgroundColor:
                                                Colors.green.shade600,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.check,
                                            size: 18,
                                          ),
                                          label: const Text(
                                            'Accept',
                                            style: TextStyle(fontSize: 13),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          onPressed: () => handleRequest(
                                            request['service_id'],
                                            0,
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.red.shade600,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12.r),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.close,
                                            size: 18,
                                          ),
                                          label: const Text(
                                            'Reject',
                                            style: TextStyle(fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
