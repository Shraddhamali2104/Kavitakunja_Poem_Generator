import 'package:flutter/material.dart';
import 'package:myoffice_sunshine/modules/hr/todo/edit_project.dart';
import 'package:myoffice_sunshine/modules/hr/todo/task_tab.dart';
import 'package:myoffice_sunshine/utils/snackbar_message.dart';
import 'add_project.dart';
import 'add_task.dart';
import 'package:get/get.dart';
import 'project_task_controller.dart';
import 'edit_task.dart';
import 'package:intl/intl.dart';

class TodosLayout extends StatelessWidget {
  const TodosLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(color: const Color(0xFFF5F5F5), child: const TodosScreen());
  }
}

class TodosScreen extends StatefulWidget {
  const TodosScreen({super.key});

  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen> {
  // bool showAddProjectPanel = false;
  // bool showAddTaskPanel = false;
  // bool isLoading = true;
  // Map<String, dynamic>? selectedProject;
  final controller = Get.put(ProjectTaskController());
  final List<Map<String, dynamic>> existingProject = [];
  // final Map<String, int> _priorityOrder = {'High': 0, 'Medium': 1, 'Low': 2};
  //
  void _addTask(Map<String, dynamic> task) {
    controller.addTask(task);
  }

  @override
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      controller.projectList.value = [];
      controller.isLoading.value = true;
      controller.fetchProjects();
    });
  }

  String formatCreatedUpdatedDate({String? createdAt, String? updatedAt}) {
    String formatDate(String? isoDate, String label) {
      if (isoDate == null || isoDate.isEmpty) return '$label: Not set';
      try {
        final dt = DateTime.parse(isoDate).toLocal();
        return '$label: ${DateFormat('dd MMM yyyy hh:mm a').format(dt)}';
      } catch (_) {
        return '$label: Invalid date';
      }
    }

    final createdText = createdAt != null
        ? formatDate(createdAt, 'Created at')
        : '';
    final updatedText = updatedAt != null
        ? formatDate(updatedAt, 'Updated at')
        : '';

    return [createdText, updatedText].where((t) => t.isNotEmpty).join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ProjectTaskController());

    return DefaultTabController(
      length: 2, // Project + Task
      child: Scaffold(
        floatingActionButton: Builder(
          builder: (context) {
            return FloatingActionButton(
              onPressed: () {
                final tabController = DefaultTabController.of(context);
                final activeTab = tabController.index;

                if (activeTab == 0) {
                  // Project tab
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    builder: (context) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.playlist_add),
                          title: const Text('Add Project'),
                          onTap: () {
                            Get.back();
                            controller.showAddProjectPanel.value = true;
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.add_task),
                          title: const Text('Add Task'),
                          onTap: () {
                            Get.back();
                            controller.showProjectTabAddTaskPanel.value = true;
                          },
                        ),
                      ],
                    ),
                  );
                } else {
                  // Task tab
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    builder: (context) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.add_task),
                          title: const Text('Add Task'),
                          onTap: () {
                            Get.back();
                            controller.showTaskTabAddTaskPanel.value = true;
                          },
                        ),
                      ],
                    ),
                  );
                }
              },
              tooltip: 'Add',
              backgroundColor: Colors.blueAccent,
              child: const Icon(Icons.add),
            );
          },
        ),
        body: Obx(() {
          final allTasks = <Map<String, dynamic>>[];

          for (var project in controller.projectTasks) {
            final title = project['title'];
            final tasks = (project['tasks'] as List<Map<String, dynamic>>).map((
              t,
            ) {
              return {...t, 'projectTitle': title};
            }).toList();
            allTasks.addAll(tasks);
          }

          return Column(
            children: [
              // Tab Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: TabBar(
                  indicator: BoxDecoration(
                    color: const Color(0xFFE0E7FF),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.black54,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  overlayColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(
                      height: 40,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open, size: 18),
                          SizedBox(width: 6),
                          Text('Projects'),
                        ],
                      ),
                    ),
                    Tab(
                      height: 40,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.task_alt, size: 18),
                          SizedBox(width: 6),
                          Text('Tasks'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (controller.isLoading.value) const LinearProgressIndicator(),

              Expanded(
                child: TabBarView(
                  children: [
                    // ➤ Project Tab View
                    Obx(() {
                      if (controller.showAddProjectPanel.value) {
                        return AddProjectPanel(
                          onClose: () =>
                              controller.showAddProjectPanel.value = false,
                          onAdd: (project) => controller.addProject(project),
                        );
                      }

                      if (controller.showProjectTabAddTaskPanel.value) {
                        return AddTaskPanel(
                          onClose: () =>
                              controller.showProjectTabAddTaskPanel.value =
                                  false,
                          onAdd: (task) => controller.addTask(task),
                          projectList: controller.projectTasks
                              .map((e) => e['title'].toString())
                              .toList(),
                        );
                      }

                      return _buildProjectsView();
                    }),

                    // ➤ Task Tab View
                    Obx(() {
                      if (controller.showTaskTabAddTaskPanel.value) {
                        return AddTaskPanel(
                          onClose: () =>
                              controller.showTaskTabAddTaskPanel.value = false,
                          onAdd: (task) => controller.addTask(task),
                          projectList: controller.projectTasks
                              .map((e) => e['title'].toString())
                              .toList(),
                        );
                      }

                      return TaskTabView(); // your regular task view
                    }),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildProjectsView() {
    return Obx(() {
      final projects = controller.projectTasks;
      final isLoading = controller.isLoading.value;

      return Stack(
        children: [
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (projects.isEmpty)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No projects found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Create your first project to get started',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              itemCount: projects.length,
              itemBuilder: (context, index) {
                final project = projects[index];
                final tasks = project['tasks'] as List<Map<String, dynamic>>;
                final completed = tasks
                    .where((t) => t['completed'] == true)
                    .length;
                final total = tasks.length;
                final hasTasks = total > 0;
                final expanded = project['expanded'] as bool;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  project['title'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  project['desc'],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                                if (project['createdBy'] != null &&
                                    project['createdBy'].toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Created by: ${project['createdBy']}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Start Date: ${project['start_date']?.isNotEmpty == true ? controller.formatDate(project['start_date']) : 'Not Assigned'}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    'Target Date: ${project['target_date']?.isNotEmpty == true ? controller.formatDate(project['target_date']) : 'Not Assigned'}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                // decoration: BoxDecoration(
                                //   color: controller.getPriorityBgColor(
                                //     project['priority'],
                                //   ),
                                //   borderRadius: BorderRadius.circular(6),
                                // ),
                                child: Text(
                                  controller.statusMap[project['status']] ??
                                      'Unknown',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: controller.getStatusColorFromInt(
                                      project['status'],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: controller.getPriorityBgColor(
                                    project['priority'],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  project['priority'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: controller.getPriorityColor(
                                      project['priority'],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        controller.editProject(project),
                                    tooltip: 'Edit Project',
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        controller.confirmDeleteProject(
                                          context,
                                          project['id'],
                                        ),
                                    tooltip: 'Delete Project',
                                  ),
                                ],
                              ),

                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () {
                                  final newExpanded = !expanded;
                                  final updatedProject = {
                                    ...project,
                                    'expanded': newExpanded,
                                  };
                                  controller.projectTasks[index] =
                                      updatedProject;
                                },
                                child: Row(
                                  children: [
                                    Text(
                                      '$completed/$total Tasks',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: hasTasks
                                            ? Colors.blueAccent
                                            : Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      expanded
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      size: 20,
                                      color: Colors.black87,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (expanded && hasTasks)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Column(
                            children: tasks.map((task) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Checkbox(
                                      value: task['completed'] == true,
                                      onChanged: (checked) async {
                                        final newStatus = checked ?? false;
                                        task['completed'] = newStatus;
                                        controller.projectTasks.refresh();

                                        if (task['id'] != null) {
                                          await controller.updateTaskStatus(
                                            task['id'],
                                            newStatus,
                                          );
                                        } else {
                                          task['completed'] = !newStatus;
                                          controller.projectTasks.refresh();
                                          SnackbarUtils.showError(
                                            'Task ID not found',
                                          );
                                        }
                                      },
                                      activeColor: Colors.green,
                                    ),
                                    const SizedBox(width: 8),

                                    /// ➤ TASK DETAILS
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            task['title'] ?? '',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              decoration:
                                                  task['completed'] == true
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                          if ((task['note']
                                                  ?.toString()
                                                  .isNotEmpty ??
                                              false))
                                            Text(
                                              task['note'],
                                              style: TextStyle(
                                                color: Colors.black54,
                                                decoration:
                                                    task['completed'] == true
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                              ),
                                            ),
                                          if (task['start_date'] != null)
                                            Text(
                                              'Start Date:${task['start_date']}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black45,
                                              ),
                                            ),
                                          Obx(() {
                                            final controller =
                                                Get.find<
                                                  ProjectTaskController
                                                >();
                                            final actionTime = controller
                                                .taskActionTimes[task['id']]; // Assuming you're inside a task item

                                            return actionTime != null &&
                                                    actionTime.isNotEmpty
                                                ? Text(
                                                    'Last $actionTime',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.green,
                                                    ),
                                                  )
                                                : const SizedBox.shrink();
                                          }),

                                          if (task['targetDate'] != null)
                                            Text(
                                              'Target: ${task['targetDate']}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black45,
                                              ),
                                            ),
                                          if ((task['assignedTo']
                                                  ?.toString()
                                                  .isNotEmpty ??
                                              false))
                                            Text(
                                              'Assigned to: ${task['assignedTo']}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black45,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),

                                    /// ➤ PRIORITY + [EDIT, DELETE] COLUMN
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        // ➤ PRIORITY
                                        if (task['priority'] != null)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: controller
                                                  .getPriorityBgColor(
                                                    task['priority'],
                                                  ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              task['priority'],
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: controller
                                                    .getPriorityColor(
                                                      task['priority'],
                                                    ),
                                              ),
                                            ),
                                          ),

                                        // ➤ EDIT + DELETE ICONS
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit,
                                                size: 20,
                                                color: Colors.blue,
                                              ),
                                              tooltip: "Edit Task",
                                              onPressed: () {
                                                controller.selectedTask.value =
                                                    task; // set the current task
                                                controller
                                                        .showEditTaskPanel
                                                        .value =
                                                    true;
                                              }, // open the panel
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete,
                                                size: 20,
                                                color: Colors.red,
                                              ),
                                              tooltip: "Delete Task",
                                              onPressed: () {
                                                controller.confirmDeleteTask(
                                                  context,
                                                  task['id'],
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          if (controller.showAddProjectPanel.value)
            Container(
              color: Colors.black38,
              child: Center(
                child: AddProjectPanel(
                  onClose: () {
                    controller.showAddProjectPanel.value = false;
                    controller.selectedProject.value = null;
                  },
                  onAdd: (project) {
                    // If adding
                    controller.addProject(project);
                  },
                ),
              ),
            ),
          if (controller.showEditProjectPanel.value)
            Container(
              color: Colors.black38,
              child: Center(
                child: EditProjectPanel(
                  existingProject: controller.selectedProject.value!,
                  onClose: () {
                    controller.showEditProjectPanel.value = false;
                    controller.selectedProject.value = null;
                  },
                  onUpdate: (project) {
                    controller.updateProject(project);
                  },
                ),
              ),
            ),

          if (controller.showAddTaskPanel.value)
            Container(
              color: Colors.black38,
              child: Center(
                child: AddTaskPanel(
                  onClose: () => controller.showAddTaskPanel.value = false,
                  projectList: controller.projectTasks
                      .map((e) => e['title'] as String)
                      .toList(),
                  onAdd: _addTask,
                ),
              ),
            ),
          if (controller.showEditTaskPanel.value)
            Container(
              color: Colors.black38,
              child: Center(
                child: EditTaskPanel(
                  existingTask: controller.selectedTask.value!,
                  onClose: () {
                    controller.showEditTaskPanel.value = false;
                    controller.selectedTask.value = null;
                  },
                  onUpdate: (task) {
                    controller.editTask(task['id'], task);
                  },

                  // projectList: controller.projectTasks
                  //     .map((e) => e['title'].toString())
                  // .toList(),
                ),
              ),
            ),
        ],
      );
    });
  }
}
