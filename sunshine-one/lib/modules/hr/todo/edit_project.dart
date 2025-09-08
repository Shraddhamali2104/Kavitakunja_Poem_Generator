import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import 'project_task_controller.dart';

class EditProjectPanel extends StatefulWidget {
  final void Function(Map<String, dynamic>) onUpdate;
  final void Function() onClose;
  final Map<String, dynamic> existingProject;

  const EditProjectPanel({
    super.key,
    required this.onUpdate,
    required this.onClose,
    required this.existingProject,
  });

  String formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '';
    try {
      final date = DateTime.parse(rawDate);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (_) {
      return rawDate;
    }
  }

  @override
  State<EditProjectPanel> createState() => _EditProjectPanelState();
}

class _EditProjectPanelState extends State<EditProjectPanel> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;
  final controller = Get.put(ProjectTaskController());
  late String _priority;
  late String _status;

  String? _startDate;
  String? _endDate;

  bool _startDateEdited = false;
  bool _endDateEdited = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingProject['name'],
    );
    _descController = TextEditingController(
      text: widget.existingProject['description'],
    );
    var rawPriority = widget.existingProject['priority'];
    if (rawPriority is int) {
      _priority = controller.priorityFromInt(rawPriority);
    } else if (rawPriority is String) {
      _priority =
          rawPriority; // use directly if it's already 'High', 'Medium', 'Low'
    } else {
      _priority = 'Low'; // fallback
    }
    var rawStatus = widget.existingProject['status'];
    if (rawStatus is int) {
      _status = controller.statusMap[rawStatus] ?? 'In Progress';
    } else if (rawStatus is String) {
      _status = rawStatus; // fallback if status is already text
    } else {
      _status = 'In Progress';
    }

    _startDate = widget.existingProject['start_date'];
    _endDate = widget.existingProject['end_date'];

    _startDateController = TextEditingController(
      text: widget.formatDate(_startDate),
    );
    _endDateController = TextEditingController(
      text: widget.formatDate(_endDate),
    );
  }

  void _submit() {
    final updatedData = {
      'id': widget.existingProject['id'],
      'title': _nameController.text.trim(),
      'desc': _descController.text.trim(),
      'priority': _priority,
      'status': controller.statusToInt(_status),
    };
    // print(controller.statusToInt(_status));
    if (_startDateEdited) {
      updatedData['start_date'] = _startDate;
    }

    if (_endDateEdited) {
      updatedData['target_date'] = _endDate;
    }

    widget.onUpdate(updatedData);
    widget.onClose();
  }

  Future<void> _pickDate({
    required BuildContext context,
    required TextEditingController controller,
    required void Function(String iso) onSelected,
    required void Function() setEdited,
    String? initialDateString,
  }) async {
    final initialDate =
        DateTime.tryParse(initialDateString ?? '') ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final iso = picked.toIso8601String();
      final formatted = DateFormat('yyyy-MM-dd').format(picked);
      controller.text = formatted;
      onSelected(iso);
      setEdited(); // mark it as edited
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFF5F5F5),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Edit Project",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Project Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _priority,
                onChanged: (value) {
                  setState(() {
                    _priority = value!;
                  });
                },
                items: ['High', 'Medium', 'Low']
                    .map(
                      (level) => DropdownMenuItem<String>(
                        value: level,
                        child: Text(level),
                      ),
                    )
                    .toList(),
                decoration: InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: controller.statusMap.values.map((String status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _status = newValue;
                    });
                  }
                },
              ),

              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(labelText: 'Start Date'),
                controller: _startDateController,
                readOnly: true,
                onTap: () => _pickDate(
                  context: context,
                  controller: _startDateController,
                  initialDateString: _startDate,
                  onSelected: (iso) => _startDate = iso,
                  setEdited: () => _startDateEdited = true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(labelText: 'End Date'),
                controller: _endDateController,
                readOnly: true,
                onTap: () => _pickDate(
                  context: context,
                  controller: _endDateController,
                  initialDateString: _endDate,
                  onSelected: (iso) => _endDate = iso,
                  setEdited: () => _endDateEdited = true,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _submit, child: const Text("Update")),
              TextButton(
                onPressed: widget.onClose,
                child: const Text("Cancel"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}