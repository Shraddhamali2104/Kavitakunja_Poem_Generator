import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:myoffice_sunshine/utils/snackbar_message.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../controllers/options_controller.dart';
import '../../../models/option_model.dart';
import 'package:get/get.dart';
import 'project_page_controller.dart';
import 'project_model.dart';

List<Option> deduplicateOptions(List<Option> options) {
  final seen = <int>{};
  return options.where((o) => seen.add(o.optionId)).toList();
}

class ProjectForm extends StatefulWidget {
  const ProjectForm({super.key});

  @override
  ProjectFormState createState() => ProjectFormState();
}

class ProjectFormState extends State<ProjectForm> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final modelNoController = TextEditingController();
  final annualQtyController = TextEditingController();
  final revenueController = TextEditingController();

  final ProjectPageController controller = Get.find<ProjectPageController>();
  late OptionsController optionsController;

  bool isLoadingEmployees = true;
  List<Map<String, dynamic>> employeeList = [];

  Option? selectedStatus;
  int? selectedLeadId;
  DateTime? startDate;
  DateTime? endDate;

  @override
  void initState() {
    super.initState();
    optionsController = Get.find<OptionsController>();
    fetchEmployeeList();
  }

  Future<void> fetchEmployeeList() async {
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
        final List<dynamic> employees = json.decode(response.body);
        if (!mounted) return;
        setState(() {
          employeeList = employees
              .where((e) => e['emp_id'] != null && e['emp_name'] != null)
              .map<Map<String, dynamic>>(
                (e) => {'emp_id': e['emp_id'], 'emp_name': e['emp_name']},
              )
              .toList();
          isLoadingEmployees = false;
        });
      } else {
        throw Exception('Failed to load employee data');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoadingEmployees = false);
      SnackbarUtils.showError('Error fetching employees: $e');
    }
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final project = Project(
        name: nameController.text.trim(),
        modelNo: modelNoController.text.trim(),
        annualQty: int.tryParse(annualQtyController.text.trim()),
        revenue: revenueController.text.trim(),
        startDate: startDate?.toIso8601String(),
        endDate: endDate?.toIso8601String(),
        projectLead: selectedLeadId?.toString(),
        status: selectedStatus?.optionId.toString(),
        createdBy: '999',
        createdAt: DateTime.now().toIso8601String(),
      );
      debugPrint("📦 Sending Project: ${jsonEncode(project.toJson())}");
      final success = await controller.addProject(project);
      if (!mounted) return;
      if (success) {
        SnackbarUtils.showSuccess('Project created successfully!');
        // ✅ Clear form fields
        nameController.clear();
        modelNoController.clear();
        annualQtyController.clear();
        revenueController.clear();

        // ✅ Clear state
        setState(() {
          selectedStatus = null;
          selectedLeadId = null;
          startDate = null;
          endDate = null;
        });

        // ✅ Reset form
        _formKey.currentState!.reset();

        // ✅ Refresh project list (you already call this in your `addProject`)
        controller.changePage('list');
      }
    } else {
      // Optionally, show a red snackbar
      SnackbarUtils.showError(
        "Failed to create project. Please check the form.",
      );
    }
  }

  InputDecoration _inputDecoration(String label, {bool enabled = true}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: enabled ? Colors.black : Colors.grey),
      filled: true,
      fillColor: enabled ? Colors.white : Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.black, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool isRequired = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: _inputDecoration(isRequired ? '$label *' : label),
        validator: isRequired
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter $label';
                }
                return null;
              }
            : null,
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? selectedDate,
    required Function(DateTime?) onDateSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: selectedDate ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (picked != null) onDateSelected(picked);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[50],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$label *',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedDate == null
                          ? 'Select Date'
                          : DateFormat('yyyy-MM-dd').format(selectedDate),
                      style: const TextStyle(fontSize: 16, color: Colors.black),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.calendar_today, color: Colors.black),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusOptions = deduplicateOptions(
      optionsController.projectStatusOptions,
    );
    if (selectedStatus != null &&
        !statusOptions.any((o) => o.optionId == selectedStatus!.optionId)) {
      selectedStatus = null;
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔼 Header Section with Back Arrow
          Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((255 * 0.04).toInt()),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(color: const Color(0xFFDDDDDD)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => controller.changePage('list'),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Add Project',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),

          // 🧾 Form Section
          Form(
            key: _formKey,
            child: Column(
              children: [
                _buildTextField(
                  controller: nameController,
                  label: 'Project Name',
                  isRequired: true,
                ),
                _buildTextField(
                  controller: modelNoController,
                  label: 'Model Number',
                ),
                _buildTextField(
                  controller: annualQtyController,
                  label: 'Annual Quantity',
                  keyboardType: TextInputType.number,
                ),
                _buildTextField(
                  controller: revenueController,
                  label: 'Revenue',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                _buildDatePicker(
                  label: 'Start Date',
                  selectedDate: startDate,
                  onDateSelected: (date) => setState(() => startDate = date),
                ),
                _buildDatePicker(
                  label: 'End Date',
                  selectedDate: endDate,
                  onDateSelected: (date) => setState(() => endDate = date),
                ),
                if (isLoadingEmployees)
                  const CircularProgressIndicator()
                else if (employeeList.isEmpty)
                  const InputDecorator(
                    decoration: InputDecoration(labelText: 'Project Lead'),
                    child: Text(
                      'No employees available',
                      style: TextStyle(color: Colors.red),
                    ),
                  )
                else
                  DropdownButtonFormField<int>(
                    value: selectedLeadId,
                    decoration: _inputDecoration('Project Lead'),
                    items: employeeList.map((emp) {
                      return DropdownMenuItem<int>(
                        value: emp['emp_id'],
                        child: Text(emp['emp_name']),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => selectedLeadId = val),
                    validator: (value) =>
                        value == null ? 'Please select a project lead' : null,
                  ),
                DropdownButtonFormField<Option>(
                  value: selectedStatus,
                  decoration: _inputDecoration('Status'),
                  items: statusOptions.map((option) {
                    return DropdownMenuItem<Option>(
                      value: option,
                      child: Text(option.optionName),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => selectedStatus = val),
                  validator: (value) =>
                      value == null ? 'Please select a status' : null,
                ),
                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _submitForm,
                    icon: const Icon(Icons.save),
                    label: const Text('Submit Project'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
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
