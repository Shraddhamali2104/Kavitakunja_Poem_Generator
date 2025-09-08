import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:myoffice_sunshine/utils/snackbar_message.dart';
import 'package:myoffice_sunshine/utils/standard_table_style.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'log_controller.dart';
import 'package:myoffice_sunshine/modules/hr/todo/project_task_controller.dart';

class ActivityLogTable extends StatefulWidget {
  const ActivityLogTable({super.key});

  @override
  State<ActivityLogTable> createState() => _ActivityLogTableState();
}

class _ActivityLogTableState extends State<ActivityLogTable> {
  final LogController controller = Get.put(LogController());
  final ProjectTaskController _projectTaskController = Get.put(
    ProjectTaskController(),
  );

  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();
  final List<String> statusList = [
    'LOW',
    'MEDIUM',
    'HIGH',
    'CRITICAL',
    'AUDIT',
  ];
  final List<String> moduleList = [
    'ADMIN',
    'HR',
    'STORE',
    'SALES',
    'PURCHASE',
    'DESIGN',
    'MANAGEMENT',
    'QUALITY',
    'SERVICE',
    'ACCOUNT',
    'PRODUCTION',
  ];

  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    controller.fetchLogs();
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  void _showDeleteDatePicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      _selectedDate = picked;
      final formatted = DateFormat('dd MMMM yyyy').format(picked);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Confirm Deletion"),
          content: Text(
            "Logs before $formatted will be permanently deleted. Do you want to continue?",
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Get.back();
                _deleteLogsForDate();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: const Text("Confirm Delete"),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _deleteLogsForDate() async {
    if (_selectedDate == null) {
      if (!mounted) return;
      SnackbarUtils.showError("Please select a date first");
      return;
    }

    final formattedDate = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
    ).toUtc().toIso8601String();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) {
      if (!mounted) return;
      SnackbarUtils.showError("Token not found. Please login again.");
      return;
    }

    try {
      final response = await http.delete(
        Uri.parse("https://1.sunshineiot.in/api/v2/admin/logs/$formattedDate"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        SnackbarUtils.showSuccess("Logs deleted successfully");
        controller.fetchLogs(); // Refresh
      } else if (response.statusCode == 404) {
        //Get.snackbar("Info", "No logs found before that date.");
        SnackbarUtils.showInfo("No logs found before that date.");
      } else {
        SnackbarUtils.showError(
          "Failed to delete logs: ${response.statusCode}",
        );
      }
    } catch (e) {
      if (!mounted) return;
      SnackbarUtils.showError("Exception occurred: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Container(
          color: Colors.grey.shade50,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Obx(() {
                  final hasFilter = controller.selectedDate.value != null ||
                      controller.selectedModule.value != null ||
                      controller.selectedStatus.value != null;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Log Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 210,
                            height: 33,
                            child: TextField(
                              controller: controller.searchController,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search, size: 20),
                                hintText: 'Search by Action...',
                                hintStyle: const TextStyle(fontSize: 12),
                                suffixIcon: Obx(
                                  () => controller.searchQuery.value.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            controller.clearSearch();
                                            controller.fetchLogs();
                                          },
                                          iconSize: 18,
                                        )
                                      : const SizedBox.shrink(),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(40),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                              ),
                              onChanged: controller.setSearchQuery,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildCompactFilter(
                            label: controller.selectedDate.value != null
                                ? " ${controller.selectedDate.value!.split('T').first}"
                                : "Date",
                            isActive: controller.selectedDate.value != null,
                            onTap: () async {
                              await controller.selectDate(context);
                              controller.fetchLogs();
                            },
                            onClear: controller.selectedDate.value != null
                                ? () {
                                    controller.selectedDate.value = null;
                                    controller.fetchLogs();
                                  }
                                : null,
                          ),
                          const SizedBox(width: 4),
                          _buildCompactFilter(
                            label: controller.selectedModule.value ?? "Module",
                            isActive: controller.selectedModule.value != null,
                            onTap: () => _showModulePicker(context),
                            onClear: controller.selectedModule.value != null
                                ? () {
                                    controller.selectedModule.value = null;
                                    controller.fetchLogs();
                                  }
                                : null,
                          ),
                          const SizedBox(width: 4),
                          _buildCompactFilter(
                            label: controller.selectedStatus.value ?? "Status",
                            isActive: controller.selectedStatus.value != null,
                            onTap: () {
                              _showStatusPicker(context);
                            },
                            onClear: controller.selectedStatus.value != null
                                ? () {
                                    controller.selectedStatus.value = null;
                                    controller.fetchLogs();
                                  }
                                : null,
                          ),
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 60,
                            child: hasFilter
                                ? TextButton.icon(
                                    onPressed: () {
                                      controller.clearFilters();
                                      // The Obx will update the UI instantly
                                    },
                                    icon: const Icon(Icons.close, size: 16),
                                    label: const Text(
                                      "Clear",
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(60, 32),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _showDeleteDatePicker(context),
                            icon: const Icon(Icons.delete, size: 18),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              minimumSize: const Size(70, 36),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            label: const Text(
                              "Delete",
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }),
              ),
              // Table Section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Obx(() {
                  if (controller.isLoading.value) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return Column(
                    children: [
                      // 'Log Details' text moved to filter/search row
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade200,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: CustomTable(
                          headers: const [
                            'ID',
                            'Module',
                            'Status',
                            'Action',
                            'Performed By',
                            'Timestamp',
                          ],
                          rows: controller.logs.asMap().entries.map<List<Widget>>((entry) {
                            final log = entry.value;
                            return [
                              Tooltip(
                                message: log['id'].toString(),
                                child: Text(log['id'].toString(), textAlign: TextAlign.center),
                              ),
                              Tooltip(
                                message: log['module'] ?? '',
                                child: Text(
                                  log['module'] ?? '',
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Tooltip(
                                message: log['status']?.toUpperCase() ?? '',
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(log['status']),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    log['status']?.toUpperCase() ?? '',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _getStatusTextColor(log['status']),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              Tooltip(
                                message: log['action'] ?? '',
                                child: Text(
                                  log['action'] ?? '',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                  style: const TextStyle(fontSize: 13),
                                  textAlign: TextAlign.left,
                                ),
                              ),
                              Tooltip(
                                message: log['performed_by'] ?? '',
                                child: Text(
                                  log['performed_by'] ?? '',
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Tooltip(
                                message: _projectTaskController.formatAssignedDate(log['timestamp']),
                                child: Text(
                                  _projectTaskController.formatAssignedDate(log['timestamp']),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ];
                          }).toList(),
                          columnWidths: const {
                            0: FixedColumnWidth(50),
                            1: FlexColumnWidth(1.2),
                            2: FixedColumnWidth(80),
                            3: FlexColumnWidth(2.5),
                            4: FlexColumnWidth(1.2),
                            5: FlexColumnWidth(1.2),
                          },
                          // Interactivity: tap row to show details
                          // This requires CustomTable to support onRowTap(int rowIndex)
                          // If not, you can wrap the table in a GestureDetector or update CustomTable
                        ),
                      ),
                      // Pagination controls
                      Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: MediaQuery.of(context).size.height * 0.01,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: controller.currentPage.value > 1
                                  ? () => controller.goToPage(
                                      controller.currentPage.value - 1,
                                    )
                                  : null,
                            ),
                            Text(
                              'Page ${controller.currentPage.value} of ${controller.totalPages.value}',
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: controller.currentPage.value < controller.totalPages.value
                                  ? () => controller.goToPage(
                                      controller.currentPage.value + 1,
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'LOW':
        return Colors.green.shade100;
      case 'MEDIUM':
        return Colors.yellow.shade100;
      case 'HIGH':
        return Colors.orange.shade100;
      case 'CRITICAL':
        return Colors.red.shade100;
      case 'AUDIT':
        return Colors.blue.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  Color _getStatusTextColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'LOW':
        return Colors.green.shade800;
      case 'MEDIUM':
        return Colors.orange.shade800;
      case 'HIGH':
        return Colors.deepOrange.shade800;
      case 'CRITICAL':
        return Colors.red.shade800;
      case 'AUDIT':
        return Colors.blue.shade800;
      default:
        return Colors.grey.shade800;
    }
  }

  void _showStatusPicker(BuildContext context) {
    final statuses = [
      'LOW',
      'MEDIUM',
      'HIGH',
      'CRITICAL',
      'AUDIT',
    ];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Status'),
        content: SizedBox(
          width: 250,
          height: 310,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 1,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 4.5,
            ),
            itemCount: statuses.length,
            itemBuilder: (context, index) {
              final status = statuses[index];
              final isSelected = controller.selectedStatus.value == status;
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  Navigator.of(context).pop();
                  controller.selectedStatus.value = status;
                  controller.fetchLogs();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue.shade100 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: Center(
                    child: Text(
                      status,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.blue.shade900 : Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showModulePicker(BuildContext context) {
    final modules = [
      'ADMIN',
      'HR',
      'STORE',
      'SALES',
      'PURCHASE',
      'DESIGN',
      'MANAGEMENT',
      'QUALITY',
      'SERVICE',
      'ACCOUNT',
      'PRODUCTION',
    ];
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select Module'),
        content: SizedBox(
          width: 350,
          height: 420,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.8,
            ),
            itemCount: modules.length,
            itemBuilder: (context, index) {
              final module = modules[index];
              final isSelected = controller.selectedModule.value == module;
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  controller.selectedModule.value = module;
                  controller.fetchLogs();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue.shade100 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: Center(
                    child: Text(
                      module,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.blue.shade900 : Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCompactFilter({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 2,
      ), // spacing between filters
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 4,
      ), // inner padding
      decoration: BoxDecoration(
        color: Colors.grey.shade200, // light background so margin shows
        borderRadius: BorderRadius.circular(6),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? Colors.black : Colors.grey,
              ),
            ),
            if (onClear != null)
              Padding(
                padding: const EdgeInsets.only(
                  left: 2,
                ), // small gap before clear icon
                child: IconButton(
                  icon: const Icon(Icons.clear, size: 14),
                  onPressed: onClear,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
