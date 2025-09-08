import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:myoffice_sunshine/utils/snackbar_message.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'holiday_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HolidayController extends GetxController {
  RxList<Holidays> holidays = <Holidays>[].obs;
  RxBool isLoading = false.obs;
  RxInt selectedYear = DateTime.now().year.obs;
  RxList<bool> expandedMonths = List.generate(12, (_) => false).obs;

  List<int> get availableYears {
    final now = DateTime.now().year;
    return [for (int y = now-1; y <= now + 15; y++) y];
  }

  Future<void> fetchHolidays() async {
    isLoading.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return;

      final url = Uri.https('1.sunshineiot.in', '/api/v2/hr/holiday', {
        'year': selectedYear.value.toString(),
      });

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        holidays.value = data.map((json) => Holidays.fromJson(json)).toList();

        // Keep all collapsed initially
        expandedMonths.value = List.generate(12, (_) => false);
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> confirmAndDeleteHoliday(
    BuildContext context,
    String date,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete the holiday on $date?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await deleteHoliday(date);

      final isSuccess = result?.$1 == true;
      final message = result?.$2 ?? 'Unknown response';

      if (isSuccess) {
        SnackbarUtils.showSuccess(message);
      } else {
        SnackbarUtils.showError(message);
      }
    }
  }

  Future<(bool, String)?> deleteHoliday(String dateStr) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return (false, "Token not found");

      // Convert dd-MM-yyyy → yyyy-MM-dd
      final parsedDate = DateFormat('dd-MM-yyyy').parse(dateStr);
      final formattedDate = DateFormat('yyyy-MM-dd').format(parsedDate);

      final url = Uri.parse('https://1.sunshineiot.in/api/v2/hr/holiday');
      final body = jsonEncode([
        {"holiday_date": formattedDate},
      ]);

      final request = http.Request("DELETE", url)
        ..headers.addAll({
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        })
        ..body = body;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // print(
      //   "DELETE request for $formattedDate returned ${response.statusCode}: ${response.body}",
      // );

      if (response.statusCode == 200) {
        final List<dynamic> res = json.decode(response.body);
        final failed = res.firstWhere(
          (e) => e['status'] != 'success',
          orElse: () => null,
        );

        if (failed != null) {
          return (false, failed['message']?.toString() ?? "Deletion failed");
        }

        await fetchHolidays(); // Refresh the UI
        return (true, "Holiday deleted successfully");
      } else {
        return (false, "Failed - HTTP ${response.statusCode}");
      }
    } catch (e) {
      return (false, "Error: $e");
    }
  }

  Future<void> updateHoliday(Holidays holiday) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) return;

    final response = await http.put(
      Uri.parse('https://1.sunshineiot.in/api/v2/hr/holiday'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(holiday.toJson()),
    );

    final resBody = json.decode(response.body);
    if (response.statusCode == 200 && resBody['data']?['success'] == true) {
      await fetchHolidays();
      SnackbarUtils.showSuccess("Holiday updated successfully");
    } else {
      SnackbarUtils.showError("Failed to update holiday");
    }
  }

  Future<void> addHoliday(Holidays holiday) async {
    // Format the incoming date to ensure consistent comparison
    final newDate = holiday.holidayDate?.trim();
    if (newDate == null || newDate.isEmpty) {
      SnackbarUtils.showError("Invalid date provided");
      return;
    }

    // Check if a holiday with the same date already exists
    final alreadyExists = holidays.any((h) => h.holidayDate == newDate);
    if (alreadyExists) {
      SnackbarUtils.showInfo(
        "A holiday already exists for this date: $newDate",
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) {
      SnackbarUtils.showError("Token not found");
      return;
    }

    final url = Uri.parse('https://1.sunshineiot.in/api/v2/hr/holiday');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(holiday.toJson()),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      await fetchHolidays();
      SnackbarUtils.showSuccess("Holiday added successfully");
    } else {
      SnackbarUtils.showError("Failed to add holiday");
    }
  }
}
