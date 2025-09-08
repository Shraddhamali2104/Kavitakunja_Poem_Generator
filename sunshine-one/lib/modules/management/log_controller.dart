import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:myoffice_sunshine/utils/snackbar_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LogController extends GetxController {
  var logs = <Map<String, dynamic>>[].obs;
  var isLoading = false.obs;

  var searchQuery = ''.obs;
  var selectedStatus = RxnString();
  var selectedModule = RxnString();
  var selectedDate = RxnString();

  var currentPage = 1.obs;
  var totalPages = 1.obs;
  final int limit = 20; // backend default

  final TextEditingController searchController = TextEditingController();
  Timer? _debounce;

  @override
  void onInit() {
    super.onInit();
    fetchLogs(); // initial load
  }

  void clearSearch() {
    searchController.clear();
    searchQuery.value = '';
    currentPage.value = 1;
    fetchLogs();
  }

  void setSearchQuery(String value) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      searchQuery.value = value;
      currentPage.value = 1;
      fetchLogs();
    });
  }

  /// Fetch logs for the current page
  Future<void> fetchLogs() async {
    try {
      isLoading.value = true;

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        SnackbarUtils.showError("Token not found. Please login again.");
        return;
      }

      Map<String, String> queryParams = {
        'page': currentPage.value.toString(),
        'limit': limit.toString(),
      };

      if (selectedStatus.value != null) {
        queryParams['status'] = selectedStatus.value!;
      }
      if (selectedModule.value != null) {
        queryParams['module'] = selectedModule.value!;
      }
      if (selectedDate.value != null) {
        queryParams['timestamp'] = selectedDate.value!;
      }
      if (searchQuery.value.isNotEmpty) {
        queryParams['action'] = searchQuery.value;
      }

      final uri = Uri.https(
        '1.sunshineiot.in',
        '/api/v2/admin/logs',
        queryParams,
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        logs.value = List<Map<String, dynamic>>.from(jsonData['logs'] ?? []);
        totalPages.value = jsonData['totalPages'] ?? 1;
      } else {
        SnackbarUtils.showError("Failed to fetch logs: ${response.statusCode}");
      }
    } catch (e) {
      SnackbarUtils.showError(e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  /// Go to specific page
  void goToPage(int page) {
    if (page >= 1 && page <= totalPages.value) {
      currentPage.value = page;
      fetchLogs();
    }
  }

  Future<void> selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      selectedDate.value = picked.toIso8601String();
      currentPage.value = 1;
      fetchLogs();
    }
  }

  void clearFilters() {
    selectedStatus.value = null;
    selectedModule.value = null;
    selectedDate.value = null;
    currentPage.value = 1;
    fetchLogs();
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }
}
