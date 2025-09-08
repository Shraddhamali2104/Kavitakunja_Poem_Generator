import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:myoffice_sunshine/utils/snackbar_message.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'task_model.dart';
import 'project_model.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:timezone/timezone.dart' as tz;

class ProjectTaskController extends GetxController {
  RxBool isLoading = false.obs;
  RxList<Projects> projectList = <Projects>[].obs;
  RxList<Map<String, dynamic>> projectTasks = <Map<String, dynamic>>[].obs;
  final selectedProject = Rxn<Map<String, dynamic>>();
  final selectedTask = Rxn<Map<String, dynamic>>();
  final showEditProjectPanel = false.obs;
  final showEditTaskPanel = false.obs;
  RxBool showAddProjectPanel = false.obs;
  RxBool showProjectTabAddTaskPanel = false.obs;
  RxBool showTaskTabAddTaskPanel = false.obs;
  final actionTime = ''.obs;

  final lastAffectedTaskId = ''.obs;
  final RxMap<int, String> taskActionTimes = <int, String>{}.obs;
  final RxString actionType = ''.obs;
  final RxSet<int> expandedProjectIds = <int>{}.obs;
  RxnInt selectedProjectId = RxnInt();
  final selectedStatus = RxnInt();

  RxnString selectedPriority = RxnString();
  final Rx<DateTime?> selectedStartDate = Rx<DateTime?>(null);
  RxnString selectedTargetDate = RxnString();

  void setCurrentActionTime({required String type, required int taskId}) {
    final now = DateTime.now();
    final formatted =
        "$type at ${DateFormat('hh:mm a | dd MMM yyyy').format(now)}";
    taskActionTimes[taskId] = formatted;
    actionType.value = type;
  }

  final Map<String, int> priorityOrder = {'High': 0, 'Medium': 1, 'Low': 2};

  String formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(isoDate));
    } catch (_) {
      return isoDate;
    }
  }

  String formatAssignedDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return 'Assigned at: Not set';
    try {
      final ist = tz.getLocation('Asia/Kolkata'); // Force IST timezone
      final utcDateTime = DateTime.parse(isoDate); // Parse ISO 8601 UTC string
      final istDateTime = tz.TZDateTime.from(
        utcDateTime,
        ist,
      ); // Convert to IST

      return ' ${DateFormat('dd MMM yyyy hh:mm a').format(istDateTime)}';
    } catch (e) {
      return ' Invalid date';
    }
  }

  String priorityFromInt(int? val) {
    switch (val) {
      case 0:
        return 'High';
      case 1:
        return 'Medium';
      case 2:
      default:
        return 'Low';
    }
  }

  int getPriorityValue(String priority) {
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

  Color getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color getPriorityBgColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red.shade100;
      case 'Medium':
        return Colors.yellow.shade100;
      case 'Low':
        return Colors.green.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  Map<int, String> statusMap = {
    0: 'In Progress',
    1: 'Not Started',
    2: 'On Hold',
    3: 'Completed',
  };
  Color getStatusColorFromInt(int? status) {
    String? statusStr = statusMap[status ?? 0];

    switch (statusStr) {
      case 'In Progress':
        return Colors.blue.shade700;
      case 'Not Started':
        return Colors.grey.shade600;
      case 'On Hold':
        return Colors.red.shade800;
      case 'Completed':
        return Colors.green.shade800;
      default:
        return Colors.black54;
    }
  }

  // String statusFromInt(int value) {
  //   return statusMap[value] ?? 'In Progress';
  // }

  int statusToInt(String status) {
    return statusMap.entries
        .firstWhere(
          (entry) => entry.value.toLowerCase() == status.toLowerCase(),
          orElse: () => const MapEntry(0, 'In Progress'),
        )
        .key;
  }

  Future<void> fetchProjects() async {
    isLoading.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) {
        SnackbarUtils.showError("Token not found. Please login again.");
        isLoading.value = false;
        return;
      }

      final response = await http.get(
        Uri.parse('https://1.sunshineiot.in/api/v2/todo/project'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final projectData = json.decode(response.body);
        final projectModel = Project.fromJson(projectData);

        final List<Future<Map<String, dynamic>>> futures =
            projectModel.projects?.map((project) async {
              // Build query parameters for this project's tasks
              Map<String, String> queryParams = {
                'project_id': project.id.toString(),
              };
              if (selectedStartDate.value != null) {
                queryParams['start_date'] = DateFormat(
                  'yyyy-MM-dd',
                ).format(selectedStartDate.value!);
              }
              if (selectedTargetDate.value != null)
                queryParams['target_date'] = selectedTargetDate.value!;
              if (selectedStatus.value != null) {
                queryParams['status'] = selectedStatus.value!.toString();
              }

              if (selectedPriority.value != null)
                queryParams['priority'] = selectedPriority.value!;

              final taskUri = Uri.https(
                '1.sunshineiot.in',
                '/api/v2/todo/task',
                queryParams,
              );

              List<Map<String, dynamic>> mappedTasks = [];
              try {
                final taskResp = await http
                    .get(
                      taskUri,
                      headers: {
                        'Content-Type': 'application/json',
                        'Authorization': 'Bearer $token',
                      },
                    )
                    .timeout(Duration(seconds: 10));

                if (taskResp.statusCode == 200) {
                  final taskData = json.decode(taskResp.body);
                  final taskModel = Task.fromJson(taskData);

                  mappedTasks =
                      taskModel.tasks
                          ?.map(
                            (task) => {
                              'id': task.id,
                              'title': task.task ?? '',
                              'note': task.note ?? '',
                              'priority': priorityFromInt(task.priority),
                              'completed': task.status == 1,
                              'targetDate': formatDate(task.targetDate),
                              'start_date': formatDate(task.startDate),
                              'assignedTo': task.assignedToName ?? '',
                              'assigned_to_id': task.assignedToId,
                              'assigned_to_role': 'employee',
                              'assigned_by_id': task.assignedById,
                              'assigned_by_role': 'admin',
                              'project_id': task.projectId,
                            },
                          )
                          .toList() ??
                      [];
                }
              } catch (_) {}

              return {
                'id': project.id,
                'title': project.name ?? 'No Title',
                'desc': project.description ?? '',
                'priority': priorityFromInt(project.priority),
                'status': project.status,
                'tasks': mappedTasks,
                'expanded': false,
                'totalTasks': project.totalTasks ?? 0,
                'completedTasks': project.completedTasks ?? 0,
                'createdBy': project.createdByName ?? '',
                'start_date': formatDate(project.startDate),
                'target_date': formatDate(project.endDate),
              };
            }).toList() ??
            [];

        final results = await Future.wait(futures);
        results.sort(
          (a, b) => priorityOrder[a['priority']]!.compareTo(
            priorityOrder[b['priority']]!,
          ),
        );
        projectTasks.assignAll(results);
        projectList.assignAll(projectModel.projects!);
      } else {
        SnackbarUtils.showError(
          "Failed to fetch projects (${response.statusCode})",
        );
      }
    } catch (e) {
      SnackbarUtils.showError("Failed to fetch: $e");
    } finally {
      isLoading.value = false;
    }
  }

  List<Map<String, dynamic>> get allTasks {
    return projectTasks
        .expand((p) => p['tasks'] as List<Map<String, dynamic>>)
        .toList();
  }

  Future<void> updateTaskStatus(int taskId, bool isCompleted) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) {
        SnackbarUtils.showError("Token not found");
        return;
      }

      Map<String, dynamic>? taskData;
      for (final project in projectTasks) {
        for (final task in project['tasks']) {
          if (task['id'] == taskId) {
            taskData = task;
            break;
          }
        }
        if (taskData != null) break;
      }

      if (taskData == null) {
        SnackbarUtils.showError("Task not found");
        return;
      }

      final updateData = {
        "task": taskData['title'] ?? '',
        "note": taskData['note'] ?? '',
        "status": isCompleted ? 1 : 0,
        "priority": getPriorityValue(taskData['priority'] ?? 'Low'),
        "start_date": taskData['start_date'],
        "target_date": taskData['targetDate'],
        "project_id": taskData['project_id'],
        "assigned_by_id": taskData['assigned_by_id'] ?? 1,
        "assigned_by_role": taskData['assigned_by_role'] ?? 'admin',
        "assigned_to_id": taskData['assigned_to_id'],
        "assigned_to_role": taskData['assigned_to_role'] ?? 'employee',
      };

      final response = await http.put(
        Uri.parse('https://1.sunshineiot.in/api/v2/todo/task/$taskId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(updateData),
      );

      final responseData = json.decode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        await fetchProjects();
        SnackbarUtils.showSuccess(
          isCompleted ? 'Marked Completed' : 'Marked Pending',
        );
      } else {
        SnackbarUtils.showError(responseData['message'] ?? 'Update failed');
      }
    } catch (e) {
      SnackbarUtils.showError("Update error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  final RxBool showAddTaskPanel = false.obs;

  Future<void> addProject(Map<String, dynamic> project) async {
    showAddProjectPanel.value = false;
    isLoading.value = true;
    try {
      // POST logic here
      await fetchProjects();
      SnackbarUtils.showSuccess("Project added!");
    } catch (e) {
      SnackbarUtils.showError("Project added but failed to refresh: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addTask(Map<String, dynamic> task) async {
    showAddTaskPanel.value = false;
    isLoading.value = true;
    try {
      // POST logic here
      await fetchProjects();
      SnackbarUtils.showSuccess("Task added!");
    } catch (e) {
      SnackbarUtils.showError("Task added but failed to refresh: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void editProject(Map<String, dynamic> project) {
    selectedProject.value = {
      'id': project['id'],
      'name': project['title'], // ✅ mapped correctly
      'description': project['desc'], // ✅ mapped correctly
      'priority': project['priority'],
      'start_date': project['start_date'],
      'end_date': project['target_date'], // ✅ map to expected key
    };
    showEditProjectPanel.value = true;
  }

  Future<void> updateProject(Map<String, dynamic> updatedProject) async {
    isLoading.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) {
        SnackbarUtils.showError("Token not found. Please login again.");
        return;
      }

      final updateData = {
        "name": updatedProject['title'] ?? '',
        "description": updatedProject['desc'] ?? '',
        "priority": getPriorityValue(updatedProject['priority'] ?? 'Low'),
        "status": updatedProject['status'] ?? 'In Progress',
      };

      if (updatedProject['start_date'] != null) {
        updateData["start_date"] = updatedProject['start_date'];
      }
      if (updatedProject['target_date'] != null) {
        updateData["end_date"] = updatedProject['target_date'];
      }

      final projectId = updatedProject['id'];
      final response = await http.put(
        Uri.parse('https://1.sunshineiot.in/api/v2/todo/project/$projectId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(updateData),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        await fetchProjects(); // Refresh project list

        showEditProjectPanel.value = false;
        SnackbarUtils.showSuccess("Project updated successfully");
      } else {
        SnackbarUtils.showError(responseData['message'] ?? "Update failed");
      }
    } catch (e) {
      SnackbarUtils.showError("Failed to update project: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void confirmDeleteTask(BuildContext context, int taskId) {
    Get.defaultDialog(
      title: "Delete Task?",
      middleText: "Are you sure you want to delete this task?",
      textConfirm: "Yes",
      textCancel: "No",
      confirmTextColor: Colors.white,
      onConfirm: () {
        Get.back(); // Close dialog
        deleteTask(taskId); // Call delete method
      },
    );
  }

  Future<void> deleteProject(int projectId) async {
    isLoading.value = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        SnackbarUtils.showError("Token missing. Please login again.");
        return;
      }

      // ✅ Decode JWT token
      Map<String, dynamic> decodedToken;
      try {
        decodedToken = JwtDecoder.decode(token);
      } catch (e) {
        SnackbarUtils.showError("Could not decode token.");
        return;
      }

      // ✅ Strong Admin Check
      final rpm = decodedToken['rpm']?.toString();
      final email = decodedToken['email']?.toString();
      final isAdmin = (rpm == '15' || email == 'admin@sunshine.com');

      // ❌ STOP if not admin — do NOT call delete API
      if (!isAdmin) {
        SnackbarUtils.showInfo("Only admins can delete projects.");
        return;
      }

      // ✅ Call DELETE API
      final response = await http.delete(
        Uri.parse('https://1.sunshineiot.in/api/v2/todo/project/$projectId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        await fetchProjects(); // 🔄 Refresh project list
        SnackbarUtils.showSuccess("Project deleted!");
      } else {
        SnackbarUtils.showError(responseData['message'] ?? "Delete failed");
      }
    } catch (e) {
      SnackbarUtils.showError("Failed to delete project: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void confirmDeleteProject(BuildContext context, int projectId) {
    Get.defaultDialog(
      title: "Delete Project?",
      middleText: "Are you sure you want to delete this project?",

      textConfirm: "Yes",
      textCancel: "No",
      confirmTextColor: Colors.white,
      onConfirm: () {
        Get.back(); // close dialog
        deleteProject(projectId);
      },
    );
  }

  Future<void> deleteTask(int taskId) async {
    isLoading.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) {
        SnackbarUtils.showError("Token not found");
        return;
      }

      final response = await http.delete(
        Uri.parse('https://1.sunshineiot.in/api/v2/todo/task/$taskId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = json.decode(response.body);
      debugPrint(responseData.toString());
      if (response.statusCode == 200 && responseData['success'] == true) {
        await fetchProjects(); // Refresh list
        SnackbarUtils.showSuccess("Task deleted successfully");
      } else {
        SnackbarUtils.showError(responseData['message'] ?? "Delete failed");
      }
    } catch (e) {
      SnackbarUtils.showError("Failed to delete task: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> editTask(
    int taskId,
    Map<String, dynamic> updatedTaskData,
  ) async {
    isLoading.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) {
        SnackbarUtils.showError("Token not found");
        return;
      }

      final updateData = {
        "task": updatedTaskData['title'] ?? '',
        "note": updatedTaskData['note'] ?? '',
        "status": updatedTaskData['completed'] == true ? 1 : 0,
        "priority": getPriorityValue(updatedTaskData['priority'] ?? 'Low'),
        "start_date": updatedTaskData['start_date'],
        "target_date": updatedTaskData['targetDate'],
        "project_id": updatedTaskData['project_id'],
        "assigned_by_id": updatedTaskData['assigned_by_id'] ?? 1,
        "assigned_by_role": updatedTaskData['assigned_by_role'] ?? 'admin',
        "assigned_to_id": updatedTaskData['assigned_to_id'],
        "assigned_to_role": updatedTaskData['assigned_to_role'] ?? 'employee',
      };

      final response = await http.put(
        Uri.parse('https://1.sunshineiot.in/api/v2/todo/task/$taskId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(updateData),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        setCurrentActionTime(type: "Updated", taskId: taskId);
        await fetchProjects(); // Refresh the task list
        SnackbarUtils.showSuccess("Task updated successfully");
      } else {
        SnackbarUtils.showError(responseData['message'] ?? "Update failed");
      }
    } catch (e) {
      SnackbarUtils.showError("Failed to update task: $e");
    } finally {
      isLoading.value = false;
    }
  }
}
