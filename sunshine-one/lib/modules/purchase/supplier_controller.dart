import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'supplier_model.dart';

class SupplierController extends GetxController {
  var suppliers = <Data>[].obs;
  var isLoading = false.obs;
  var errorMessage = ''.obs;
  var currentPage = 1.obs;
  var totalPages = 1.obs;
  var totalCount = 0.obs;
  var searchText = ''.obs;

  // UI state for layout
  var showSupplierForm = false.obs;
  var showSearchBar = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchSuppliers(page: 1);
    debounce(
      searchText,
      (_) => fetchSuppliers(page: 1, query: searchText.value.trim()),
      time: const Duration(milliseconds: 300),
    );
  }

  Future<void> fetchSuppliers({int page = 1, String? query, int limit = 10}) async {
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
        '/api/v2/purchase/supplier/all',
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
        final supplierModel = Supplier.fromJson(jsonBody);
        suppliers.value = supplierModel.data ?? [];
        currentPage.value = supplierModel.page ?? page;
        totalPages.value = supplierModel.totalPages ?? 1;
        totalCount.value = supplierModel.total ?? 0;
      } else {
        errorMessage.value = 'Failed to load suppliers: ${response.statusCode}';
        suppliers.clear();
        totalCount.value = 0;
      }
    } catch (e) {
      errorMessage.value = 'Error: ${e.toString()}';
      suppliers.clear();
      totalCount.value = 0;
    }
    isLoading.value = false;
  }
}
