import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:myoffice_sunshine/modules/hr/attendence/widgets/attendance_dropdown.dart';
import 'package:myoffice_sunshine/utils/snackbar_message.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart' as flutter;

class YearlyReport extends StatefulWidget {
  const YearlyReport({super.key});

  @override
  State<YearlyReport> createState() => _YearlyReportState();
}

class _YearlyReportState extends State<YearlyReport> {
  int? selectedYear;
  bool isLoading = false;
  List<dynamic> yearlyData = [];
  String? error;
  Map<String, dynamic>? selectedEmployee;

  final List<String> months = [
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
    'January',
    'February',
    'March',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedYear = now.month >= 4 ? now.year : now.year - 1;
    fetchYearlyReport(selectedYear!);
  }

  Future<void> fetchYearlyReport(int year) async {
    setState(() {
      isLoading = true;
      error = null;
      yearlyData = [];
      selectedEmployee = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) throw Exception('Authentication token not found.');
      final endYear = year + 1;
      final url =
          'https://1.sunshineiot.in/api/v2/hr/attendance/yearly-records/$endYear';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          yearlyData = data;
        });
      } else {
        throw Exception('Failed to fetch data: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> exportToExcel() async {
    final excel = Excel.createExcel();

    // Use the default Sheet1
    final sheet = excel['Sheet1'];
    final header = [
      'Employee Name',
      ...months.expand((m) => ['$m Required', '$m Present', '$m Extra']),
      'Total Required',
      'Total Present',
      'Total Extra',
    ];
    sheet.appendRow(header);
    for (final emp in yearlyData) {
      final row = <dynamic>[];
      row.add(emp['emp_name']);
      for (final m in months) {
        final summary =
            emp['monthly_summary'][m] ??
            {'required': 0, 'present': 0, 'extra': 0};
        row.add(summary['required']);
        row.add(summary['present']);
        row.add(summary['extra']);
      }
      final total = emp['yearly_total'] ?? {};
      row.add(total['total_required'] ?? 0);
      row.add(total['total_present'] ?? 0);
      row.add(total['total_extra'] ?? 0);
      sheet.appendRow(row);
    }
    final bytes = excel.encode();
    if (bytes == null) return;
    if (kIsWeb) {
      // Use universal_html for web file download
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'yearly_report_$selectedYear.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/yearly_report_$selectedYear.xlsx');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      SnackbarUtils.showSuccess('Excel exported: ${file.path}');
    }
  }

  List<Map<String, dynamic>> get employeeList => yearlyData
      .map<Map<String, dynamic>>(
        (e) => {
          'emp_id': e['emp_id'],
          'emp_name': e['emp_name'],
          'monthly_summary': e['monthly_summary'],
          'yearly_total': e['yearly_total'],
        },
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    final showList = selectedEmployee != null ? [selectedEmployee!] : [];
    final now = DateTime.now();
    final currentFyStart = now.month >= 4 ? now.year : now.year - 1;
    final fyList = List.generate((currentFyStart) - 2023 + 1, (i) => 2023 + i);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yearly Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export to Excel',
            onPressed: yearlyData.isNotEmpty ? exportToExcel : null,
          ),
          const SizedBox(width: 10),
          AttendanceDropdown(),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            color: Colors.white,
            width: double.infinity,
            height: double.infinity,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: flutter.Border.all(color: Colors.blue.shade100),
                      ),
                      child: const Text(
                        'This page fetches a financial year\'s attendance summary for all active employees with punch Mandatory.\n'
                        'It calculates required hours (working days × 9), compares with present hours, and shows extra hours if any.\n'
                        'Yearly totals is just addition of that fields for all months.',
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                    ),
                    Row(
                      children: [
                        const Text(
                          'Year:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<int>(
                          value: selectedYear,
                          items: fyList.reversed.map((startYear) {
                            final endYear = startYear + 1;
                            return DropdownMenuItem(
                              value: startYear,
                              child: Text('$startYear - $endYear'),
                            );
                          }).toList(),
                          onChanged: (y) {
                            if (y != null) {
                              setState(() => selectedYear = y);
                              fetchYearlyReport(y);
                            }
                          },
                        ),
                        const SizedBox(width: 24),
                        SizedBox(
                          width: 350,
                          child: DropdownSearch<Map<String, dynamic>>(
                            items: employeeList,
                            itemAsString: (e) =>
                                e['emp_id'] != null && e['emp_name'] != null
                                ? '${e['emp_id']} - ${e['emp_name']}'
                                : (e['emp_name'] ?? ''),
                            selectedItem: selectedEmployee,
                            dropdownDecoratorProps:
                                const DropDownDecoratorProps(
                                  dropdownSearchDecoration: InputDecoration(
                                    labelText: 'View Employee',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                            onChanged: (emp) {
                              setState(() => selectedEmployee = emp);
                            },
                            clearButtonProps: const ClearButtonProps(
                              isVisible: true,
                            ),
                            popupProps: const PopupProps.menu(
                              showSearchBox: true,
                              searchFieldProps: TextFieldProps(
                                decoration: InputDecoration(
                                  hintText: 'Search employee...',
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (isLoading) const CircularProgressIndicator(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (error != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: flutter.Border.all(
                            color: Colors.red.shade100,
                          ),
                        ),
                        child: Text(
                          error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    if (!isLoading && selectedEmployee == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Text(
                            'Choose employee',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    if (!isLoading && showList.isNotEmpty)
                      Column(
                        children: showList
                            .map(
                              (emp) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: constraints.maxWidth < 700
                                          ? constraints.maxWidth
                                          : 900,
                                    ),
                                    child: EmployeeYearlySummaryCard(
                                      empName: emp['emp_name'] ?? '',
                                      months: months,
                                      monthlySummary:
                                          emp['monthly_summary'] ?? {},
                                      yearlyTotal: emp['yearly_total'] ?? {},
                                      selectedYear: selectedYear!,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    if (!isLoading &&
                        showList.isEmpty &&
                        error == null &&
                        selectedEmployee != null)
                      const Center(
                        child: Text('No data found for this employee.'),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class EmployeeYearlySummaryCard extends StatelessWidget {
  final String empName;
  final List<String> months;
  final Map<String, dynamic> monthlySummary;
  final Map<String, dynamic> yearlyTotal;
  final int selectedYear;
  const EmployeeYearlySummaryCard({
    required this.empName,
    required this.months,
    required this.monthlySummary,
    required this.yearlyTotal,
    required this.selectedYear,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentFY =
        (now.month >= 4 ? now.year : now.year - 1) == selectedYear;
    final currentMonthIndex = now.month >= 4 ? now.month - 4 : now.month + 8;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
                  columns: const [
                    DataColumn(
                      label: Text(
                        'Month',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Required',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Present',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Extra',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                  rows: [
                    DataRow(
                      color: WidgetStateProperty.all(Colors.yellow[100]),
                      cells: [
                        const DataCell(
                          Text(
                            'Yearly Total',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${yearlyTotal['total_required'] ?? 0}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${yearlyTotal['total_present'] ?? 0}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${yearlyTotal['total_extra'] ?? 0}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    ...months.asMap().entries.map((entry) {
                      final i = entry.key;
                      final m = entry.value;
                      final summary =
                          monthlySummary[m] ??
                          {'required': 0, 'present': 0, 'extra': 0};
                      final isCurrentMonth =
                          isCurrentFY && i == currentMonthIndex;
                      return DataRow(
                        color: isCurrentMonth
                            ? WidgetStateProperty.all(
                                Colors.lightGreen.shade100,
                              )
                            : null,
                        cells: [
                          DataCell(
                            Text(
                              m,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${summary['required']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${summary['present']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${summary['extra']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
