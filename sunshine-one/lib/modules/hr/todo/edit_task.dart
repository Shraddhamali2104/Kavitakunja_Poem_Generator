import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EditTaskPanel extends StatefulWidget {
  final Map<String, dynamic> existingTask;
  final void Function(Map<String, dynamic>) onUpdate;
  final void Function() onClose;

  const EditTaskPanel({
    super.key,
    required this.existingTask,
    required this.onUpdate,
    required this.onClose,
  });

  @override
  State<EditTaskPanel> createState() => _EditTaskPanelState();
}

class _EditTaskPanelState extends State<EditTaskPanel> {
  late TextEditingController _titleController;
  late TextEditingController _noteController;
  late TextEditingController _startDateController;
  late TextEditingController _targetDateController;

  String _priority = 'Medium';
  String? _startDate;
  String? _targetDate;

  bool _startDateEdited = false;
  bool _targetDateEdited = false;

  @override
  void initState() {
    super.initState();
    final task = widget.existingTask;

    _titleController = TextEditingController(text: task['title']);
    _noteController = TextEditingController(text: task['note']);
    _priority = task['priority'] ?? 'Medium';

    _startDate = task['start_date'];
    _targetDate = task['targetDate'];

    _startDateController = TextEditingController(text: _formatDate(_startDate));
    _targetDateController = TextEditingController(
      text: _formatDate(_targetDate),
    );
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '';
    final dt = DateTime.tryParse(isoDate);
    return dt != null ? DateFormat('yyyy-MM-dd').format(dt) : isoDate;
  }

  void _submit() {
    final updatedTask = {
      'id': widget.existingTask['id'],
      'title': _titleController.text.trim(),
      'note': _noteController.text.trim(),
      'priority': _priority,
    };

    if (_startDateEdited) {
      updatedTask['start_date'] = _startDate;
    }
    if (_targetDateEdited) {
      updatedTask['targetDate'] = _targetDate;
    }

    widget.onUpdate(updatedTask);
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
      setEdited();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Edit Task",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Task Title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _priority,
                items: ['High', 'Medium', 'Low'].map((level) {
                  return DropdownMenuItem(value: level, child: Text(level));
                }).toList(),
                onChanged: (val) => setState(() => _priority = val ?? 'Medium'),
                decoration: const InputDecoration(labelText: 'Priority'),
              ),
              const SizedBox(height: 10),
              TextField(
                readOnly: true,
                controller: _startDateController,
                decoration: const InputDecoration(labelText: 'Start Date'),
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
                readOnly: true,
                controller: _targetDateController,
                decoration: const InputDecoration(labelText: 'Target Date'),
                onTap: () => _pickDate(
                  context: context,
                  controller: _targetDateController,
                  initialDateString: _targetDate,
                  onSelected: (iso) => _targetDate = iso,
                  setEdited: () => _targetDateEdited = true,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submit,
                child: const Text("Update Task"),
              ),
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
