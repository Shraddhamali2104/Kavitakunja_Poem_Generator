import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'add_employee.dart';
import 'view_employee.dart';
import '../../../controllers/options_controller.dart';

class ManageEmployeeLayout extends StatefulWidget {
  const ManageEmployeeLayout({super.key});

  @override
  State<ManageEmployeeLayout> createState() => _ManageEmployeeLayoutState();
}

class _ManageEmployeeLayoutState extends State<ManageEmployeeLayout> {
  late OptionsController optionsController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<OptionsController>()) {
      optionsController = Get.find<OptionsController>();
    } else {
      optionsController = Get.put(OptionsController());
    }
    _initOptions();
  }

  Future<void> _initOptions() async {
    if (!optionsController.hasData) {
      await optionsController.fetchOptions();
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    // Always show the employee list. Add/edit handled by their own routes.
    return ViewEmployee(
      onEdit: (empId) => Get.toNamed('/dashboard/hr/manage_employee/edit/$empId'),
      showEditButtons: true,
    );
  }
}

// Updated pages using actual widgets
class AddEmployeePage extends StatelessWidget {
  const AddEmployeePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AddEmployee();
  }
}
