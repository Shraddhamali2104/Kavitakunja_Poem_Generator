import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'project_task_controller.dart';

class AddProjectPanel extends StatefulWidget {
  final VoidCallback onClose;
  final Function(Map<String, dynamic>) onAdd;

  const AddProjectPanel({
    super.key,
    required this.onClose,
    required this.onAdd,
  });

  @override
  State<AddProjectPanel> createState() => _AddProjectPanelState();
}

class _AddProjectPanelState extends State<AddProjectPanel> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final controller = Get.put(ProjectTaskController());

  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedPriority = 'Medium';
  bool _isLoading = false;
  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _startDate ??= today;
  }

  Future<void> _submitProject() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        _showError('Authentication token not found. Please login again.');
        return;
      }

      if (_nameController.text.trim().isEmpty) {
        _showError('Project name is required.');
        return;
      }

      final body = {
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'priority': _getPriorityValue(_selectedPriority),
        'start_date': _startDate?.toIso8601String(),
        'end_date': _endDate?.toIso8601String(),
        'status': statusValue,
      };

      final response = await http.post(
        Uri.parse('https://1.sunshineiot.in/api/v2/todo/project'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final project = json.decode(response.body);
        final newProject = {
          'id': project['id'],
          'title': project['name'],
          'desc': project['description'],
          'priority': project['priority'],
          'status': project['status'],
          'start_date': project['start_date'],
          'target_date': project['end_date'],
          'createdBy': project['createdBy'],
          'tasks': project['tasks'] ?? [],
          'expanded': false,
        };
        widget.onAdd(newProject);
        widget.onClose();
      } else {
        final error = jsonDecode(response.body);
        _showError(error['message'] ?? 'Failed to create project.');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  int _getPriorityValue(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return 0;
      case 'medium':
        return 1;
      case 'low':
      default:
        return 2;
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? now) : (_endDate ?? now),
      firstDate: now,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Add New Project',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _inputLabel('Project Name'),
              _inputField(_nameController, 'Enter project name'),
              _inputLabel('Description'),
              _inputField(
                _descController,
                'Enter project description',
                maxLines: 3,
              ),
              _inputLabel('Start Date'),
              _datePickerBox(
                _startDate,
                'Select start date',
                () => _pickDate(isStart: true),
              ),
              _inputLabel('End Date'),
              _datePickerBox(
                _endDate,
                'Select end date',
                () => _pickDate(isStart: false),
              ),
              _inputLabel('Priority'),
              _priorityDropdown(),
              _inputLabel('Status'),
              _statusDropdown(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isLoading ? null : _submitProject,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Create Project',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF007BFF),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputLabel(String text) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
    ),
  );

  Widget _inputField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        fillColor: Colors.white,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }

  Widget _datePickerBox(DateTime? date, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text(
              date != null ? DateFormat('yyyy-MM-dd').format(date) : label,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priorityDropdown() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        isExpanded: true,
        value: _selectedPriority,
        underline: const SizedBox(),
        dropdownColor: Colors.white,
        iconEnabledColor: Colors.black,
        style: const TextStyle(color: Colors.black),
        items: ['High', 'Medium', 'Low']
            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
            .toList(),
        onChanged: (value) {
          setState(() {
            _selectedPriority = value!;
          });
        },
      ),
    );
  }

  String _statusText = 'In Progress'; // default

  Widget _statusDropdown() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        isExpanded: true,
        value: _statusText,
        underline: const SizedBox(),
        dropdownColor: Colors.white,
        iconEnabledColor: Colors.black,
        style: const TextStyle(color: Colors.black),
        items: controller.statusMap.values
            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
            .toList(),
        onChanged: (value) {
          setState(() {
            _statusText = value!;
          });
        },
      ),
    );
  }

  int get statusValue {
    return controller.statusMap.entries
        .firstWhere(
          (entry) => entry.value == _statusText,
          orElse: () => const MapEntry(0, 'In Progress'),
        )
        .key;
  }
}