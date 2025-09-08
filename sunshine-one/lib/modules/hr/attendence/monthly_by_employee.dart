import 'package:flutter/material.dart';
import 'package:myoffice_sunshine/modules/hr/attendence/widgets/attendance_dropdown.dart';
import 'package:myoffice_sunshine/utils/snackbar_message.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../controllers/options_controller.dart';
import 'package:dropdown_search/dropdown_search.dart';

class MonthlyByEmployee extends StatefulWidget {
  const MonthlyByEmployee({super.key});

  @override
  MonthlyByEmployeeState createState() => MonthlyByEmployeeState();
}

class MonthlyByEmployeeState extends State<MonthlyByEmployee> {
  // Only use month view, remove calendar format switch
  final CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<String, dynamic>? _attendanceData;
  List<Map<String, dynamic>> _employees = [];
  String? _selectedEmployeeId;
  bool _isLoading = false;
  Set<DateTime> _presentDays = {};
  List<Map<String, dynamic>> _monthlyAttendanceData = [];
  Set<DateTime> _absentDays = {};

  @override
  void initState() {
    super.initState();
    _initOptionsAndEmployees();
  }

  Future<void> _initOptionsAndEmployees() async {
    if (!OptionsController.to.hasData) {
      await OptionsController.to.fetchOptions();
    }
    await _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('https://1.sunshineiot.in/api/v2/hr/employee/all'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (!mounted) return;
        // Get the universal yes/no 'Yes' option id
        final yesId = OptionsController.to.getOptionIdByName('Yes');
        if (yesId == null) {
          setState(() {
            _employees = data
                .map(
                  (emp) => {
                    'emp_id': emp['emp_id'],
                    'emp_name': emp['emp_name'],
                  },
                )
                .toList();
          });
          return;
        }
        setState(() {
          _employees = data
              .where((emp) => emp['emp_active_status'] == yesId)
              .map(
                (emp) => {'emp_id': emp['emp_id'], 'emp_name': emp['emp_name']},
              )
              .toList();
        });
      }
    } catch (e) {
      if (!mounted) return;
      SnackbarUtils.showError('Error fetching employee $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchMonthlyAttendance(DateTime date) async {
    if (_selectedEmployeeId == null) return;

    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.post(
        Uri.parse('https://1.sunshineiot.in/api/v2/hr/attendance/by_month'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'emp_id': int.parse(_selectedEmployeeId!),
          'month': date.month,
          'year': date.year,
        }),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (!mounted) return;
        setState(() {
          _monthlyAttendanceData = List<Map<String, dynamic>>.from(data);
          _presentDays = data
              .where((record) {
                bool isPresent = false;
                final fields = [
                  'emp_basic_hrs',
                  'emp_ot_hrs',
                  'emp_od_hrs',
                  'emp_wfh_hrs',
                  'emp_extra_hrs',
                  'emp_missed_punch_hrs',
                  'admin_adjustment_hrs',
                ];
                for (final field in fields) {
                  if (record[field] != null && record[field] > 0) {
                    isPresent = true;
                    break;
                  }
                }
                return isPresent;
              })
              .map((record) {
                final dateParts = record['attendance_date'].split('-');
                return DateTime(
                  int.parse(dateParts[2]),
                  int.parse(dateParts[1]),
                  int.parse(dateParts[0]),
                );
              })
              .toSet();

          // Calculate absent days: all days before today in the current month that are not present
          final now = DateTime.now();
          _absentDays = {};
          if (date.year == now.year && date.month == now.month) {
            for (int d = 1; d < now.day; d++) {
              final dt = DateTime(date.year, date.month, d);
              if (!_presentDays.contains(dt)) {
                _absentDays.add(dt);
              }
            }
          } else {
            final lastDay = DateTime(date.year, date.month + 1, 0).day;
            for (int d = 1; d <= lastDay; d++) {
              final dt = DateTime(date.year, date.month, d);
              if (dt.isBefore(now) && !_presentDays.contains(dt)) {
                _absentDays.add(dt);
              }
            }
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      SnackbarUtils.showError('Error fetching monthly athendance $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _findAttendanceDataForDate(DateTime date) {
    // Find attendance data for the selected date from monthly data
    final dateString = DateFormat('dd-MM-yyyy').format(date);
    final attendanceRecord = _monthlyAttendanceData.firstWhere(
      (record) => record['attendance_date'] == dateString,
      orElse: () => <String, dynamic>{},
    );

    setState(() {
      _attendanceData = attendanceRecord.isNotEmpty ? attendanceRecord : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        color: Colors.white,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Monthly Employee',
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
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(26),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Employee Dropdown
                      DropdownSearch<String>(
                        items: _employees
                            .map(
                              (employee) =>
                                  '${employee['emp_id']} - ${employee['emp_name']}',
                            )
                            .toList(),
                        selectedItem: _selectedEmployeeId == null
                            ? null
                            : _employees
                                  .firstWhere(
                                    (e) =>
                                        e['emp_id'].toString() ==
                                        _selectedEmployeeId,
                                    orElse: () => {},
                                  )
                                  .isNotEmpty
                            ? '${_employees.firstWhere((e) => e['emp_id'].toString() == _selectedEmployeeId)['emp_id']} - ${_employees.firstWhere((e) => e['emp_id'].toString() == _selectedEmployeeId)['emp_name']}'
                            : null,
                        dropdownDecoratorProps: const DropDownDecoratorProps(
                          dropdownSearchDecoration: InputDecoration(
                            labelText: 'Select Employee',
                            hintText: 'Select an employee',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            labelStyle: TextStyle(color: Colors.black),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        popupProps: PopupProps.menu(
                          showSearchBox: true,
                          searchFieldProps: TextFieldProps(
                            decoration: InputDecoration(
                              hintText: 'Search employee...',
                              border: OutlineInputBorder(),
                            ),
                            style: TextStyle(color: Colors.black),
                          ),
                          menuProps: MenuProps(
                            backgroundColor: Colors.white,
                            elevation: 8,
                          ),
                          itemBuilder: (context, item, isSelected) => Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Text(
                              item,
                              style: const TextStyle(color: Colors.black),
                            ),
                          ),
                        ),
                        dropdownButtonProps: const DropdownButtonProps(
                          color: Colors.black,
                        ),
                        dropdownBuilder: (context, selectedItem) => Text(
                          selectedItem ?? 'Select an employee',
                          style: TextStyle(
                            color: selectedItem != null
                                ? Colors.black
                                : Colors.grey,
                          ),
                        ),
                        onChanged: (value) {
                          final empId = value?.split(' - ').first;
                          setState(() {
                            _selectedEmployeeId = empId;
                            _presentDays.clear();
                            _absentDays
                                .clear(); // Clear absent days when employee changes
                            _attendanceData = null;
                          });
                          if (empId != null && empId.isNotEmpty) {
                            _fetchMonthlyAttendance(_focusedDay);
                            if (_selectedDay != null) {
                              _findAttendanceDataForDate(_selectedDay!);
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Month Selector
                      Row(
                        children: [
                          // Previous Month Button
                          IconButton(
                            onPressed: () {
                              final newDate = DateTime(
                                _focusedDay.year,
                                _focusedDay.month - 1,
                                1,
                              );
                              setState(() {
                                _focusedDay = newDate;
                                _selectedDay = null;
                                _attendanceData = null;
                              });
                              if (_selectedEmployeeId != null) {
                                _fetchMonthlyAttendance(_focusedDay);
                              }
                            },
                            icon: const Icon(
                              Icons.chevron_left,
                              color: Colors.black,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.grey[200],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Current Month Display
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat('MMMM yyyy').format(_focusedDay),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Next Month Button
                          IconButton(
                            onPressed: () {
                              final newDate = DateTime(
                                _focusedDay.year,
                                _focusedDay.month + 1,
                                1,
                              );
                              setState(() {
                                _focusedDay = newDate;
                                _selectedDay = null;
                                _attendanceData = null;
                              });
                              if (_selectedEmployeeId != null) {
                                _fetchMonthlyAttendance(_focusedDay);
                              }
                            },
                            icon: const Icon(
                              Icons.chevron_right,
                              color: Colors.black,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.grey[200],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Select Month Button
                          ElevatedButton.icon(
                            onPressed: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: _focusedDay,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                                initialDatePickerMode: DatePickerMode.year,
                              );
                              if (picked != null) {
                                setState(() {
                                  _focusedDay = DateTime(
                                    picked.year,
                                    picked.month,
                                    1,
                                  );
                                  _selectedDay = null;
                                  _attendanceData = null;
                                });
                                if (_selectedEmployeeId != null) {
                                  _fetchMonthlyAttendance(_focusedDay);
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.date_range),
                            label: const Text('Select Month'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Calendar
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(26),
                              spreadRadius: 1,
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: TableCalendar(
                          firstDay: DateTime.utc(2020, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          calendarFormat: _calendarFormat, // always month
                          availableCalendarFormats: const {
                            CalendarFormat.month: 'Month',
                          }, // disables format switch
                          selectedDayPredicate: (day) {
                            return isSameDay(_selectedDay, day);
                          },
                          calendarStyle: CalendarStyle(
                            markersMaxCount: 1,
                            markerDecoration: const BoxDecoration(
                              color: Color.fromARGB(77, 76, 175, 80),
                              shape: BoxShape.circle,
                            ),
                            selectedDecoration: BoxDecoration(
                              color: Color.fromARGB(128, 33, 150, 243),
                              shape: BoxShape.circle,
                            ),
                            todayDecoration: BoxDecoration(
                              color: Color.fromARGB(77, 33, 150, 243),
                              shape: BoxShape.circle,
                            ),
                            defaultDecoration: BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            weekendDecoration: BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                          ),
                          calendarBuilders: CalendarBuilders(
                            defaultBuilder: (context, date, _) {
                              if (_presentDays.contains(
                                DateTime(date.year, date.month, date.day),
                              )) {
                                return Container(
                                  margin: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Color.fromARGB(77, 76, 175, 80),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${date.day}',
                                      style: const TextStyle(
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              if (_absentDays.contains(
                                DateTime(date.year, date.month, date.day),
                              )) {
                                return Container(
                                  margin: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${date.day}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return null;
                            },
                            selectedBuilder: (context, date, _) {
                              if (_presentDays.contains(
                                DateTime(date.year, date.month, date.day),
                              )) {
                                return Container(
                                  margin: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Color.fromARGB(128, 33, 150, 243),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${date.day}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return null;
                            },
                            todayBuilder: (context, date, _) {
                              if (_presentDays.contains(
                                DateTime(date.year, date.month, date.day),
                              )) {
                                return Container(
                                  margin: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Color.fromARGB(128, 76, 175, 80),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${date.day}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return null;
                            },
                          ),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                            _findAttendanceDataForDate(selectedDay);
                          },
                          // Remove onFormatChanged to disable format switching
                          onPageChanged: (focusedDay) {
                            _focusedDay = focusedDay;
                            if (_selectedEmployeeId != null) {
                              _fetchMonthlyAttendance(focusedDay);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Attendance Details
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (_selectedEmployeeId == null)
                        const Center(
                          child: Text(
                            'Please select an employee',
                            style: TextStyle(fontSize: 16, color: Colors.black),
                          ),
                        )
                      else if (_selectedDay != null &&
                          _selectedDay!.weekday == DateTime.sunday) ...[
                        if (_attendanceData != null &&
                            ((_attendanceData!['emp_basic_hrs'] ?? 0) > 0 ||
                                (_attendanceData!['emp_ot_hrs'] ?? 0) > 0 ||
                                (_attendanceData!['emp_od_hrs'] ?? 0) > 0 ||
                                (_attendanceData!['emp_wfh_hrs'] ?? 0) > 0 ||
                                (_attendanceData!['emp_extra_hrs'] ?? 0) > 0 ||
                                (_attendanceData!['emp_missed_punch_hrs'] ??
                                        0) >
                                    0 ||
                                (_attendanceData!['admin_adjustment_hrs'] ??
                                        0) >
                                    0))
                          Card(
                            color: Colors.white,
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Daily Attendance Details',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildDetailRow(
                                    'Basic Hours',
                                    '${_attendanceData!['emp_basic_hrs'] ?? 0} hrs',
                                    textColor: Colors.black,
                                  ),
                                  _buildDetailRow(
                                    'OT Hours',
                                    '${_attendanceData!['emp_ot_hrs'] ?? 0} hrs',
                                    textColor: Colors.black,
                                  ),
                                  _buildDetailRow(
                                    'OD Hours',
                                    '${_attendanceData!['emp_od_hrs'] ?? 0} hrs',
                                    textColor: Colors.black,
                                  ),
                                  _buildDetailRow(
                                    'WFH Hours',
                                    '${_attendanceData!['emp_wfh_hrs'] ?? 0} hrs',
                                    textColor: Colors.black,
                                  ),
                                  _buildDetailRow(
                                    'Extra Hours',
                                    '${_attendanceData!['emp_extra_hrs'] ?? 0} hrs',
                                    textColor: Colors.black,
                                  ),
                                  _buildDetailRow(
                                    'Missed Punch Hours',
                                    '${_attendanceData!['emp_missed_punch_hrs'] ?? 0} hrs',
                                    textColor: Colors.black,
                                  ),
                                  _buildDetailRow(
                                    'Admin Adjustment Hours',
                                    '${_attendanceData!['admin_adjustment_hrs'] ?? 0} hrs',
                                    textColor: Colors.black,
                                  ),
                                  const Divider(height: 24),
                                  _buildDetailRow(
                                    'Total Working Hours',
                                    '${_attendanceData!['emp_total_working_hrs'] ?? 0} hrs',
                                    isTotal: true,
                                    textColor: Colors.black,
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Card(
                            color: Colors.white,
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: const [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.orange,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    "It's Sunday. No Working.",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ] else if (_attendanceData != null)
                        Card(
                          color: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Daily Attendance Details',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildDetailRow(
                                  'Basic Hours',
                                  '${_attendanceData!['emp_basic_hrs'] ?? 0} hrs',
                                  textColor: Colors.black,
                                ),
                                _buildDetailRow(
                                  'OT Hours',
                                  '${_attendanceData!['emp_ot_hrs'] ?? 0} hrs',
                                  textColor: Colors.black,
                                ),
                                _buildDetailRow(
                                  'OD Hours',
                                  '${_attendanceData!['emp_od_hrs'] ?? 0} hrs',
                                  textColor: Colors.black,
                                ),
                                _buildDetailRow(
                                  'WFH Hours',
                                  '${_attendanceData!['emp_wfh_hrs'] ?? 0} hrs',
                                  textColor: Colors.black,
                                ),
                                _buildDetailRow(
                                  'Extra Hours',
                                  '${_attendanceData!['emp_extra_hrs'] ?? 0} hrs',
                                  textColor: Colors.black,
                                ),
                                _buildDetailRow(
                                  'Missed Punch Hours',
                                  '${_attendanceData!['emp_missed_punch_hrs'] ?? 0} hrs',
                                  textColor: Colors.black,
                                ),
                                _buildDetailRow(
                                  'Admin Adjustment Hours',
                                  '${_attendanceData!['admin_adjustment_hrs'] ?? 0} hrs',
                                  textColor: Colors.black,
                                ),
                                const Divider(height: 24),
                                _buildDetailRow(
                                  'Total Working Hours',
                                  '${_attendanceData!['emp_total_working_hrs'] ?? 0} hrs',
                                  isTotal: true,
                                  textColor: Colors.black,
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (_monthlyAttendanceData.isNotEmpty)
                        Card(
                          color: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Monthly Overview - ${DateFormat('MMMM yyyy').format(_focusedDay)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildDetailRow(
                                  'Total Working Days',
                                  '${_presentDays.length} days',
                                  textColor: Colors.black,
                                ),
                                _buildDetailRow(
                                  'Calendar Days',
                                  '${DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day} days',
                                  textColor: Colors.black,
                                ),
                                _buildDetailRow(
                                  'Attendance Rate',
                                  '${((_presentDays.length / DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day) * 100).toStringAsFixed(1)}%',
                                  textColor: Colors.black,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: const BoxDecoration(
                                        color: Color.fromARGB(77, 76, 175, 80),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Present',
                                      style: TextStyle(color: Colors.black),
                                    ),
                                    SizedBox(width: 16),
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Absent (past days)',
                                      style: TextStyle(color: Colors.black),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Click on any marked date to view detailed attendance',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        const Center(
                          child: Text(
                            'No attendance data available for this month',
                            style: TextStyle(fontSize: 16, color: Colors.black),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isTotal = false,
    Color textColor = Colors.black,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
