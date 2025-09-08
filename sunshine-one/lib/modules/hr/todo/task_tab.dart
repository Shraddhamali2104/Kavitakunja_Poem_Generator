import 'package:get/get.dart';
import 'project_task_controller.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TaskTabView extends StatelessWidget {
  TaskTabView({super.key});

  final ProjectTaskController controller = Get.put(ProjectTaskController());
  final TextEditingController _searchController = TextEditingController();
  final RxString searchQuery = ''.obs;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      /// ✅ Fixed filtering logic
      final filteredTasks = controller.allTasks.where((task) {
        final title = (task['title'] ?? '').toString().toLowerCase();
        if (!title.contains(searchQuery.value.toLowerCase())) return false;

        // 🔹 Project filter
        if (controller.selectedProjectId.value != null &&
            task['project_id'].toString() !=
                controller.selectedProjectId.value.toString()) {
          return false;
        }

        // 🔹 Start date filter
        if (controller.selectedStartDate.value != null) {
          final rawStartDate = task['start_date'] ?? '';
          DateTime? taskDate;

          try {
            taskDate = DateTime.parse(rawStartDate); // ISO
          } catch (_) {
            try {
              taskDate = DateFormat('yyyy-MM-dd').parse(rawStartDate);
            } catch (_) {
              try {
                taskDate = DateFormat('dd MMM yyyy').parse(rawStartDate);
              } catch (e) {
                debugPrint(
                  '❌ Date parse error: $e, rawStartDate=$rawStartDate',
                );
                return false;
              }
            }
          }

          final filterDate = controller.selectedStartDate.value!;
          if (taskDate.year != filterDate.year ||
              taskDate.month != filterDate.month ||
              taskDate.day != filterDate.day) {
            return false;
          }
        }

        // 🔹 Priority filter
        if (controller.selectedPriority.value != null &&
            task['priority']?.toString().toLowerCase() !=
                controller.selectedPriority.value!.toLowerCase()) {
          return false;
        }

        // 🔹 Status filter
        if (controller.selectedStatus.value != null &&
            task['status'].toString() !=
                controller.selectedStatus.value.toString()) {
          return false;
        }

        return true;
      }).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------------- FILTER BAR + SEARCH ----------------
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Left side: filters in Wrap
                Expanded(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildProjectFilter(context),
                      _buildDateFilter(context),
                      _buildPriorityFilter(context),

                      if (controller.selectedProjectId.value != null ||
                          controller.selectedPriority.value != null ||
                          controller.selectedStartDate.value != null ||
                          controller.selectedStatus.value != null)
                        TextButton.icon(
                          onPressed: () {
                            controller.selectedProjectId.value = null;
                            controller.selectedPriority.value = null;
                            controller.selectedStartDate.value = null;
                            controller.selectedStatus.value = null;
                            controller.fetchProjects();
                          },
                          icon: const Icon(Icons.close),
                          label: const Text("Clear Filters"),
                        ),
                    ],
                  ),
                ),

                // Right side: search bar
                SizedBox(
                  width: 250,
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search by task title...',
                      suffixIcon: Obx(
                        () => searchQuery.value.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  searchQuery.value = '';
                                },
                              )
                            : const SizedBox.shrink(),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(40),
                      ),
                    ),
                    onChanged: (val) => searchQuery.value = val,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 0),

          // ---------------- TASK LIST ----------------
          Expanded(child: _buildTaskList(filteredTasks)),
        ],
      );
    });
  }

  // ---------------- FILTER CHIP HELPERS ----------------
  Widget _buildProjectFilter(BuildContext context) {
    return Obx(
      () => FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list,
              size: 18,
              color: controller.selectedProjectId.value != null
                  ? Colors.black
                  : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              controller.selectedProjectId.value != null
                  ? controller.projectTasks.firstWhere(
                          (p) => p['id'] == controller.selectedProjectId.value,
                          orElse: () => {'title': 'Unknown'},
                        )['title'] ??
                        ''
                  : 'Filter Project',
              style: TextStyle(
                color: controller.selectedProjectId.value != null
                    ? Colors.black
                    : Colors.grey,
              ),
            ),
          ],
        ),
        selected: controller.selectedProjectId.value != null,
        onSelected: (_) => _showProjectPicker(context),
        onDeleted: controller.selectedProjectId.value != null
            ? () => controller.selectedProjectId.value = null
            : null,
        backgroundColor: controller.selectedProjectId.value != null
            ? Colors.blue.shade50
            : Colors.grey.shade200,
      ),
    );
  }

  Widget _buildDateFilter(BuildContext context) {
    return Obx(
      () => FilterChip(
        label: Text(
          controller.selectedStartDate.value != null
              ? '📅 ${DateFormat('dd MMM yyyy').format(controller.selectedStartDate.value!)}'
              : 'Start Date',
        ),
        selected: controller.selectedStartDate.value != null,
        onSelected: (_) async {
          final picked = await showDatePicker(
            context: context,
            initialDate: controller.selectedStartDate.value ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );
          if (picked != null) {
            controller.selectedStartDate.value = picked;
            controller.fetchProjects();
          }
        },
        onDeleted: controller.selectedStartDate.value != null
            ? () {
                controller.selectedStartDate.value = null;
                controller.fetchProjects();
              }
            : null,
        backgroundColor: controller.selectedStartDate.value != null
            ? Colors.blue.shade50
            : Colors.grey.shade200,
      ),
    );
  }

  Widget _buildPriorityFilter(BuildContext context) {
    return Obx(
      () => FilterChip(
        label: Text(controller.selectedPriority.value ?? 'Priority'),
        selected: controller.selectedPriority.value != null,
        onSelected: (_) => _showPriorityPicker(context),
        onDeleted: controller.selectedPriority.value != null
            ? () => controller.selectedPriority.value = null
            : null,
        backgroundColor: controller.selectedPriority.value != null
            ? Colors.blue.shade50
            : Colors.grey.shade200,
      ),
    );
  }

  // ---------------- PICKERS ----------------
  void _showProjectPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        children: controller.projectTasks.map((project) {
          return ListTile(
            title: Text(project['title']),
            onTap: () {
              controller.selectedProjectId.value = project['id'];
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showPriorityPicker(BuildContext context) {
    final options = ['Low', 'Medium', 'High'];
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        children: options.map((priority) {
          return ListTile(
            title: Text(priority),
            onTap: () {
              controller.selectedPriority.value = priority;
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  // ---------------- TASK LIST ----------------
  Widget _buildTaskList(List<Map<String, dynamic>> tasks) {
    if (tasks.isEmpty) return const Center(child: Text('No tasks found.'));

    tasks.sort(
      (a, b) => controller.priorityOrder[a['priority']]!.compareTo(
        controller.priorityOrder[b['priority']]!,
      ),
    );

    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (_, index) {
        final task = tasks[index];
        final bool completed = task['completed'] == true;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade300,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Checkbox(
                value: completed,
                onChanged: (val) {
                  if (val != null) {
                    controller.updateTaskStatus(task['id'], val);
                  }
                },
                activeColor: Colors.green,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task['title'] ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        decoration: completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (task['note']?.toString().isNotEmpty ?? false)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          task['note'],
                          style: TextStyle(
                            color: Colors.black54,
                            decoration: completed
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Start: ${task['start_date']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
                      ),
                    ),
                    if (task['targetDate'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Target: ${task['targetDate']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black45,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: controller.getPriorityBgColor(task['priority']),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  task['priority'],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: controller.getPriorityColor(task['priority']),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}