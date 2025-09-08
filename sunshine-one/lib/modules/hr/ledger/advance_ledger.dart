import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
import 'package:dropdown_search/dropdown_search.dart';

class AdvanceLedger extends StatefulWidget {
  const AdvanceLedger({super.key});

  @override
  AdvanceLedgerState createState() => AdvanceLedgerState();
}

class AdvanceLedgerState extends State<AdvanceLedger> {
  String? selectedEmployeeId;
  DateTime? fromDate;
  DateTime? toDate;
  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> employees = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    fromDate = DateTime(now.year, now.month - 1, now.day);
    toDate = now;
    fetchEmployees();
  }

  Future<String?> getJwtToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<void> fetchEmployees() async {
    setState(() => isLoading = true);
    try {
      final token = await getJwtToken();
      final response = await http.get(
        Uri.parse('https://1.sunshineiot.in/api/v2/hr/employee/id-name'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (!mounted) return;
        setState(() {
          employees = data.map((e) => Map<String, dynamic>.from(e)).toList();
        });
      } else {
        if (!mounted) return;
        SnackbarUtils.showError('Failed to fetch employees');
      }
    } catch (e) {
      if (!mounted) return;
      SnackbarUtils.showError('Error: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> fetchTransactions() async {
    if (selectedEmployeeId == null) {
      SnackbarUtils.showInfo('Please select an employee');
      return;
    }

    setState(() => isLoading = true);
    try {
      final token = await getJwtToken();
      final response = await http.post(
        Uri.parse('https://1.sunshineiot.in/api/v2/hr/ledger/advance/fetch'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'emp_id': selectedEmployeeId,
          'from_date': DateFormat('yyyy-MM-dd').format(fromDate!),
          'to_date': DateFormat('yyyy-MM-dd').format(toDate!),
        }),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (!mounted) return;
        setState(() {
          transactions = data.map((e) => Map<String, dynamic>.from(e)).toList();
        });
      } else {
        if (!mounted) return;
        SnackbarUtils.showError('Failed to fetch transactions');
      }
    } catch (e) {
      if (!mounted) return;
      SnackbarUtils.showError('Error: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? fromDate! : toDate!,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          fromDate = picked;
        } else {
          toDate = picked;
        }
      });
    }
  }

  Future<void> editTransaction(Map<String, dynamic> transactionData) async {
    setState(() => isLoading = true);
    try {
      final token = await getJwtToken();
      final response = await http.put(
        Uri.parse('https://1.sunshineiot.in/api/v2/hr/ledger/advance'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(transactionData),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (!mounted) return;
        SnackbarUtils.showSuccess(
          data['message'] ?? 'Advance entry updated successfully',
        );
        fetchTransactions();
      } else {
        if (!mounted) return;
        final Map<String, dynamic> data = json.decode(response.body);
        SnackbarUtils.showError(data['message'] ?? 'Failed to update entry');
      }
    } catch (e) {
      if (!mounted) return;
      SnackbarUtils.showError('Error: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> deleteTransaction(int transactionId) async {
    setState(() => isLoading = true);
    try {
      final token = await getJwtToken();
      final response = await http.delete(
        Uri.parse(
          'https://1.sunshineiot.in/api/v2/hr/ledger/advance/$transactionId',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (!mounted) return;
        SnackbarUtils.showSuccess(
          data['message'] ?? 'Advance entry deleted successfully',
        );
        fetchTransactions();
      } else {
        if (!mounted) return;
        final Map<String, dynamic> data = json.decode(response.body);
        SnackbarUtils.showError(data['message'] ?? 'Failed to delete entry');
      }
    } catch (e) {
      if (!mounted) return;
      SnackbarUtils.showError('Error: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> addTransaction(Map<String, dynamic> transactionData) async {
    setState(() => isLoading = true);
    try {
      final token = await getJwtToken();
      final response = await http.post(
        Uri.parse('https://1.sunshineiot.in/api/v2/hr/ledger/advance'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(transactionData),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (!mounted) return;
        SnackbarUtils.showSuccess(
          data['message'] ?? 'Advance entry added successfully',
        );
        fetchTransactions();
      } else {
        if (!mounted) return;
        final Map<String, dynamic> data = json.decode(response.body);
        SnackbarUtils.showError(data['message'] ?? 'Failed to add entry');
      }
    } catch (e) {
      if (!mounted) return;
      SnackbarUtils.showError('Error: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _exportToExcel() async {
    try {
      // Create the Excel workbook and use the default 'Sheet1' as the ledger sheet
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];
      // Add headers
      sheet.appendRow(['Date', 'Advance Given', 'Advance Returned', 'Remark']);
      // Add data
      for (var transaction in transactions) {
        if (!(transaction.containsKey('total'))) {
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
      }
      // Add summary row if present
      final summary =
          transactions.isNotEmpty && transactions.last.containsKey('total')
          ? transactions.last
          : null;
      if (summary != null) {
        sheet.appendRow(['']); // Empty row for spacing
        sheet.appendRow([
          'Total',
          summary['totalGiven']?.toString() ?? '0',
          summary['totalReturned']?.toString() ?? '0',
          'Balance: ${summary['total']?.toString() ?? '0'}',
        ]);
      }
      // Get the employee name
      final selectedEmployee = employees.firstWhere(
        (emp) => emp['emp_id'].toString() == selectedEmployeeId,
        orElse: () => {'emp_name': 'Unknown'},
      );
      // Create filename
      final fileName =
          'Advance_Ledger_${selectedEmployee['emp_name'] ?? 'Unknown'}_${DateFormat('yyyy-MM-dd').format(fromDate!)}_to_${DateFormat('yyyy-MM-dd').format(toDate!)}.xlsx';
      final bytes = excel.encode();
      if (bytes != null) {
        if (kIsWeb) {
          // Web download logic
          final blob = html.Blob([bytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          html.AnchorElement(href: url)
            ..setAttribute('download', fileName)
            ..click();
          html.Url.revokeObjectUrl(url);
        } else {
          // Mobile/desktop logic
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

  void showEditDialog(Map<String, dynamic> transaction) {
    showDialog(
      context: context,
      builder: (context) =>
          EditAdvanceDialog(transaction: transaction, onEdit: editTransaction),
    );
  }

  void showAddDialog() {
    showDialog(
      context: context,
      builder: (context) =>
          AddAdvanceDialog(empId: selectedEmployeeId!, onAdd: addTransaction),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Find summary if present
    Map<String, dynamic>? summary;
    if (transactions.isNotEmpty && transactions.last.containsKey('total')) {
      summary = transactions.last;
    }
    final transactionRows = summary != null
        ? transactions.sublist(0, transactions.length - 1)
        : transactions;
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top bar with title
              Padding(
                padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
                child: Row(
                  children: const [
                    Text(
                      'Advance Ledger',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: DropdownSearch<Map<String, dynamic>>(
                      items: employees,
                      itemAsString: (emp) =>
                          '${emp['emp_id']} - ${emp['emp_name']}',
                      selectedItem: employees.firstWhereOrNull(
                        (emp) => emp['emp_id'].toString() == selectedEmployeeId,
                      ),
                      dropdownDecoratorProps: DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          labelText: 'Select Employee',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white, // White background
                          labelStyle: const TextStyle(color: Colors.black),
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
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          style: const TextStyle(color: Colors.black),
                        ),
                        itemBuilder: (context, emp, isSelected) => Container(
                          color: Colors.white,
                          child: ListTile(
                            title: Text(
                              '${emp['emp_id']} - ${emp['emp_name']}',
                              style: const TextStyle(color: Colors.black),
                            ),
                          ),
                        ),
                        menuProps: const MenuProps(
                          backgroundColor: Colors.white,
                        ),
                      ),
                      filterFn: (emp, filter) {
                        final search = filter.toLowerCase();
                        return emp['emp_id'].toString().toLowerCase().contains(
                              search,
                            ) ||
                            emp['emp_name'].toString().toLowerCase().contains(
                              search,
                            );
                      },
                      onChanged: (emp) {
                        setState(() {
                          selectedEmployeeId = emp?['emp_id'].toString();
                        });
                      },
                      validator: (emp) =>
                          emp == null ? 'Please select an employee' : null,
                      dropdownButtonProps: const DropdownButtonProps(
                        icon: Icon(Icons.arrow_drop_down, color: Colors.black),
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
                      onTap: () => _selectDate(context, true),
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
                      onTap: () => _selectDate(context, false),
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
                onPressed: isLoading ? null : fetchTransactions,
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
                    showAddDialog();
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
                    double fontSize = constraints.maxWidth > 600 ? 15 : 13;
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
                            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                      'Advance Given',
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
                                      'Advance Returned',
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
                                          transaction['transaction_date'] ?? '',
                                          style: TextStyle(
                                            fontSize: fontSize - 1,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          transaction['transaction_type'] == 0
                                              ? transaction['transaction_amount']
                                                    .toString()
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
                                          transaction['transaction_type'] == 1
                                              ? transaction['transaction_amount']
                                                    .toString()
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
                                                showEditDialog(transaction);
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
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                    content: const Text(
                                                      'Are you sure you want to delete this transaction?',
                                                      style: TextStyle(
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Get.back(),
                                                        child: const Text(
                                                          'Cancel',
                                                          style: TextStyle(
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                      ),
                                                      TextButton(
                                                        onPressed: () {
                                                          Get.back();
                                                          deleteTransaction(
                                                            transaction['transaction_id'],
                                                          );
                                                        },
                                                        child: const Text(
                                                          'Delete',
                                                          style: TextStyle(
                                                            color: Colors.black,
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
                                        summary['totalGiven']?.toString() ??
                                            '-',
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
                                        summary['totalReturned']?.toString() ??
                                            '-',
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
                                        'Balance: ${summary['total']?.toString() ?? '-'}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: fontSize,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                    const Expanded(flex: 2, child: SizedBox()),
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
    );
  }
}

class EditAdvanceDialog extends StatefulWidget {
  final Map<String, dynamic> transaction;
  final Function(Map<String, dynamic>) onEdit;
  const EditAdvanceDialog({
    super.key,
    required this.transaction,
    required this.onEdit,
  });
  @override
  State<EditAdvanceDialog> createState() => EditAdvanceDialogState();
}

class EditAdvanceDialogState extends State<EditAdvanceDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime transactionDate;
  late String transactionType;
  late TextEditingController amountController;
  late TextEditingController remarkController;

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
      text: widget.transaction['transaction_remark'] ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Edit Advance Transaction',
        style: TextStyle(color: Colors.black),
      ),
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
                fillColor: Colors.grey.shade50,
                labelStyle: const TextStyle(color: Colors.black),
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
                fillColor: Colors.grey.shade50,
                labelStyle: const TextStyle(color: Colors.black),
              ),
              items: const [
                DropdownMenuItem(
                  value: '0',
                  child: Text(
                    'Advance Given',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
                DropdownMenuItem(
                  value: '1',
                  child: Text(
                    'Advance Returned',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => transactionType = value!);
              },
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
                fillColor: Colors.grey.shade50,
                labelStyle: const TextStyle(color: Colors.black),
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
                fillColor: Colors.grey.shade50,
                labelStyle: const TextStyle(color: Colors.black),
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
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              widget.onEdit({
                'transaction_id': widget.transaction['transaction_id'],
                'emp_id': widget.transaction['emp_id'],
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
            backgroundColor: Colors.black,
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

class AddAdvanceDialog extends StatefulWidget {
  final String empId;
  final Function(Map<String, dynamic>) onAdd;
  const AddAdvanceDialog({super.key, required this.empId, required this.onAdd});
  @override
  State<AddAdvanceDialog> createState() => AddAdvanceDialogState();
}

class AddAdvanceDialogState extends State<AddAdvanceDialog> {
  final _formKey = GlobalKey<FormState>();
  DateTime transactionDate = DateTime.now();
  String transactionType = '0';
  final TextEditingController amountController = TextEditingController();
  final TextEditingController remarkController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Add Advance Transaction',
        style: TextStyle(color: Colors.black),
      ),
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
                fillColor: Colors.grey.shade50,
                labelStyle: const TextStyle(color: Colors.black),
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
                fillColor: Colors.grey.shade50,
                labelStyle: const TextStyle(color: Colors.black),
              ),
              items: const [
                DropdownMenuItem(
                  value: '0',
                  child: Text(
                    'Advance Given',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
                DropdownMenuItem(
                  value: '1',
                  child: Text(
                    'Advance Returned',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => transactionType = value!);
              },
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
                fillColor: Colors.grey.shade50,
                labelStyle: const TextStyle(color: Colors.black),
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
                fillColor: Colors.grey.shade50,
                labelStyle: const TextStyle(color: Colors.black),
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
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              widget.onAdd({
                'emp_id': int.parse(widget.empId),
                'transaction_date': DateFormat(
                  'yyyy-MM-dd',
                ).format(transactionDate),
                'transaction_remark': remarkController.text,
                'transaction_type': int.parse(transactionType),
                'transaction_amount': double.parse(amountController.text),
              });
              Get.back();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
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
