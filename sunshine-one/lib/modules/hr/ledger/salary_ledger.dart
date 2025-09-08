import 'package:flutter/material.dart';
import 'package:myoffice_sunshine/utils/snackbar_message.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:io' as io;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:dropdown_search/dropdown_search.dart';

class SalaryLedger extends StatefulWidget {
  const SalaryLedger({super.key});

  @override
  SalaryLedgerState createState() => SalaryLedgerState();
}

class SalaryLedgerState extends State<SalaryLedger> {
  List<Map<String, dynamic>> employees = [];
  List<Map<String, dynamic>> transactions = [];
  String? selectedEmployeeId;
  DateTime? fromDate;
  DateTime? toDate;
  bool isLoading = false;

  // Add this method to check authentication
  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) {
      _showError('Authentication token not found. Please login again.');
      // You might want to navigate to login page here
      return null;
    }
    return token;
  }

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    final now = DateTime.now();
    fromDate = DateTime(now.year, now.month - 1, now.day);
    toDate = now;
  }

  Future<void> _loadEmployees() async {
    setState(() => isLoading = true);
    try {
      final token = await _getAuthToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('https://1.sunshineiot.in/api/v2/hr/employee/id-name'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          employees = data.map((e) {
            final Map<String, dynamic> employee = Map<String, dynamic>.from(e);
            // Ensure emp_id and emp_name are strings and not null
            employee['emp_id'] = employee['emp_id']?.toString() ?? '';
            employee['emp_name'] =
                employee['emp_name']?.toString() ?? 'Unknown';
            return employee;
          }).toList();
        });
      } else if (response.statusCode == 401) {
        _showError('Session expired. Please login again.');
      } else {
        _showError('Failed to load employees');
      }
    } catch (e) {
      _showError('Error loading employees: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchLedgerData() async {
    if (selectedEmployeeId == null || fromDate == null || toDate == null) {
      _showError('Please fill all fields');
      return;
    }
    setState(() => isLoading = true);
    try {
      final token = await _getAuthToken();
      if (token == null) return;
      final requestBody = {
        'emp_id': int.parse(selectedEmployeeId!),
        'from_date': DateFormat('yyyy-MM-dd').format(fromDate!),
        'to_date': DateFormat('yyyy-MM-dd').format(toDate!),
      };
      final response = await http.post(
        Uri.parse('https://1.sunshineiot.in/api/v2/hr/ledger/fetch'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> ledgerData = data['data'] ?? [];
        setState(() {
          transactions = ledgerData.map((e) {
            final Map<String, dynamic> transaction = Map<String, dynamic>.from(
              e,
            );
            transaction['transaction_date'] =
                transaction['transaction_date']?.toString() ?? '';
            transaction['transaction_remark'] =
                transaction['transaction_remark']?.toString() ?? '';
            transaction['transaction_type'] =
                transaction['transaction_type'] ?? 0;
            transaction['transaction_amount'] =
                transaction['transaction_amount'] ?? 0;
            transaction['transaction_id'] =
                transaction['transaction_id']?.toString() ?? '';
            transaction['emp_id'] = transaction['emp_id']?.toString() ?? '';
            return transaction;
          }).toList();
          // Add the summary as the last row
          transactions.add({
            'transaction_date': 'Total',
            'transaction_type': -1, // Special type for summary
            'transaction_amount': data['total'] ?? 0,
            'transaction_remark': 'Summary',
            'payable': data['totalPayable'] ?? 0,
            'paid': data['totalPaid'] ?? 0,
          });
        });
      } else if (response.statusCode == 401) {
        _showError('Session expired. Please login again.');
      } else {
        _showError('Failed to fetch ledger data');
      }
    } catch (e) {
      _showError('Error fetching ledger data: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _addTransaction(Map<String, dynamic> transactionData) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return;
      final response = await http.post(
        Uri.parse('https://1.sunshineiot.in/api/v2/hr/ledger'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(transactionData),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        _showSuccess(data['message'] ?? 'Transaction added successfully');
        _fetchLedgerData();
      } else if (response.statusCode == 401) {
        _showError('Session expired. Please login again.');
      } else {
        final Map<String, dynamic> data = json.decode(response.body);
        _showError(data['message'] ?? 'Failed to add transaction');
      }
    } catch (e) {
      _showError('Error adding transaction: $e');
    }
  }

  Future<void> _editTransaction(Map<String, dynamic> transactionData) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return;
      final response = await http.post(
        Uri.parse('https://1.sunshineiot.in/api/v2/hr/ledger/edit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(transactionData),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        _showSuccess(data['message'] ?? 'Transaction updated successfully');
        _fetchLedgerData();
      } else if (response.statusCode == 401) {
        _showError('Session expired. Please login again.');
      } else {
        final Map<String, dynamic> data = json.decode(response.body);
        _showError(data['message'] ?? 'Failed to update transaction');
      }
    } catch (e) {
      _showError('Error updating transaction: $e');
    }
  }

  Future<void> _deleteTransaction(String transactionId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return;
      final response = await http.delete(
        Uri.parse(
          'https://1.sunshineiot.in/api/v2/hr/ledger/delete/$transactionId',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        _showSuccess(data['message'] ?? 'Transaction deleted successfully');
        _fetchLedgerData();
      } else if (response.statusCode == 401) {
        _showError('Session expired. Please login again.');
      } else {
        final Map<String, dynamic> data = json.decode(response.body);
        _showError(data['message'] ?? 'Failed to delete transaction');
      }
    } catch (e) {
      _showError('Error deleting transaction: $e');
    }
  }

  Future<void> _exportToExcel() async {
    try {
      if (!mounted) return;
      final excel = Excel.createExcel();
      final sheet = excel['Salary Ledger'];
      // Add headers
      sheet.appendRow(['Date', 'Payable', 'Paid', 'Remark']);
      // Add data
      for (var transaction in transactions) {
        sheet.appendRow([
          transaction['transaction_date'] ?? '',
          transaction['transaction_type'] == 0
              ? transaction['transaction_amount']?.toString() ?? '0'
              : '',
          transaction['transaction_type'] == 1
              ? transaction['transaction_amount']?.toString() ?? '0'
              : '',
          transaction['transaction_remark'] ?? '',
        ]);
      }
      // Add summary row if present
      final summary = transactions.lastWhere(
        (t) => t['transaction_type'] == -1,
        orElse: () => <String, dynamic>{},
      );
      if (summary.isNotEmpty) {
        sheet.appendRow(['']);
        sheet.appendRow([
          'Total',
          summary['payable']?.toString() ?? '0',
          summary['paid']?.toString() ?? '0',
          'Balance: ${summary['transaction_amount']?.toString() ?? '0'}',
        ]);
      }
      // Get the employee name
      final selectedEmployee = employees.firstWhere(
        (emp) => emp['emp_id'].toString() == selectedEmployeeId,
        orElse: () => {'emp_name': 'Unknown'},
      );
      final fileName =
          'Salary_Ledger_${selectedEmployee['emp_name'] ?? 'Unknown'}_${DateFormat('yyyy-MM-dd').format(fromDate!)}_to_${DateFormat('yyyy-MM-dd').format(toDate!)}.xlsx';
      final bytes = excel.encode();
      if (bytes != null) {
        if (kIsWeb) {
          final blob = html.Blob([bytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          html.AnchorElement(href: url)
            ..setAttribute('download', fileName)
            ..click();
          html.Url.revokeObjectUrl(url);
        } else {
          final directory = await getApplicationDocumentsDirectory();
          final file = io.File('${directory.path}/$fileName');
          await file.writeAsBytes(bytes);
          if (!mounted) return;
          SnackbarUtils.showInfo('Excel file saved to ${file.path}');
        }
      }
    } catch (e) {
      if (!mounted) return;
      SnackbarUtils.showError('Error exporting to Excel: $e');
    }
  }

  void _showError(String message) {
    SnackbarUtils.showError(message);
  }

  void _showSuccess(String message) {
    SnackbarUtils.showSuccess(message);
  }

  @override
  Widget build(BuildContext context) {
    // Find summary if present
    Map<String, dynamic>? summary;
    if (transactions.isNotEmpty &&
        transactions.last['transaction_type'] == -1) {
      summary = transactions.last;
    }
    final transactionRows = summary != null
        ? transactions.sublist(0, transactions.length - 1)
        : transactions;
    return Material(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top bar with title and Advance Ledger button
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 16.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Salary Ledger',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Get.toNamed(
                      '/dashboard/hr/ledger/advance',
                    ); // Navigate to Advance Ledger
                  },
                  icon: const Icon(Icons.account_balance_wallet),
                  label: const Text('Advance Ledger'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownSearch<Map<String, dynamic>>(
                            items: employees,
                            itemAsString: (emp) =>
                                '${emp['emp_id']} - ${emp['emp_name']}',
                            selectedItem: employees.firstWhereOrNull(
                              (emp) => emp['emp_id'] == selectedEmployeeId,
                            ),
                            dropdownDecoratorProps: DropDownDecoratorProps(
                              dropdownSearchDecoration: InputDecoration(
                                labelText: 'Select Employee',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.white, // White background
                                labelStyle: const TextStyle(
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            popupProps: PopupProps.menu(
                              showSearchBox: true,
                              searchFieldProps: TextFieldProps(
                                decoration: InputDecoration(
                                  labelText: 'Search Employee',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  fillColor: Colors.white,
                                  filled: true,
                                ),
                                style: const TextStyle(color: Colors.black),
                              ),
                              itemBuilder: (context, emp, isSelected) =>
                                  Container(
                                    color: Colors.white,
                                    child: ListTile(
                                      title: Text(
                                        '${emp['emp_id']} - ${emp['emp_name']}',
                                        style: const TextStyle(
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ),
                              menuProps: const MenuProps(
                                backgroundColor: Colors.white,
                              ),
                            ),
                            filterFn: (emp, filter) {
                              final search = filter.toLowerCase();
                              return emp['emp_id']
                                      .toString()
                                      .toLowerCase()
                                      .contains(search) ||
                                  emp['emp_name']
                                      .toString()
                                      .toLowerCase()
                                      .contains(search);
                            },
                            onChanged: (emp) {
                              setState(() {
                                selectedEmployeeId = emp?['emp_id'];
                              });
                            },
                            validator: (emp) => emp == null
                                ? 'Please select an employee'
                                : null,
                            dropdownButtonProps: const DropdownButtonProps(
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: Colors.black,
                              ),
                            ),
                            dropdownBuilder: (context, selectedItem) => Text(
                              selectedItem == null
                                  ? ''
                                  : '${selectedItem['emp_id']} - ${selectedItem['emp_name']}',
                              style: const TextStyle(color: Colors.black),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: 'From Date',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              labelStyle: const TextStyle(color: Colors.black),
                            ),
                            readOnly: true,
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: fromDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (date != null) {
                                setState(() => fromDate = date);
                              }
                            },
                            controller: TextEditingController(
                              text: fromDate != null
                                  ? DateFormat('yyyy-MM-dd').format(fromDate!)
                                  : '',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: 'To Date',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              labelStyle: const TextStyle(color: Colors.black),
                            ),
                            readOnly: true,
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: toDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (date != null) {
                                setState(() => toDate = date);
                              }
                            },
                            controller: TextEditingController(
                              text: toDate != null
                                  ? DateFormat('yyyy-MM-dd').format(toDate!)
                                  : '',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: isLoading ? null : _fetchLedgerData,
                      icon: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                      label: Text(isLoading ? 'Loading...' : 'Check Ledgers'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    if (selectedEmployeeId != null) ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AddTransactionDialog(
                              employeeId: selectedEmployeeId!,
                              onAdd: _addTransaction,
                            ),
                          );
                        },
                        icon: const Icon(Icons.add, color: Colors.black),
                        label: const Text(
                          'Add Transaction',
                          style: TextStyle(color: Colors.black),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          side: const BorderSide(color: Colors.black),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                    if (transactions.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: _exportToExcel,
                          icon: const Icon(Icons.download),
                          label: const Text('Export to Excel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 20,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          double horizontalPadding = constraints.maxWidth > 600
                              ? 24.0
                              : 8.0;
                          double fontSize = constraints.maxWidth > 600
                              ? 15
                              : 13;
                          return Align(
                            alignment: Alignment.topCenter,
                            child: Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              color: Colors.white,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: horizontalPadding,
                                  vertical: 16,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Header Row
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Date',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: fontSize,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Payable',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: fontSize,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Paid',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: fontSize,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            'Remark',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: fontSize,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Actions',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: fontSize,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(thickness: 1, height: 16),
                                    // Data Rows
                                    ...transactionRows.map(
                                      (transaction) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 6.0,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                transaction['transaction_date'] ??
                                                    '',
                                                style: TextStyle(
                                                  fontSize: fontSize - 1,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                transaction['transaction_type'] ==
                                                        0
                                                    ? transaction['transaction_amount']
                                                              ?.toString() ??
                                                          '0'
                                                    : '-',
                                                style: TextStyle(
                                                  fontSize: fontSize - 1,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                transaction['transaction_type'] ==
                                                        1
                                                    ? transaction['transaction_amount']
                                                              ?.toString() ??
                                                          '0'
                                                    : '-',
                                                style: TextStyle(
                                                  fontSize: fontSize - 1,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                transaction['transaction_remark'] ??
                                                    '',
                                                style: TextStyle(
                                                  fontSize: fontSize - 1,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Row(
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.edit,
                                                      color: Colors.blueAccent,
                                                    ),
                                                    onPressed: () {
                                                      showDialog(
                                                        context: context,
                                                        builder: (context) =>
                                                            EditTransactionDialog(
                                                              transaction:
                                                                  transaction,
                                                              onEdit:
                                                                  _editTransaction,
                                                            ),
                                                      );
                                                    },
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.delete,
                                                      color: Colors.redAccent,
                                                    ),
                                                    onPressed: () {
                                                      showDialog(
                                                        context: context,
                                                        builder: (context) => AlertDialog(
                                                          title: const Text(
                                                            'Confirm Delete',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.black,
                                                            ),
                                                          ),
                                                          content: const Text(
                                                            'Are you sure you want to delete this transaction?',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.black,
                                                            ),
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Get.back(),
                                                              child: const Text(
                                                                'Cancel',
                                                                style: TextStyle(
                                                                  color: Colors
                                                                      .black,
                                                                ),
                                                              ),
                                                            ),
                                                            TextButton(
                                                              onPressed: () {
                                                                Get.back();
                                                                _deleteTransaction(
                                                                  transaction['transaction_id']
                                                                      .toString(),
                                                                );
                                                              },
                                                              child: const Text(
                                                                'Delete',
                                                                style: TextStyle(
                                                                  color: Colors
                                                                      .black,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (summary != null) ...[
                                      const Divider(thickness: 1, height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'Total',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: fontSize,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              summary['payable']?.toString() ??
                                                  '0',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: fontSize,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              summary['paid']?.toString() ??
                                                  '0',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: fontSize,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              'Balance: ${summary['transaction_amount']?.toString() ?? '0'}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: fontSize,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                          const Expanded(
                                            flex: 2,
                                            child: SizedBox(),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
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

class AddTransactionDialog extends StatefulWidget {
  final String employeeId;
  final Function(Map<String, dynamic>) onAdd;
  const AddTransactionDialog({
    super.key,
    required this.employeeId,
    required this.onAdd,
  });
  @override
  AddTransactionDialogState createState() => AddTransactionDialogState();
}

class AddTransactionDialogState extends State<AddTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  DateTime? transactionDate;
  String? transactionType;
  final amountController = TextEditingController();
  final remarkController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Add Transaction'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Transaction Date',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: const Color(0xFFF0F4FA),
              ),
              readOnly: true,
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (date != null) {
                  setState(() => transactionDate = date);
                }
              },
              controller: TextEditingController(
                text: transactionDate != null
                    ? DateFormat('yyyy-MM-dd').format(transactionDate!)
                    : '',
              ),
              validator: (value) =>
                  transactionDate == null ? 'Please select a date' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: transactionType,
              decoration: InputDecoration(
                labelText: 'Transaction Type',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
                labelStyle: const TextStyle(color: Colors.black),
              ),
              items: const [
                DropdownMenuItem(
                  value: '0',
                  child: Text('PAYABLE', style: TextStyle(color: Colors.black)),
                ),
                DropdownMenuItem(
                  value: '1',
                  child: Text('PAID', style: TextStyle(color: Colors.black)),
                ),
              ],
              onChanged: (value) {
                setState(() => transactionType = value);
              },
              validator: (value) =>
                  value == null ? 'Please select a transaction type' : null,
              dropdownColor: Colors.white,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
              style: const TextStyle(color: Colors.black),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: amountController,
              decoration: InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: const Color(0xFFF0F4FA),
              ),
              keyboardType: TextInputType.number,
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Please enter an amount' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: remarkController,
              decoration: InputDecoration(
                labelText: 'Remark',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: const Color(0xFFF0F4FA),
              ),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Please enter a remark' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              widget.onAdd({
                'emp_id': int.parse(widget.employeeId),
                'transaction_date': DateFormat(
                  'yyyy-MM-dd',
                ).format(transactionDate!),
                'transaction_type': int.parse(transactionType!),
                'transaction_amount': double.parse(amountController.text),
                'transaction_remark': remarkController.text,
              });
              Get.back();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class EditTransactionDialog extends StatefulWidget {
  final Map<String, dynamic> transaction;
  final Function(Map<String, dynamic>) onEdit;
  const EditTransactionDialog({
    super.key,
    required this.transaction,
    required this.onEdit,
  });
  @override
  EditTransactionDialogState createState() => EditTransactionDialogState();
}

class EditTransactionDialogState extends State<EditTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime transactionDate;
  late String transactionType;
  late final TextEditingController amountController;
  late final TextEditingController remarkController;
  @override
  void initState() {
    super.initState();
    // Accept both yyyy-MM-dd and dd-MM-yyyy
    final dateStr = widget.transaction['transaction_date'];
    if (dateStr != null && dateStr.contains('-')) {
      final parts = dateStr.split('-');
      if (parts[0].length == 4) {
        transactionDate = DateTime.parse(dateStr);
      } else {
        // dd-MM-yyyy
        transactionDate = DateFormat('dd-MM-yyyy').parse(dateStr);
      }
    } else {
      transactionDate = DateTime.now();
    }
    transactionType = widget.transaction['transaction_type'].toString();
    amountController = TextEditingController(
      text: widget.transaction['transaction_amount'].toString(),
    );
    remarkController = TextEditingController(
      text: widget.transaction['transaction_remark'],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Edit Transaction'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Transaction Date',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: const Color(0xFFF0F4FA),
              ),
              readOnly: true,
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: transactionDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (date != null) {
                  setState(() => transactionDate = date);
                }
              },
              controller: TextEditingController(
                text: DateFormat('yyyy-MM-dd').format(transactionDate),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: transactionType,
              decoration: InputDecoration(
                labelText: 'Transaction Type',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
                labelStyle: const TextStyle(color: Colors.black),
              ),
              items: const [
                DropdownMenuItem(
                  value: '0',
                  child: Text('PAYABLE', style: TextStyle(color: Colors.black)),
                ),
                DropdownMenuItem(
                  value: '1',
                  child: Text('PAID', style: TextStyle(color: Colors.black)),
                ),
              ],
              onChanged: (value) {
                setState(() => transactionType = value!);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: amountController,
              decoration: InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: const Color(0xFFF0F4FA),
              ),
              keyboardType: TextInputType.number,
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Please enter an amount' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: remarkController,
              decoration: InputDecoration(
                labelText: 'Remark',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: const Color(0xFFF0F4FA),
              ),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Please enter a remark' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              widget.onEdit({
                'transaction_id': int.parse(
                  widget.transaction['transaction_id'].toString(),
                ),
                'transaction_date': DateFormat(
                  'dd-MM-yyyy',
                ).format(transactionDate),
                'transaction_remark': remarkController.text,
                'transaction_type': int.parse(transactionType),
                'transaction_amount': double.parse(amountController.text),
              });
              Get.back();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
