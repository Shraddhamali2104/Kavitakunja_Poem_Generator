// project_page_controller.dart
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:myoffice_sunshine/utils/snackbar_message.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'project_model.dart';
import 'package:flutter/foundation.dart';

class ProjectPageController extends GetxController {
  RxString currentPage = 'list'.obs;
  RxList<Project> projectList = <Project>[].obs;
  RxBool isLoading = false.obs;

  @override
  void onInit() {
    fetchProjects();
    super.onInit();
  }

  void changePage(String page) {
    currentPage.value = page;
  }

  Future<void> fetchProjects() async {
    try {
      isLoading.value = true;
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('https://1.sunshineiot.in/api/v2/design/project'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        projectList.value = data.map((json) => Project.fromJson(json)).toList();
      } else {
        SnackbarUtils.showError("Fail to load project");
      }
    } catch (e) {
      SnackbarUtils.showError("Error fetching projects: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> addProject(Project project) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final payload = project.toJson();
      debugPrint("📦 Sending Project: ${jsonEncode(payload)}");

      final response = await http.post(
        Uri.parse('https://1.sunshineiot.in/api/v2/design/project'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      debugPrint('📥 Response ${response.statusCode}: ${response.body}');

      final jsonRes = jsonDecode(response.body);

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          (jsonRes['success'] == true || jsonRes['id'] != null)) {
        await fetchProjects();
        return true;
      } else {
        // Only show error message if not already shown
        SnackbarUtils.showError(jsonRes['message'] ?? 'Unknown error occurred');
        return false;
      }
    } catch (e) {
      SnackbarUtils.showError(' ${e.toString()}');
      return false;
    }
  }
}
