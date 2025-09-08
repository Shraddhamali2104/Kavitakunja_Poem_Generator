import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/option_model.dart';

class OptionsService {
  static final OptionsService _instance = OptionsService._internal();
  factory OptionsService() => _instance;
  OptionsService._internal();

  OptionsData? _optionsData;
  bool _isLoading = false;
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  // Getters
  OptionsData? get optionsData => _optionsData;
  bool get isLoading => _isLoading;
  bool get hasData => _optionsData != null;
  bool get isCacheValid => _lastFetchTime != null && 
      DateTime.now().difference(_lastFetchTime!) < _cacheDuration;

  // Fetch options from API
  Future<OptionsData?> fetchOptions() async {
    // Return cached data if it's still valid
    if (isCacheValid && _optionsData != null) {
      return _optionsData;
    }

    if (_isLoading) {
      // Wait for ongoing request to complete
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _optionsData;
    }

    _isLoading = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('https://1.sunshineiot.in/api/v2/admin/option/types-options'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _optionsData = OptionsData.fromJson(data);
        _lastFetchTime = DateTime.now();
        return _optionsData;
      } else {
        throw Exception('Failed to fetch options: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch options: $e');
    } finally {
      _isLoading = false;
    }
  }

  // Force refresh options (ignores cache)
  Future<OptionsData?> refreshOptions() async {
    _lastFetchTime = null;
    return await fetchOptions();
  }

  // Helper methods for easy access
  Future<List<Option>> getOptionsByTypeId(int typeId) async {
    final data = await fetchOptions();
    return data?.getOptionsByTypeId(typeId) ?? [];
  }

  Future<List<Option>> getOptionsByTypeName(String typeName) async {
    final data = await fetchOptions();
    return data?.getOptionsByTypeName(typeName) ?? [];
  }

  Future<List<String>> getDropdownItemsByTypeId(int typeId) async {
    final data = await fetchOptions();
    return data?.getDropdownItemsByTypeId(typeId) ?? [];
  }

  Future<List<String>> getDropdownItemsByTypeName(String typeName) async {
    final data = await fetchOptions();
    return data?.getDropdownItemsByTypeName(typeName) ?? [];
  }

  Future<List<String>> getDropdownItemsWithIdByTypeId(int typeId) async {
    final data = await fetchOptions();
    return data?.getDropdownItemsWithIdByTypeId(typeId) ?? [];
  }

  Future<List<String>> getDropdownItemsWithIdByTypeName(String typeName) async {
    final data = await fetchOptions();
    return data?.getDropdownItemsWithIdByTypeName(typeName) ?? [];
  }

  Future<String?> getOptionNameById(int optionId) async {
    final data = await fetchOptions();
    return data?.getOptionNameById(optionId);
  }

  Future<int?> getOptionIdByName(String optionName) async {
    final data = await fetchOptions();
    return data?.getOptionIdByName(optionName);
  }

  // Extract option ID from "ID - Name" format
  static int? extractOptionId(String displayValue) {
    if (displayValue.isEmpty || displayValue == 'Select Option') return null;
    if (displayValue.contains(' - ')) {
      final idPart = displayValue.split(' - ').first;
      return int.tryParse(idPart);
    }
    return int.tryParse(displayValue);
  }

  // Extract option name from "ID - Name" format
  static String? extractOptionName(String displayValue) {
    if (displayValue.isEmpty || displayValue == 'Select Option') return null;
    if (displayValue.contains(' - ')) {
      return displayValue.split(' - ').last;
    }
    return displayValue;
  }

  // Get option display value from ID
  Future<String?> getOptionDisplayById(int optionId) async {
    final optionName = await getOptionNameById(optionId);
    if (optionName != null) {
      return '$optionId - $optionName';
    }
    return null;
  }

  // Clear cache
  void clearCache() {
    _optionsData = null;
    _lastFetchTime = null;
  }

  // Predefined type IDs for common use cases
  static const int typeDomain = 1;
  static const int typeCreditType = 2;
  static const int typeSupplierType = 3;
  static const int typeOrigin = 4;
  static const int typeCategory = 5;
  static const int typeGstType = 6;
  static const int typePaymentTerm = 7;
  static const int typeItemType = 8;
  static const int typeItemCategory = 9;
  static const int typeCountryName = 10;
  static const int typeUnitOfMeasurement = 11;
  static const int typeGstSlab = 12;
  static const int typeServiceType = 21;
  static const int typeGrnType = 22;
  static const int typeGrnStatus = 23;
  static const int typeProjectStatus = 24;
  static const int typeStore = 32;

  // Convenience methods for common types
  Future<List<Option>> getDomainOptions() async => await getOptionsByTypeId(typeDomain);
  Future<List<Option>> getCreditTypeOptions() async => await getOptionsByTypeId(typeCreditType);
  Future<List<Option>> getSupplierTypeOptions() async => await getOptionsByTypeId(typeSupplierType);
  Future<List<Option>> getOriginOptions() async => await getOptionsByTypeId(typeOrigin);
  Future<List<Option>> getCategoryOptions() async => await getOptionsByTypeId(typeCategory);
  Future<List<Option>> getGstTypeOptions() async => await getOptionsByTypeId(typeGstType);
  Future<List<Option>> getPaymentTermOptions() async => await getOptionsByTypeId(typePaymentTerm);
  Future<List<Option>> getItemTypeOptions() async => await getOptionsByTypeId(typeItemType);
  Future<List<Option>> getItemCategoryOptions() async => await getOptionsByTypeId(typeItemCategory);
  Future<List<Option>> getCountryOptions() async => await getOptionsByTypeId(typeCountryName);
  Future<List<Option>> getUomOptions() async => await getOptionsByTypeId(typeUnitOfMeasurement);
  Future<List<Option>> getGstSlabOptions() async => await getOptionsByTypeId(typeGstSlab);
  Future<List<Option>> getServiceTypeOptions() async => await getOptionsByTypeId(typeServiceType);
  Future<List<Option>> getGrnTypeOptions() async => await getOptionsByTypeId(typeGrnType);
  Future<List<Option>> getGrnStatusOptions() async => await getOptionsByTypeId(typeGrnStatus);
  Future<List<Option>> getProjectStatusOptions() async => await getOptionsByTypeId(typeProjectStatus);
  Future<List<Option>> getStoreOptions() async => await getOptionsByTypeId(typeStore);

  // Convenience methods for dropdown items
  Future<List<String>> getDomainDropdownItems() async => await getDropdownItemsByTypeId(typeDomain);
  Future<List<String>> getCreditTypeDropdownItems() async => await getDropdownItemsByTypeId(typeCreditType);
  Future<List<String>> getSupplierTypeDropdownItems() async => await getDropdownItemsByTypeId(typeSupplierType);
  Future<List<String>> getOriginDropdownItems() async => await getDropdownItemsByTypeId(typeOrigin);
  Future<List<String>> getCategoryDropdownItems() async => await getDropdownItemsByTypeId(typeCategory);
  Future<List<String>> getGstTypeDropdownItems() async => await getDropdownItemsByTypeId(typeGstType);
  Future<List<String>> getPaymentTermDropdownItems() async => await getDropdownItemsByTypeId(typePaymentTerm);
  Future<List<String>> getItemTypeDropdownItems() async => await getDropdownItemsByTypeId(typeItemType);
  Future<List<String>> getItemCategoryDropdownItems() async => await getDropdownItemsByTypeId(typeItemCategory);
  Future<List<String>> getCountryDropdownItems() async => await getDropdownItemsByTypeId(typeCountryName);
  Future<List<String>> getUomDropdownItems() async => await getDropdownItemsByTypeId(typeUnitOfMeasurement);
  Future<List<String>> getGstSlabDropdownItems() async => await getDropdownItemsByTypeId(typeGstSlab);
  Future<List<String>> getServiceTypeDropdownItems() async => await getDropdownItemsByTypeId(typeServiceType);
  Future<List<String>> getGrnTypeDropdownItems() async => await getDropdownItemsByTypeId(typeGrnType);
  Future<List<String>> getGrnStatusDropdownItems() async => await getDropdownItemsByTypeId(typeGrnStatus);
  Future<List<String>> getProjectStatusDropdownItems() async => await getDropdownItemsByTypeId(typeProjectStatus);
  Future<List<String>> getStoreDropdownItems() async => await getDropdownItemsByTypeId(typeStore);
} 