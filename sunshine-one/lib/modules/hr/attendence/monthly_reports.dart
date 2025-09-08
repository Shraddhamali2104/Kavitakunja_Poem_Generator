import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:myoffice_sunshine/modules/hr/attendence/widgets/attendance_dropdown.dart';
import 'package:myoffice_sunshine/utils/snackbar_message.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:universal_html/html.dart' as html;
import '../../../models/option_model.dart';
import '../../../controllers/options_controller.dart';
import 'package:get/get.dart';

class MonthlyReport extends StatefulWidget {
  const MonthlyReport({super.key});

  @override
  MonthlyReportState createState() => MonthlyReportState();
}

class MonthlyReportState extends State<MonthlyReport> {
  DateTime? _selectedMonth;
  List<ThresholdEmployee> _thresholdEmployees = [];
  bool _isLoading = false;
  bool _thresholdDataLoaded = false;
  int? _selectedAttendanceTypeId; // Option ID for monthly/yearly

  String? _startMonthLabel; // New: for start_month from API
  String? _endMonthLabel; // New: for end_month from API

  late final OptionsController _optionsController;
  // Removed: List<Option> _attendanceTypeOptions = [];

  // New: Toggle for monthly/yearly export
  int _isForYearly = 0; // 0 = monthly, 1 = yearly

  // Work details mapping similar to the JavaScript version
  final Map<String, String> workDetailsMapping = {
    'emp_basic_hrs': 'Basic Hours',
    'emp_extra_hrs': 'Extra Working Hours',
    'emp_missed_punch_hrs': 'Missed Punch Hours',
    'emp_od_hrs': 'OD Hours',
    'emp_ot_hrs': 'OT Hours',
    'emp_wfh_hrs': 'WFH Hours',
    'emp_total_working_hrs': 'Total Working Hours',
  };

  @override
  void initState() {
    super.initState();
    // Set default to previous month
    final now = DateTime.now();
    final prevMonth = DateTime(now.year, now.month - 1, 1);
    _selectedMonth = prevMonth;
    _optionsController = OptionsController.to;
    // Ensure options are loaded before fetching threshold data
    Future.microtask(() async {
      if (!_optionsController.hasData) {
        await _optionsController.fetchOptions();
      }
      debugPrint(
        'DEBUG: attendanceTypeOptions: ${_optionsController.attendanceTypeOptions}',
      );
      _fetchThresholdData();
    });
  }

  // Removed: _loadOptionsAndInit and _initAttendanceTypeOptions

  Future<void> _fetchThresholdData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('https://1.sunshineiot.in/api/v2/hr/attendance/threshold'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (!mounted) return;
        // New API: extract 'data', 'start_month', 'end_month'
        final employeesJson = data['data'] as List<dynamic>? ?? [];
        setState(() {
          _thresholdEmployees = employeesJson
              .map((e) => ThresholdEmployee.fromJson(e))
              .toList();
          _thresholdDataLoaded = true;
          _startMonthLabel = data['start_month'] as String?;
          _endMonthLabel = data['end_month'] as String?;
        });
        debugPrint('DEBUG: threshold employees loaded: $_thresholdEmployees');
        debugPrint(
          'DEBUG: filtered threshold employees: $_filteredThresholdEmployees',
        );
      } else {
        debugPrint('Error  [31m${response.statusCode} [0m: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching threshold data: $e');
    }
  }

  List<ThresholdEmployee> get _filteredThresholdEmployees {
    if (_selectedAttendanceTypeId == null) return [];
    return _thresholdEmployees
        .where((emp) => emp.empAttendanceType == _selectedAttendanceTypeId)
        .toList();
  }

  Future<void> _exportToExcel() async {
    if (_selectedMonth == null) {
      if (!mounted) return;
      SnackbarUtils.showError('Please select a month and year.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final year = _selectedMonth!.year;
      final month = _selectedMonth!.month;
      final attendanceData = {
        "month": month,
        "year": year,
        "isForYearly": _isForYearly, // Pass the toggle value
      };
      final response = await http.post(
        Uri.parse(
          'https://1.sunshineiot.in/api/v2/hr/attendance/processed_monthly',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(attendanceData),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final employees = (data as List<dynamic>? ?? [])
            .map((e) => MonthlyReportEmployee.fromJson(e))
            .toList();
        if (employees.isEmpty) {
          if (!mounted) return;
          SnackbarUtils.showError('No data to export');
          return;
        }
        // Now export to Excel
        final monthStr = month.toString().padLeft(2, '0');
        final fileName = _isForYearly == 1
            ? '$year-Attendance.xlsx'
            : '$year-${monthStr}_Attendance.xlsx';
        final totalDaysInMonth = DateTime(year, month + 1, 0).day;
        final excel = excel_pkg.Excel.createExcel();
        final sheet = excel['Monthly Attendance'];
        // Set 'Monthly Attendance' as the default sheet
        excel.setDefaultSheet('Monthly Attendance');
        sheet
                .cell(
                  excel_pkg.CellIndex.indexByColumnRow(
                    columnIndex: 0,
                    rowIndex: 0,
                  ),
                )
                .value =
            'Employee Name';
        sheet
                .cell(
                  excel_pkg.CellIndex.indexByColumnRow(
                    columnIndex: 1,
                    rowIndex: 0,
                  ),
                )
                .value =
            'Employee ID';
        sheet
                .cell(
                  excel_pkg.CellIndex.indexByColumnRow(
                    columnIndex: 2,
                    rowIndex: 0,
                  ),
                )
                .value =
            'Work Detail';
        for (int day = 1; day <= totalDaysInMonth; day++) {
          final date = '$year-$monthStr-${day.toString().padLeft(2, '0')}';
          sheet
                  .cell(
                    excel_pkg.CellIndex.indexByColumnRow(
                      columnIndex: day + 2,
                      rowIndex: 0,
                    ),
                  )
                  .value =
              date;
        }
        int currentRow = 1;
        for (var employee in employees) {
          final empName = employee.empName;
          final empId = employee.empId;
          final attendanceRecords = employee.attendanceRecords;
          MonthlyAttendanceRecord findRecord(int day) {
            return attendanceRecords.firstWhere(
              (r) =>
                  r.attendanceDate?.substring(0, 10) ==
                  '$year-$monthStr-${day.toString().padLeft(2, '0')}',
              orElse: () => MonthlyAttendanceRecord(),
            );
          }

          sheet
                  .cell(
                    excel_pkg.CellIndex.indexByColumnRow(
                      columnIndex: 0,
                      rowIndex: currentRow,
                    ),
                  )
                  .value =
              '$empName (EID: $empId)';
          sheet
                  .cell(
                    excel_pkg.CellIndex.indexByColumnRow(
                      columnIndex: 1,
                      rowIndex: currentRow,
                    ),
                  )
                  .value =
              empId;
          currentRow++;
          for (var entry in workDetailsMapping.entries) {
            sheet
                    .cell(
                      excel_pkg.CellIndex.indexByColumnRow(
                        columnIndex: 0,
                        rowIndex: currentRow,
                      ),
                    )
                    .value =
                '';
            sheet
                    .cell(
                      excel_pkg.CellIndex.indexByColumnRow(
                        columnIndex: 1,
                        rowIndex: currentRow,
                      ),
                    )
                    .value =
                '';
            sheet
                    .cell(
                      excel_pkg.CellIndex.indexByColumnRow(
                        columnIndex: 2,
                        rowIndex: currentRow,
                      ),
                    )
                    .value =
                entry.value;
            for (int day = 1; day <= totalDaysInMonth; day++) {
              final value = getAttendanceValueByKey(findRecord(day), entry.key);
              sheet
                      .cell(
                        excel_pkg.CellIndex.indexByColumnRow(
                          columnIndex: day + 2,
                          rowIndex: currentRow,
                        ),
                      )
                      .value =
                  value;
            }
            currentRow++;
          }
          currentRow++;
        }
        final bytes = excel.encode()!;
        if (kIsWeb) {
          final blob = html.Blob([bytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          html.AnchorElement(href: url)
            ..setAttribute('download', fileName)
            ..click();
          html.Url.revokeObjectUrl(url);
          if (!mounted) return;
          SnackbarUtils.showInfo('Excel file downloaded: $fileName');
        } else {
          final directory = await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/$fileName');
          await file.writeAsBytes(bytes);
          if (!mounted) return;
          SnackbarUtils.showInfo('Excel file downloaded: $fileName');
        }
      } else if (response.statusCode == 409) {
        if (!mounted) return;
        // Check for specific error message in response body
        String errorMsg = 'Report generation failed: Month not over!!';
        try {
          final body = response.body;
          if (body.contains('Current month not processed')) {
            errorMsg = 'Current month not processed !! Choose Last month';
          }
        } catch (_) {}
        SnackbarUtils.showError(errorMsg);
        return;
      } else {
        if (!mounted) return;
        // Show a user-friendly error message instead of JSON
        String errorMsg =
            'Export failed. Please try again later or contact support.';
        try {
          final body = response.body;
          if (body.contains('not processed')) {
            errorMsg = 'Current month not processed !! Choose Last month';
          } else if (body.contains('not found')) {
            errorMsg = 'No data found for the selected period.';
          }
        } catch (_) {}
        SnackbarUtils.showError(errorMsg);
      }
    } catch (e) {
      if (!mounted) return;
      SnackbarUtils.showError('Error exporting to Excel: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                      'Monthly Report',
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
              Obx(() {
                final attendanceTypeOptions =
                    _optionsController.attendanceTypeOptions;
                debugPrint(
                  'DEBUG: attendanceTypeOptions (build): $attendanceTypeOptions',
                );
                // Show loading spinner if options are not loaded
                if (_optionsController.isLoading ||
                    attendanceTypeOptions.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                // Set default if not set and options are loaded
                if (_selectedAttendanceTypeId == null &&
                    attendanceTypeOptions.isNotEmpty) {
                  // Try to find the 'Month' or 'Monthly' option
                  final monthOption = attendanceTypeOptions.firstWhere(
                    (o) => o.optionName.toLowerCase().contains('month'),
                    orElse: () => attendanceTypeOptions.first,
                  );
                  _selectedAttendanceTypeId = monthOption.optionId;
                }
                final selectedType = attendanceTypeOptions.isNotEmpty
                    ? attendanceTypeOptions.firstWhere(
                        (o) => o.optionId == _selectedAttendanceTypeId,
                        orElse: () => Option(optionId: -1, optionName: ''),
                      )
                    : Option(optionId: -1, optionName: '');
                final selectedTypeName = selectedType.optionName;
                debugPrint(
                  'DEBUG: Selected type ID:  [32m [1m$_selectedAttendanceTypeId [0m',
                );
                debugPrint(
                  'DEBUG: Filtered employees: $_filteredThresholdEmployees',
                );
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Controls
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Select Month and Year: ',
                            style: TextStyle(color: Colors.black),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _pickYearMonth,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              _selectedMonth != null
                                  ? DateFormat(
                                      'MMMM yyyy',
                                    ).format(_selectedMonth!)
                                  : 'Select Month',
                            ),
                          ),
                          const SizedBox(width: 24),
                          // Enhanced Monthly/Yearly Toggle
                          _EnhancedToggle(
                            isForYearly: _isForYearly,
                            onChanged: (val) =>
                                setState(() => _isForYearly = val),
                          ),
                          const SizedBox(width: 24),
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _exportToExcel,
                            icon: const Icon(Icons.download, size: 20),
                            label: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Export to Excel',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                          ),
                          const Spacer(),
                          // Monthly/Yearly toggle for threshold (existing, do not change)
                          if (attendanceTypeOptions.isNotEmpty)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: attendanceTypeOptions
                                    .where(
                                      (option) =>
                                          option.optionName.toLowerCase() !=
                                              'na' &&
                                          option.optionName.toLowerCase() !=
                                              'n/a',
                                    )
                                    .map((option) {
                                      final isSelected =
                                          _selectedAttendanceTypeId ==
                                          option.optionId;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: ChoiceChip(
                                          label: Text(
                                            option.optionName,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.blue,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                          selected: isSelected,
                                          onSelected: (selected) {
                                            if (selected) {
                                              setState(() {
                                                _selectedAttendanceTypeId =
                                                    option.optionId;
                                              });
                                            }
                                          },
                                          selectedColor: Colors.blue,
                                          backgroundColor: Colors.white,
                                          side: BorderSide(
                                            color: Colors.blue,
                                            width: isSelected ? 0 : 1,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                      );
                                    })
                                    .toList(),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Average Range Label (move to above list, left-aligned, clean)
                      if (_thresholdDataLoaded &&
                          _startMonthLabel != null &&
                          _endMonthLabel != null)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: 8.0,
                            left: 2.0,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Average From ${_startMonthLabel!} - ${_endMonthLabel!}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      // Legend for punch mandatory symbols
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0, left: 2.0),
                        child: Row(
                          children: [
                            const Icon(Icons.star, color: Colors.red, size: 16),
                            const SizedBox(width: 4),
                            const Text(
                              'Punch Mandatory',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Punch Not Mandatory',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Threshold Statistics
                      if (_thresholdDataLoaded &&
                          attendanceTypeOptions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(
                                  (0.04 * 255).round(),
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedTypeName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _buildStatCard(
                                    'Met Threshold',
                                    _filteredThresholdEmployees
                                        .where((emp) => emp.statusFlag == 1)
                                        .length,
                                    Colors.green,
                                  ),
                                  const SizedBox(width: 16),
                                  _buildStatCard(
                                    'Below Threshold',
                                    _filteredThresholdEmployees
                                        .where((emp) => emp.statusFlag == 0)
                                        .length,
                                    Colors.red,
                                  ),
                                  const SizedBox(width: 16),
                                  _buildStatCard(
                                    'Total',
                                    _filteredThresholdEmployees.length,
                                    Colors.blue,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                      // Show threshold employees list
                      if (_thresholdDataLoaded &&
                          attendanceTypeOptions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(
                                  (0.04 * 255).round(),
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 8,
                                ),
                                child: Row(
                                  children: const [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Employee Name',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        'Employee ID',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        'Avg Hours',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        'Threshold',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        'Status',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1, thickness: 1),
                              ..._filteredThresholdEmployees.map(
                                (employee) =>
                                    _ThresholdEmployeeRow(employee: employee),
                              ),
                            ],
                          ),
                        ),

                      // Show only employee names as clickable ListTiles after data is loaded
                      // Remove employee view functionality and just show a message or nothing
                      if (!_isLoading)
                        SizedBox(
                          height: 200,
                          child: Center(
                            child: Text(
                              'Select a month and click Export to Excel to download the monthly report',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  double getAttendanceValueByKey(MonthlyAttendanceRecord record, String key) {
    switch (key) {
      case 'emp_basic_hrs':
        return record.empBasicHrs;
      case 'emp_extra_hrs':
        return record.empExtraHrs;
      case 'emp_missed_punch_hrs':
        return record.empMissedPunchHrs;
      case 'emp_od_hrs':
        return record.empOdHrs;
      case 'emp_ot_hrs':
        return record.empOtHrs;
      case 'emp_wfh_hrs':
        return record.empWfhHrs;
      case 'emp_total_working_hrs':
        return record.empTotalWorkingHrs;
      default:
        return 0.0;
    }
  }

  Future<void> _pickYearMonth() async {
    final now = DateTime.now();
    int selectedYear = _selectedMonth?.year ?? now.year;
    int selectedMonth = _selectedMonth?.month ?? now.month;
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        int tempYear = selectedYear;
        int tempMonth = selectedMonth;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Month and Year'),
              content: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DropdownButton<int>(
                    value: tempYear,
                    items: List.generate(10, (i) => now.year - 5 + i)
                        .map(
                          (y) => DropdownMenuItem(
                            value: y,
                            child: Text(y.toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (y) {
                      if (y != null) setState(() => tempYear = y);
                    },
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<int>(
                    value: tempMonth,
                    items: List.generate(12, (i) => i + 1)
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(
                              DateFormat('MMMM').format(DateTime(0, m)),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (m) {
                      if (m != null) setState(() => tempMonth = m);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () =>
                      Get.back(result: DateTime(tempYear, tempMonth)),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
      // Do NOT fetch here, only update selection
    }
  }
}

class ThresholdEmployee {
  final int empId;
  final String empName;
  final int empAttendanceType;
  final double avgMonthlyHours;
  final String thresholdHours;
  final int statusFlag;
  final int isPunchMandatory;

  ThresholdEmployee({
    required this.empId,
    required this.empName,
    required this.empAttendanceType,
    required this.avgMonthlyHours,
    required this.thresholdHours,
    required this.statusFlag,
    required this.isPunchMandatory,
  });

  factory ThresholdEmployee.fromJson(Map<String, dynamic> json) {
    return ThresholdEmployee(
      empId: json['emp_id'] ?? 0,
      empName: json['emp_name'] ?? '',
      empAttendanceType: json['emp_attendance_type'] ?? 0,
      avgMonthlyHours: (json['avg_monthly_hours'] ?? 0)?.toDouble() ?? 0.0,
      thresholdHours: (json['threshold_hours'] != null)
          ? json['threshold_hours'].toString()
          : '0',
      statusFlag: json['status_flag'] ?? 0,
      isPunchMandatory: json['is_punch_mandatory'] ?? 0,
    );
  }
}

class MonthlyReportEmployee {
  final String empName;
  final int empId;
  final List<MonthlyAttendanceRecord> attendanceRecords;

  MonthlyReportEmployee({
    required this.empName,
    required this.empId,
    required this.attendanceRecords,
  });

  factory MonthlyReportEmployee.fromJson(Map<String, dynamic> json) {
    return MonthlyReportEmployee(
      empName: json['emp_name'] ?? '',
      empId: json['emp_id'] ?? 0,
      attendanceRecords: (json['attendance_records'] as List<dynamic>? ?? [])
          .map((e) => MonthlyAttendanceRecord.fromJson(e))
          .toList(),
    );
  }
}

class MonthlyAttendanceRecord {
  final String? attendanceDate;
  final double empBasicHrs;
  final double empExtraHrs;
  final double empMissedPunchHrs;
  final double empOdHrs;
  final double empOtHrs;
  final double empWfhHrs;
  final double empTotalWorkingHrs;

  MonthlyAttendanceRecord({
    this.attendanceDate,
    this.empBasicHrs = 0.0,
    this.empExtraHrs = 0.0,
    this.empMissedPunchHrs = 0.0,
    this.empOdHrs = 0.0,
    this.empOtHrs = 0.0,
    this.empWfhHrs = 0.0,
    this.empTotalWorkingHrs = 0.0,
  });

  factory MonthlyAttendanceRecord.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return MonthlyAttendanceRecord(
      attendanceDate: json['attendance_date'],
      empBasicHrs: parseDouble(json['emp_basic_hrs']),
      empExtraHrs: parseDouble(json['emp_extra_hrs']),
      empMissedPunchHrs: parseDouble(json['emp_missed_punch_hrs']),
      empOdHrs: parseDouble(json['emp_od_hrs']),
      empOtHrs: parseDouble(json['emp_ot_hrs']),
      empWfhHrs: parseDouble(json['emp_wfh_hrs']),
      empTotalWorkingHrs: parseDouble(json['emp_total_working_hrs']),
    );
  }
}

class _ThresholdEmployeeRow extends StatelessWidget {
  final ThresholdEmployee employee;

  const _ThresholdEmployeeRow({required this.employee});

  @override
  Widget build(BuildContext context) {
    final isMet = employee.statusFlag == 1;
    final avg = employee.avgMonthlyHours;
    final threshold = double.tryParse(employee.thresholdHours) ?? 0;
    double percent = 0;
    if (threshold > 0) {
      percent = (avg / threshold) * 100;
      if (percent > 100) percent = 100;
      if (percent < 0) percent = 0;
    }
    final barColor = isMet ? Colors.green : Colors.red;
    final statusText = isMet ? 'Met Threshold' : 'Below Threshold';
    // Remove percent from text, and set text color to black everywhere

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isMet ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMet ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Text(
                  employee.empName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 4),
                employee.isPunchMandatory == 1
                    ? Tooltip(
                        message: 'Punch Mandatory',
                        child: const Icon(
                          Icons.star,
                          color: Colors.red,
                          size: 16,
                        ),
                      )
                    : Tooltip(
                        message: 'Punch Not Mandatory',
                        child: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 16,
                        ),
                      ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              employee.empId.toString(),
              style: const TextStyle(fontSize: 14, color: Colors.black),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              employee.avgMonthlyHours.toStringAsFixed(2),
              style: const TextStyle(fontSize: 14, color: Colors.black),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              employee.thresholdHours,
              style: const TextStyle(fontSize: 14, color: Colors.black),
            ),
          ),
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      FractionallySizedBox(
                        widthFactor: percent / 100,
                        child: Container(
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          statusText,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EnhancedToggle extends StatelessWidget {
  final int isForYearly;
  final ValueChanged<int> onChanged;
  const _EnhancedToggle({required this.isForYearly, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Tooltip(
          message:
              'Toggle between Monthly and Yearly export. "Monthly" exports data for the selected month, "Yearly" exports for the selected month.',
          child: Icon(
            Icons.info_outline,
            color: Colors.grey.shade600,
            size: 20,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.blue.shade200, width: 1),
          ),
          child: Row(
            children: [
              _Segment(
                icon: Icons.calendar_month,
                label: 'Monthly',
                selected: isForYearly == 0,
                onTap: () => onChanged(0),
              ),
              _Segment(
                icon: Icons.event_note,
                label: 'Yearly',
                selected: isForYearly == 1,
                onTap: () => onChanged(1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Segment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? Colors.white : Colors.blue, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.blue,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
