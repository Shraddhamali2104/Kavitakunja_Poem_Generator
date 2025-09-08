import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myoffice_sunshine/utils/snackbar_message.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:developer';

class Holiday {
  final String holidayDate;
  final String holidayName;
  final String holidayDescription;
  final String remarks;

  Holiday({
    required this.holidayDate,
    required this.holidayName,
    required this.holidayDescription,
    required this.remarks,
  });

  factory Holiday.fromJson(Map<String, dynamic> json) {
    return Holiday(
      holidayDate: json['holiday_date'],
      holidayName: json['holiday_name'],
      holidayDescription: json['holiday_description'] ?? '',
      remarks: json['remarks'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'holiday_date': holidayDate,
      'holiday_name': holidayName,
      'holiday_description': holidayDescription,
      'remarks': remarks,
    };
  }
}

class HolidayScreen extends StatefulWidget {
  const HolidayScreen({super.key});

  @override
  HolidayScreenState createState() => HolidayScreenState();
}

class HolidayScreenState extends State<HolidayScreen> {
  List<Holiday> holidays = [];
  DateTime currentDate = DateTime.now();
  bool isLoading = true;
  String? jwtToken;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      jwtToken = prefs.getString('jwt_token');
    });
    if (jwtToken != null) {
      await fetchHolidays();
    }
  }

  Future<void> fetchHolidays() async {
    try {
      log('Fetching holidays from API...');
      final response = await http.get(
        Uri.parse('https://1.sunshineiot.in/api/v2/hr/holiday'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      );

      log('Fetch response status: ${response.statusCode}');
      log('Fetch response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        log('Parsed holidays data: $data');
        log('Number of holidays fetched: ${data.length}');

        if (!mounted) return;

        setState(() {
          holidays = data.map((json) => Holiday.fromJson(json)).toList();
          isLoading = false;
        });

        log('Updated holidays list length: ${holidays.length}');
      } else {
        log('Fetch failed with status code: ${response.statusCode}');
        throw Exception('Failed to load holidays');
      }
    } catch (e) {
      log('Error in fetchHolidays: $e');
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      SnackbarUtils.showError('Error fetching holidays: $e');
    }
  }

  Future<(bool, String)> addHoliday(Holiday holiday) async {
    if (holiday.holidayName.trim().isEmpty ||
        holiday.holidayDate.trim().isEmpty) {
      return (false, 'Holiday title and date cannot be empty');
    }

    // Check for duplicate date in local list
    if (holidays.any((h) => h.holidayDate == holiday.holidayDate)) {
      return (false, 'A holiday for this date already exists.');
    }

    try {
      final response = await http.post(
        Uri.parse('https://1.sunshineiot.in/api/v2/hr/holiday'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(holiday.toJson()),
      );

      final Map<String, dynamic> res = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (res['success'] == true) {
          // Refresh the holidays list
          await fetchHolidays();
          return (true, 'Holiday added successfully');
        } else {
          String errorMsg = res['message'] ?? 'Failed to add holiday';
          // Handle specific database errors
          if (errorMsg.contains('Duplicate entry') ||
              errorMsg.contains('ER_DUP_ENTRY')) {
            errorMsg = 'A holiday for this date already exists.';
          }
          return (false, errorMsg);
        }
      } else {
        String errorMsg = res['message'] ?? 'Failed to add holiday';
        // Handle specific database errors
        if (errorMsg.contains('Duplicate entry') ||
            errorMsg.contains('ER_DUP_ENTRY')) {
          errorMsg = 'A holiday for this date already exists.';
        }
        return (false, errorMsg);
      }
    } catch (e) {
      return (false, 'Error adding holiday: $e');
    }
  }

  Future<(bool, String)> deleteHoliday(String date) async {
    try {
      log('Attempting to delete holiday with date: $date');
      final response = await http.delete(
        Uri.parse('https://1.sunshineiot.in/api/v2/hr/holiday'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: json.encode([
          {'holiday_date': date},
        ]),
      );

      log('Delete response status: ${response.statusCode}');
      log('Delete response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> res = json.decode(response.body);
        log('Parsed response: $res');

        final bool allSuccess = res.every(
          (item) => item['status'] == 'success',
        );

        if (allSuccess) {
          log('Delete successful, refreshing holidays list');
          await fetchHolidays();
          return (true, 'Holiday deleted successfully');
        } else {
          log('Delete failed - not all items returned success status');
          return (
            false,
            'Failed to delete holiday - server returned partial failure',
          );
        }
      } else {
        log('Delete failed with status code: ${response.statusCode}');
        return (
          false,
          'Failed to delete holiday - HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      log('Error in deleteHoliday: $e');
      return (false, 'Error deleting holiday: $e');
    }
  }

  Future<(bool, String)> updateHoliday(Holiday holiday) async {
    try {
      final response = await http.put(
        Uri.parse('https://1.sunshineiot.in/api/v2/hr/holiday'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(holiday.toJson()),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> res = json.decode(response.body);
        if (res['success'] == true) {
          await fetchHolidays();
          return (true, 'Holiday updated successfully');
        } else {
          final dynamic errorMsg = res['data']?['message'];
          final String message =
              errorMsg?.toString() ?? 'Failed to update holiday';
          return (false, message);
        }
      } else {
        return (false, 'Failed to update holiday');
      }
    } catch (e) {
      return (false, 'Error updating holiday: $e');
    }
  }

  void _showAddHolidayDialog() {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Add Holiday',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.black),
                decoration: const InputDecoration(
                  labelText: 'Holiday Title',
                  labelStyle: TextStyle(color: Colors.black),
                  hintText: 'Enter holiday title',
                  hintStyle: TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                style: const TextStyle(color: Colors.black),
                decoration: const InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: Colors.black),
                  hintText: 'Enter holiday description',
                  hintStyle: TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 2),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color: Colors.black,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('dd-MM-yyyy').format(selectedDate),
                      style: const TextStyle(color: Colors.black),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Select Date'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) {
                if (!mounted) return;
                SnackbarUtils.showInfo('Holiday title cannot be empty');
                return;
              }

              final formattedDate = DateFormat(
                'dd-MM-yyyy',
              ).format(selectedDate);

              final holiday = Holiday(
                holidayDate: formattedDate,
                holidayName: titleController.text.trim(),
                holidayDescription: descriptionController.text.trim(),
                remarks: '',
              );

              final (success, message) = await addHoliday(holiday);

              if (!mounted) return;
              SnackbarUtils.showInfo(message);

              if (success) {
                Get.back();
                // Refresh the page after successful addition
                await fetchHolidays();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditHolidayDialog(Holiday holiday) {
    final TextEditingController titleController = TextEditingController(
      text: holiday.holidayName,
    );
    final TextEditingController descriptionController = TextEditingController(
      text: holiday.holidayDescription,
    );

    DateTime selectedDate;
    try {
      selectedDate = DateFormat('dd-MM-yyyy').parse(holiday.holidayDate);
    } catch (e) {
      selectedDate = DateTime.now();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Edit Holiday',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.black),
                decoration: const InputDecoration(
                  labelText: 'Holiday Title',
                  labelStyle: TextStyle(color: Colors.black),
                  hintText: 'Enter holiday title',
                  hintStyle: TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                style: const TextStyle(color: Colors.black),
                decoration: const InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: Colors.black),
                  hintText: 'Enter holiday description',
                  hintStyle: TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 2),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color: Colors.black,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('dd-MM-yyyy').format(selectedDate),
                      style: const TextStyle(color: Colors.black),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Select Date'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            onPressed: () async {
              final formattedDate = DateFormat(
                'dd-MM-yyyy',
              ).format(selectedDate);

              final updatedHoliday = Holiday(
                holidayDate: formattedDate,
                holidayName: titleController.text.trim(),
                holidayDescription: descriptionController.text.trim(),
                remarks: holiday.remarks,
              );

              final (success, message) = await updateHoliday(updatedHoliday);

              if (!mounted) return;

              SnackbarUtils.showInfo(message);

              if (success) {
                SnackbarUtils.showSuccess(message);
                Get.back();
                // Refresh the page after successful update
                await fetchHolidays();
              } else {
                SnackbarUtils.showError(message);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildHolidayCard(
    List<Holiday> holidayGroup,
    String title,
    Color cardColor,
    Color textColor,
  ) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: cardColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Scrollable Holiday List
            Expanded(
              child: holidayGroup.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'No holidays in this category',
                          style: TextStyle(
                            color: textColor.withOpacity(0.6),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8.0),
                      itemCount: holidayGroup.length,
                      itemBuilder: (context, index) {
                        final holiday = holidayGroup[index];
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            title: Text(
                              holiday.holidayName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  holiday.holidayDate,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (holiday.holidayDescription.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    holiday.holidayDescription,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 16),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  onPressed: () =>
                                      _showEditHolidayDialog(holiday),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    size: 16,
                                    color: Colors.red,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  onPressed: () async {
                                    // Show confirmation dialog
                                    final bool?
                                    confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor: Colors.white,
                                        title: const Text(
                                          'Confirm Delete',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        content: Text(
                                          'Are you sure you want to delete the holiday "${holiday.holidayName}" on ${holiday.holidayDate}?',
                                          style: const TextStyle(
                                            color: Colors.black,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Get.back(result: false),
                                            child: const Text(
                                              'Cancel',
                                              style: TextStyle(
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Get.back(result: true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      log(
                                        'User confirmed delete for holiday: ${holiday.holidayName} on ${holiday.holidayDate}',
                                      );
                                      final (
                                        success,
                                        message,
                                      ) = await deleteHoliday(
                                        holiday.holidayDate,
                                      );

                                      if (!context.mounted) return;

                                      SnackbarUtils.showInfo(message);

                                      if (success) {
                                        SnackbarUtils.showSuccess(message);
                                        await fetchHolidays();
                                      } else {
                                        SnackbarUtils.showError(message);
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<List<Holiday>> _categorizeHolidays() {
    final DateTime now = DateTime.now();
    final DateTime currentYearStart = DateTime(now.year, 1, 1);
    final DateTime currentYearEnd = DateTime(now.year, 12, 31);
    final DateTime nextYearEnd = DateTime(now.year + 1, 12, 31);

    List<Holiday> pastHolidays = [];
    List<Holiday> upcomingHolidays = [];
    List<Holiday> nextYearHolidays = [];

    for (Holiday holiday in holidays) {
      try {
        DateTime holidayDateTime = DateFormat(
          'dd-MM-yyyy',
        ).parse(holiday.holidayDate);

        if (holidayDateTime.isBefore(now)) {
          // Past holidays (this year)
          if (holidayDateTime.isAfter(
            currentYearStart.subtract(const Duration(days: 1)),
          )) {
            pastHolidays.add(holiday);
          }
        } else if (holidayDateTime.isAfter(now) &&
            holidayDateTime.isBefore(
              currentYearEnd.add(const Duration(days: 1)),
            )) {
          // Upcoming holidays (this year)
          upcomingHolidays.add(holiday);
        } else if (holidayDateTime.isAfter(currentYearEnd)) {
          // Next year holidays
          nextYearHolidays.add(holiday);
        }
      } catch (e) {
        log('Error parsing date for holiday: ${holiday.holidayDate}');
        // Add to upcoming as fallback
        upcomingHolidays.add(holiday);
      }
    }

    // Sort each category by date
    pastHolidays.sort((a, b) {
      try {
        DateTime dateA = DateFormat('dd-MM-yyyy').parse(a.holidayDate);
        DateTime dateB = DateFormat('dd-MM-yyyy').parse(b.holidayDate);
        return dateB.compareTo(dateA); // Most recent first
      } catch (e) {
        return 0;
      }
    });

    upcomingHolidays.sort((a, b) {
      try {
        DateTime dateA = DateFormat('dd-MM-yyyy').parse(a.holidayDate);
        DateTime dateB = DateFormat('dd-MM-yyyy').parse(b.holidayDate);
        return dateA.compareTo(dateB); // Earliest first
      } catch (e) {
        return 0;
      }
    });

    nextYearHolidays.sort((a, b) {
      try {
        DateTime dateA = DateFormat('dd-MM-yyyy').parse(a.holidayDate);
        DateTime dateB = DateFormat('dd-MM-yyyy').parse(b.holidayDate);
        return dateA.compareTo(dateB); // Earliest first
      } catch (e) {
        return 0;
      }
    });

    return [pastHolidays, upcomingHolidays, nextYearHolidays];
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color.fromARGB(26, 158, 158, 158),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Holiday Management',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAddHolidayDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Add Holiday'),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: () {
                          final categorizedHolidays = _categorizeHolidays();
                          return [
                            _buildHolidayCard(
                              categorizedHolidays[0],
                              'Past Holidays\n(${categorizedHolidays[0].length})',
                              Colors.orange,
                              Colors.orange[800]!,
                            ),
                            _buildHolidayCard(
                              categorizedHolidays[1],
                              'Upcoming Holidays\n(${categorizedHolidays[1].length})',
                              Colors.green,
                              Colors.green[800]!,
                            ),
                            _buildHolidayCard(
                              categorizedHolidays[2],
                              'Next Year\n(${categorizedHolidays[2].length})',
                              Colors.blue,
                              Colors.blue[800]!,
                            ),
                          ];
                        }(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
