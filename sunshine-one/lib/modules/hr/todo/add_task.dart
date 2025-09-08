// Import section
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:myoffice_sunshine/utils/snackbar_message.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:myoffice_sunshine/controllers/user_controller.dart';
// import 'project_task_controller.dart';

class AddTaskPanel extends StatefulWidget {
  final VoidCallback onClose;
  final List<String> projectList;
  final Function(Map<String, dynamic>) onAdd;

  const AddTaskPanel({
    super.key,
    required this.onClose,
    required this.projectList,
    required this.onAdd,
  });

  @override
  State<AddTaskPanel> createState() => _AddTaskPanelState();
}

class _AddTaskPanelState extends State<AddTaskPanel> {
  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final userController = Get.find<UserController>();
  String? _selectedProject;
  String? _assignedBy;
  String? _assignedTo;
  DateTime? _startDate;
  DateTime? _targetDate;
  String _selectedPriority = 'Low';

  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _employees = [];
  DateTime? _projectStartDate;
  DateTime? _projectEndDate;

  @override
  void initState() {
    super.initState();
    _fetchProjects();
    _fetchEmployees();
    if (widget.projectList.isNotEmpty) {
      _selectedProject = widget.projectList.first;
    }
    final userController = Get.find<UserController>();
    _assignedBy = userController.empName;
    _assignedTo = null;
    final today = DateTime.now();
    _startDate ??= today;
  }

  Future<void> _fetchProjects() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return;
      final response = await http.get(
        Uri.parse('https://1.sunshineiot.in/api/v2/todo/project'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> projects = data['projects'] ?? [];
        setState(() {
          _projects = projects
              .map<Map<String, dynamic>>(
                (p) => {
                  'id': p['id'],
                  'name': p['name'],
                  'start_date': p['start_date'],
                  'end_date': p['end_date'],
                },
              )
              .where((p) => p['name'] != null)
              .toList();
          if (_projects.isNotEmpty) {
            _selectedProject = _projects.first['name'];
            _updateProjectDates(_selectedProject);
          }
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch projects: ${response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      SnackbarUtils.showError('Error fetching projects: $e');
    }
  }

  Future<void> _fetchEmployees() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return;

      final response = await http.get(
        Uri.parse('https://1.sunshineiot.in/api/v2/hr/employee/all'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> employees = json.decode(response.body);

        final mappedEmployees = employees
            .map<Map<String, dynamic>>(
              (e) => {
                'id': e['emp_id'],
                'name': e['emp_name'],
                'email': e['emp_email_id'],
                'phone': e['emp_phone_no'],
                'designation': e['emp_designation'],
                'role': 'employee',
              },
            )
            .where((e) => e['id'] != null && e['name'] != null)
            .toList();

        final userController = Get.find<UserController>();
        final loggedInId = userController.empId;

        debugPrint("✅ userController.empId: $loggedInId");

        final matchedUser = mappedEmployees.firstWhere(
          (e) => e['id'] == loggedInId,
          orElse: () => {},
        );

        debugPrint("🟡 matched user: $matchedUser");

        if (!mounted) return;
        setState(() {
          _employees = mappedEmployees;
          _assignedTo = null;
          _assignedBy = matchedUser['name']; // This sets dropdown value
        });
      } else {
        if (!mounted) return;
        SnackbarUtils.showError(
          'Failed to fetch employees: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      SnackbarUtils.showError('Failed to fetch employees: $e');
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

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _submitTask() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) {
      if (!mounted) return;
      SnackbarUtils.showInfo(
        'Authentication token not found. Please login again.',
      );
      return;
    }

    if (_taskController.text.trim().isEmpty) {
      if (!mounted) return;
      _showErrorDialog("Task title is required.");
      return;
    }

    if (_selectedProject == null) {
      if (!mounted) return;
      _showErrorDialog("Please select a project.");
      return;
    }

    if (_assignedTo == null) {
      if (!mounted) return;
      _showErrorDialog("Please select who the task is assigned to.");
      return;
    }

    // Find the selected project
    final projectMap = _projects.firstWhere(
      (p) => p['name'] == _selectedProject,
      orElse: () => <String, dynamic>{},
    );

    if (projectMap.isEmpty || projectMap['id'] == null) {
      _showErrorDialog("Invalid project selected.");
      return;
    }

    final int projectId = projectMap['id'];

    // Find the assigned to employee
    final assignedToEmp = _employees.firstWhere(
      (e) => e['name'] == _assignedTo,
      orElse: () => <String, dynamic>{},
    );

    if (assignedToEmp.isEmpty || assignedToEmp['id'] == null) {
      _showErrorDialog("Invalid assigned to employee selected.");
      return;
    }

    final int assignedToId = assignedToEmp['id'];
    final String assignedToRole = assignedToEmp['role'] ?? 'employee';

    // Find the assigned by employee (if selected)
    int? assignedById;
    String assignedByRole = 'admin'; // Default to admin if not specified

    if (_assignedBy != null && _assignedBy!.isNotEmpty) {
      final assignedByEmp = _employees.firstWhere(
        (e) => e['name'] == _assignedBy,
        orElse: () => <String, dynamic>{},
      );

      if (assignedByEmp.isNotEmpty && assignedByEmp['id'] != null) {
        assignedById = assignedByEmp['id'];
        assignedByRole = assignedByEmp['role'] ?? 'employee';
      } else {
        _showErrorDialog("Invalid assigned by employee selected.");
        return;
      }
    } else {
      // 🔹 Use the logged-in user if nothing is selected
      assignedById = userController.empId;
      assignedByRole = 'employee';
    }

    final newTask = {
      "task": _taskController.text.trim(),
      "note": _noteController.text.trim(),
      "priority": _getPriorityValue(_selectedPriority),
      "start_date": _startDate?.toUtc().toIso8601String(),
      "target_date": _targetDate != null
          ? DateFormat('yyyy-MM-dd HH:mm:ss').format(_targetDate!)
          : null,
      "project_id": projectId,
      "assigned_to_id": assignedToId,
      "assigned_to_role": assignedToRole,
      "assigned_by_id": assignedById,
      "assigned_by_role": assignedByRole,
    };

    try {
      final response = await http.post(
        Uri.parse("https://1.sunshineiot.in/api/v2/todo/task"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(newTask),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          // Add the created task to the local list
          final createdTask = responseData['task'];

          // if (createdTask != null && createdTask['id'] != null) {
          //   final controller = Get.find<ProjectTaskController>();
          //   controller.setCurrentActionTime(
          //     type: "Added",
          //     taskId: createdTask['id'],
          //   );
          //   widget.onAdd(createdTask);
          //   widget.onClose();
          // } else {
          //   _showErrorDialog(
          //     "Task created, but no ID received from the server.",
          //   );
          // }
          debugPrint(
            "Submitting start date: ${_startDate?.toUtc().toIso8601String()}",
          );

          widget.onAdd(createdTask);

          // Close the panel - success message will be shown in main screen
          widget.onClose();
        } else {
          _showErrorDialog(responseData['message'] ?? 'Failed to add task.');
        }
      } else {
        try {
          final errorData = json.decode(response.body);
          _showErrorDialog(
            'Failed to add task.\nStatus: ${response.statusCode}\n${errorData['message'] ?? response.body}',
          );
        } catch (e) {
          _showErrorDialog(
            'Failed to add task.\nStatus: ${response.statusCode}\n${response.body}',
          );
        }
      }
    } catch (e) {
      _showErrorDialog('Something went wrong while adding the task: $e');
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    DateTime now = DateTime.now();
    DateTime minDate = isStart
        ? (_projectStartDate != null && _projectStartDate!.isAfter(now)
              ? _projectStartDate!
              : now)
        : now;
    DateTime maxDate = (!isStart && _projectEndDate != null)
        ? _projectEndDate!
        : DateTime(2100);

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? minDate) : (_targetDate ?? now),
      firstDate: minDate,
      lastDate: isStart ? DateTime(2100) : maxDate,
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      DateTime finalDateTime = pickedDate;
      if (pickedTime != null) {
        finalDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      }

      setState(() {
        if (isStart) {
          _startDate = finalDateTime;
        } else {
          _targetDate = finalDateTime;
        }
      });
    }
  }

  void _updateProjectDates(String? projectName) {
    final project = _projects.firstWhere(
      (p) => p['name'] == projectName,
      orElse: () => <String, dynamic>{},
    );
    if (project.isNotEmpty) {
      try {
        _projectStartDate = project['start_date'] != null
            ? DateTime.parse(project['start_date'])
            : null;
      } catch (_) {
        _projectStartDate = null;
      }
      try {
        _projectEndDate = project['end_date'] != null
            ? DateTime.parse(project['end_date'])
            : null;
      } catch (_) {
        _projectEndDate = null;
      }
    } else {
      _projectStartDate = null;
      _projectEndDate = null;
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
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: widget.onClose,
                  ),
                  const Expanded(
                    child: Text(
                      'Add Task',
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
              _inputLabel('Task'),
              _inputField(_taskController, 'Task'),
              _inputLabel('Note'),
              _inputField(_noteController, 'Note', maxLines: 3),
              const SizedBox(height: 12),
              _searchableDropdown(
                value: _selectedProject,
                items: _projects.map((p) => p['name'].toString()).toList(),
                icon: Icons.folder,
                labelText: 'Project',
                onChanged: (val) {
                  setState(() {
                    _selectedProject = val;
                    _updateProjectDates(val);
                  });
                },
              ),
              const SizedBox(height: 12),
              _searchableDropdown(
                value: _assignedBy,
                items: _employees
                    .map((e) => '${e['name']}')
                    .toList(), // ✅ Using formatted list
                icon: Icons.person,
                labelText: 'Assigned By',
                onChanged: (val) => setState(() => _assignedBy = val),
              ),

              const SizedBox(height: 12),

              _searchableDropdown(
                value: _assignedTo,
                items: _employees.map((e) => '${e['name']}').toList(),
                // ✅ Using formatted list
                icon: Icons.person,
                labelText: 'Assigned To',
                onChanged: (val) => setState(() => _assignedTo = val),
              ),

              _inputLabel('Start Date'),
              _datePickerBox(
                _startDate,
                'Select Start Date',
                () => _pickDate(isStart: true),
              ),
              _inputLabel('Target Date'),
              _datePickerBox(
                _targetDate,
                'Select Target Date',
                () => _pickDate(isStart: false),
              ),
              _inputLabel('Priority'),
              _dropdownBox(
                value: _selectedPriority,
                items: ['High', 'Medium', 'Low'],
                icon: Icons.flag,
                onChanged: (val) => setState(() => _selectedPriority = val!),
              ),
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
                  onPressed: _submitTask,
                  child: const Text(
                    'Add Task',
                    style: TextStyle(fontSize: 16, color: Color(0xFF007BFF)),
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

  Widget _searchableDropdown({
    required String? value,
    required List<String> items,
    required IconData icon,
    required Function(String?) onChanged,
    String? labelText,
  }) {
    return DropdownSearch<String>(
      selectedItem: value,
      items: items,
      dropdownDecoratorProps: DropDownDecoratorProps(
        dropdownSearchDecoration: InputDecoration(
          labelText: labelText,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
      popupProps: PopupProps.menu(
        showSearchBox: true,
        searchFieldProps: TextFieldProps(
          style: const TextStyle(
            color: Colors.white,
          ), // 🔥 Search text color set to white
          decoration: InputDecoration(
            hintText: 'Search here...',
            hintStyle: const TextStyle(
              color: Colors.white60,
            ), // Optional: hint text color
            prefixIcon: const Icon(
              Icons.search,
              color: Colors.white,
            ), // Optional: icon color
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      onChanged: onChanged,
    );
  }

  Widget _dropdownBox({
    required String? value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No options available',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          : DropdownButton<String>(
              isExpanded: true,
              value: items.contains(value) ? value : null,
              hint: const Text('Select'),
              underline: const SizedBox(),
              icon: Icon(icon, color: Colors.black54),
              dropdownColor: Colors.white,
              style: const TextStyle(color: Colors.black),
              items: items
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: onChanged,
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
}
