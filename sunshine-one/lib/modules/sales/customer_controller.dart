import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'customer_model.dart';

class CustomerController extends GetxController {
  var customers = <Data>[].obs;
  var isLoading = false.obs;
  var errorMessage = ''.obs;
  var currentPage = 1.obs;
  var totalPages = 1.obs;
  var totalCount = 0.obs;

  // UI state
  var showCustomerForm = false.obs;
  var showSearchBar = false.obs;
  var searchText = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchCustomers(page: 1);
    debounce(
      searchText,
      (_) => fetchCustomers(page: 1, query: searchText.value.trim()),
      time: const Duration(milliseconds: 350),
    );
  }

  Future<void> fetchCustomers({int page = 1, String? query, int limit = 10}) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) {
        errorMessage.value = 'No authentication token found.';
        isLoading.value = false;
        return;
      }
      final params = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (query != null && query.isNotEmpty) {
        params['search'] = query;
      }
      final uri = Uri.https(
        '1.sunshineiot.in',
        '/api/v2/sale/customer/all',
        params,
      );
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final jsonBody = json.decode(response.body);
        final customerModel = Customer.fromJson(jsonBody);
        customers.value = customerModel.data ?? [];
        currentPage.value = customerModel.page ?? page;
        totalPages.value = customerModel.totalPages ?? 1;
        totalCount.value = customerModel.total ?? 0;
      } else {
        errorMessage.value = 'Failed to load customers: ${response.statusCode}';
        customers.clear();
        totalCount.value = 0;
      }
    } catch (e) {
      errorMessage.value = 'Error: ${e.toString()}';
      customers.clear();
      totalCount.value = 0;
    }
    isLoading.value = false;
  }

  // Force refresh the customer list
  Future<void> refreshCustomers({int? limit}) async {
    await fetchCustomers(page: 1, query: searchText.value, limit: limit ?? 10);
  }
}
