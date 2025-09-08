import 'package:flutter/material.dart';
import 'package:myoffice_sunshine/utils/snackbar_message.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';

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
        Uri.parse('https://1.sunshineiot.in/api/v2/hr/employee/all'),
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

  void _showError(String message) {
    SnackbarUtils.showError(message);
  }

  void _showSuccess(String message) {
    SnackbarUtils.showSuccess(message);
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;
    return Scaffold(
      body: Stack(
        children: [
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!isWeb) ...[
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                              _LedgerDropdown(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (isWeb) ...[
                        // On web, show the dropdown below the Navbar (breadcrumb)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 12,
                            left: 24,
                            right: 24,
                            bottom: 8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [_LedgerDropdown()],
                          ),
                        ),
                      ],
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedEmployeeId,
                                decoration: InputDecoration(
                                  labelText: 'Select Employee',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF0F4FA),
                                ),
                                items: employees.map((employee) {
                                  return DropdownMenuItem(
                                    value: employee['emp_id'].toString(),
                                    child: Text(
                                      employee['emp_name'] ?? 'Unknown',
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() => selectedEmployeeId = value);
                                },
                                validator: (value) => value == null
                                    ? 'Please select an employee'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      decoration: InputDecoration(
                                        labelText: 'From Date',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: const Color(0xFFF0F4FA),
                                      ),
                                      readOnly: true,
                                      onTap: () async {
                                        final date = await showDatePicker(
                                          context: context,
                                          initialDate:
                                              fromDate ?? DateTime.now(),
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2100),
                                        );
                                        if (date != null) {
                                          setState(() => fromDate = date);
                                        }
                                      },
                                      controller: TextEditingController(
                                        text: fromDate != null
                                            ? DateFormat(
                                                'yyyy-MM-dd',
                                              ).format(fromDate!)
                                            : '',
                                      ),
                                      validator: (value) => fromDate == null
                                          ? 'Please select a date'
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      decoration: InputDecoration(
                                        labelText: 'To Date',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: const Color(0xFFF0F4FA),
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
                                            ? DateFormat(
                                                'yyyy-MM-dd',
                                              ).format(toDate!)
                                            : '',
                                      ),
                                      validator: (value) => toDate == null
                                          ? 'Please select a date'
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: transactions.length,
                          itemBuilder: (context, index) {
                            final transaction = transactions[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              elevation: 2,
                              child: ListTile(
                                title: Text(
                                  '${transaction['transaction_date']} - ${transaction['transaction_remark']}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: transaction['transaction_type'] == 0
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                                subtitle: Text(
                                  'Amount: ${transaction['transaction_amount']?.toStringAsFixed(2) ?? '0.00'}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (BuildContext context) =>
                                              EditTransactionDialog(
                                                transaction: transaction,
                                                onEdit: _editTransaction,
                                              ),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (BuildContext context) =>
                                              AlertDialog(
                                                title: const Text(
                                                  'Confirm Deletion',
                                                ),
                                                content: Text(
                                                  'Are you sure you want to delete this transaction? This action cannot be undone.',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Get.back(
                                                      result: 'Cancel',
                                                    ),

                                                    child: const Text('Cancel'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      _deleteTransaction(
                                                        transaction['transaction_id'],
                                                      );
                                                      Get.back(
                                                        result: 'Delete',
                                                      );
                                                    },
                                                    child: const Text('Delete'),
                                                  ),
                                                ],
                                              ),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ElevatedButton(
                          onPressed: () {
                            if (selectedEmployeeId == null) {
                              _showError('Please select an employee.');
                              return;
                            }
                            if (fromDate == null) {
                              _showError('Please select a From Date.');
                              return;
                            }
                            if (toDate == null) {
                              _showError('Please select a To Date.');
                              return;
                            }
                            _fetchLedgerData();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Fetch Ledger'),
                        ),
                      ),
                    ],
                  ),
                ),
          // Always visible floating button (top right)
          Positioned(
            top: 16,
            right: 16,
            child: ElevatedButton.icon(
              onPressed: () {
                Get.toNamed('/dashboard/hr/ledger/advance');
              },
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Go to Advance Ledger'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 8,
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

// --- Ledger Dropdown copied from ledger_layout.dart ---
class _LedgerDropdown extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: PopupMenuButton<_LedgerMenuItem>(
        tooltip: 'Ledger Sections',
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        offset: const Offset(0, 40),
        color: Colors.white,
        elevation: 8,
        onSelected: (item) => Get.toNamed(item.route),
        itemBuilder: (context) => [
          _buildMenuItem(
            context,
            _LedgerMenuItem(
              label: 'Salary Ledger',
              icon: Icons.account_balance_wallet,
              route: '/dashboard/hr/ledger/salary',
            ),
          ),
          _buildMenuItem(
            context,
            _LedgerMenuItem(
              label: 'Advance Ledger',
              icon: Icons.payment,
              route: '/dashboard/hr/ledger/advance',
            ),
          ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.menu, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                'Sections',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<_LedgerMenuItem> _buildMenuItem(
    BuildContext context,
    _LedgerMenuItem item,
  ) {
    return PopupMenuItem<_LedgerMenuItem>(
      value: item,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Icon(item.icon, size: 20, color: Colors.black),
          ),
          const SizedBox(width: 14),
          Text(
            item.label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerMenuItem {
  final String label;
  final IconData icon;
  final String route;
  const _LedgerMenuItem({
    required this.label,
    required this.icon,
    required this.route,
  });
}
// --- End Ledger Dropdown ---