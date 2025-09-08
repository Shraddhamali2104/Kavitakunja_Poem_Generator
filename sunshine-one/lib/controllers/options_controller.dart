import 'package:get/get.dart';
import '../models/option_model.dart';
import '../services/options_service.dart';

class OptionsController extends GetxController {
  static OptionsController get to => Get.find();

  final OptionsService _optionsService = OptionsService();

  final Rx<OptionsData?> _optionsData = Rx<OptionsData?>(null);
  final RxBool _isLoading = false.obs;
  final RxString _errorMessage = ''.obs;

  // Getters
  OptionsData? get optionsData => _optionsData.value;
  bool get isLoading => _isLoading.value;
  String get errorMessage => _errorMessage.value;
  bool get hasData => _optionsData.value != null;
  bool get hasError => _errorMessage.value.isNotEmpty;

  // Add type IDs for HR/employee fields
  static const int typeBloodGroup = 27;
  static const int typeQualification = 28;
  static const int typeDesignation = 26;
  static const int typePosition = 25;
  static const int typeAttendanceType = 30;
  static const int typeUndefined = 31;
  static const int typeUniversalYesNo = 29;
  //Add tpye IDs for Design/project fields
  static const int typeProjectStatus = 24;
  // Add type IDs for Store/Item fields
  static const int typeUnitOfMeasurement = 11;
  static const int typeGstSlab = 12;
  static const int typeStore = 32;

  @override
  void onInit() {
    super.onInit();
    fetchOptions();
  }

  // Fetch options
  Future<void> fetchOptions() async {
    if (_isLoading.value) return;

    _isLoading.value = true;
    _errorMessage.value = '';

    try {
      final data = await _optionsService.fetchOptions();
      if (data != null) {
        _optionsData.value = data;
      } else {
        _errorMessage.value = 'Failed to fetch options data';
      }
    } catch (e) {
      _errorMessage.value = e.toString();
    } finally {
      _isLoading.value = false;
    }
  }

  // Refresh options (force fetch)
  Future<void> refreshOptions() async {
    _optionsService.clearCache();
    await fetchOptions();
  }

  // Helper methods for reactive access
  List<Option> getOptionsByTypeId(int typeId) {
    return _optionsData.value?.getOptionsByTypeId(typeId) ?? [];
  }

  List<Option> getOptionsByTypeName(String typeName) {
    return _optionsData.value?.getOptionsByTypeName(typeName) ?? [];
  }

  List<String> getDropdownItemsByTypeId(int typeId) {
    return _optionsData.value?.getDropdownItemsByTypeId(typeId) ?? [];
  }

  List<String> getDropdownItemsByTypeName(String typeName) {
    return _optionsData.value?.getDropdownItemsByTypeName(typeName) ?? [];
  }

  List<String> getDropdownItemsWithIdByTypeId(int typeId) {
    return _optionsData.value?.getDropdownItemsWithIdByTypeId(typeId) ?? [];
  }

  List<String> getDropdownItemsWithIdByTypeName(String typeName) {
    return _optionsData.value?.getDropdownItemsWithIdByTypeName(typeName) ?? [];
  }

  String? getOptionNameById(int optionId) {
    return _optionsData.value?.getOptionNameById(optionId);
  }

  int? getOptionIdByName(String optionName) {
    return _optionsData.value?.getOptionIdByName(optionName);
  }

  String? getOptionDisplayById(int optionId) {
    final optionName = getOptionNameById(optionId);
    if (optionName != null) {
      return '$optionId - $optionName';
    }
    return null;
  }

  // Convenience methods for common types
  List<Option> get domainOptions =>
      getOptionsByTypeId(OptionsService.typeDomain);
  List<Option> get creditTypeOptions =>
      getOptionsByTypeId(OptionsService.typeCreditType);
  List<Option> get supplierTypeOptions =>
      getOptionsByTypeId(OptionsService.typeSupplierType);
  List<Option> get originOptions =>
      getOptionsByTypeId(OptionsService.typeOrigin);
  List<Option> get categoryOptions =>
      getOptionsByTypeId(OptionsService.typeCategory);
  List<Option> get gstTypeOptions =>
      getOptionsByTypeId(OptionsService.typeGstType);
  List<Option> get paymentTermOptions =>
      getOptionsByTypeId(OptionsService.typePaymentTerm);
  List<Option> get itemTypeOptions =>
      getOptionsByTypeId(OptionsService.typeItemType);
  List<Option> get itemCategoryOptions =>
      getOptionsByTypeId(OptionsService.typeItemCategory);
  List<Option> get countryOptions =>
      getOptionsByTypeId(OptionsService.typeCountryName);
  List<Option> get serviceTypeOptions =>
      getOptionsByTypeId(OptionsService.typeServiceType);
  List<Option> get grnTypeOptions =>
      getOptionsByTypeId(OptionsService.typeGrnType);
  List<Option> get grnStatusOptions =>
      getOptionsByTypeId(OptionsService.typeGrnStatus);
  List<Option> get projectStatusOptions =>
      getOptionsByTypeId(OptionsService.typeProjectStatus);

  // Store/Item specific options
  List<Option> get uomOptions => getOptionsByTypeId(typeUnitOfMeasurement);
  List<Option> get gstSlabOptions => getOptionsByTypeId(typeGstSlab);
  List<Option> get storeOptions => getOptionsByTypeId(typeStore);

  // Fallback methods in case type IDs are incorrect
  List<Option> get uomOptionsByName => getOptionsByTypeName('Unit of Measurement');
  List<Option> get uomOptionsByNameAlt => getOptionsByTypeName('UOM');
  List<Option> get gstSlabOptionsByName => getOptionsByTypeName('GST Slab');

  // Convenience methods for dropdown items
  List<String> get domainDropdownItems =>
      getDropdownItemsByTypeId(OptionsService.typeDomain);
  List<String> get creditTypeDropdownItems =>
      getDropdownItemsByTypeId(OptionsService.typeCreditType);
  List<String> get supplierTypeDropdownItems =>
      getDropdownItemsByTypeId(OptionsService.typeSupplierType);
  List<String> get originDropdownItems =>
      getDropdownItemsByTypeId(OptionsService.typeOrigin);
  List<String> get categoryDropdownItems =>
      getDropdownItemsByTypeId(OptionsService.typeCategory);
  List<String> get gstTypeDropdownItems =>
      getDropdownItemsByTypeId(OptionsService.typeGstType);
  List<String> get paymentTermDropdownItems =>
      getDropdownItemsByTypeId(OptionsService.typePaymentTerm);
  List<String> get itemTypeDropdownItems =>
      getDropdownItemsByTypeId(OptionsService.typeItemType);
  List<String> get itemCategoryDropdownItems =>
      getDropdownItemsByTypeId(OptionsService.typeItemCategory);
  List<String> get countryDropdownItems =>
      getDropdownItemsByTypeId(OptionsService.typeCountryName);
  List<String> get serviceTypeDropdownItems =>
      getDropdownItemsByTypeId(OptionsService.typeServiceType);
  List<String> get grnTypeDropdownItems =>
      getDropdownItemsByTypeId(OptionsService.typeGrnType);
  List<String> get grnStatusDropdownItems =>
      getDropdownItemsByTypeId(OptionsService.typeGrnStatus);
  List<String> get projectStatusDropdownItems =>
      getDropdownItemsByTypeId(OptionsService.typeProjectStatus);

  // Store/Item specific dropdown items
  List<String> get uomDropdownItems =>
      getDropdownItemsByTypeId(typeUnitOfMeasurement);
  List<String> get gstSlabDropdownItems =>
      getDropdownItemsByTypeId(typeGstSlab);

  // Convenience methods for dropdown items with ID
  List<String> get domainDropdownItemsWithId =>
      getDropdownItemsWithIdByTypeId(OptionsService.typeDomain);
  List<String> get creditTypeDropdownItemsWithId =>
      getDropdownItemsWithIdByTypeId(OptionsService.typeCreditType);
  List<String> get supplierTypeDropdownItemsWithId =>
      getDropdownItemsWithIdByTypeId(OptionsService.typeSupplierType);
  List<String> get originDropdownItemsWithId =>
      getDropdownItemsWithIdByTypeId(OptionsService.typeOrigin);
  List<String> get categoryDropdownItemsWithId =>
      getDropdownItemsWithIdByTypeId(OptionsService.typeCategory);
  List<String> get gstTypeDropdownItemsWithId =>
      getDropdownItemsWithIdByTypeId(OptionsService.typeGstType);
  List<String> get paymentTermDropdownItemsWithId =>
      getDropdownItemsWithIdByTypeId(OptionsService.typePaymentTerm);
  List<String> get itemTypeDropdownItemsWithId =>
      getDropdownItemsWithIdByTypeId(OptionsService.typeItemType);
  List<String> get itemCategoryDropdownItemsWithId =>
      getDropdownItemsWithIdByTypeId(OptionsService.typeItemCategory);
  List<String> get countryDropdownItemsWithId =>
      getDropdownItemsWithIdByTypeId(OptionsService.typeCountryName);
  List<String> get serviceTypeDropdownItemsWithId =>
      getDropdownItemsWithIdByTypeId(OptionsService.typeServiceType);
  List<String> get grnTypeDropdownItemsWithId =>
      getDropdownItemsWithIdByTypeId(OptionsService.typeGrnType);
  List<String> get grnStatusDropdownItemsWithId =>
      getDropdownItemsWithIdByTypeId(OptionsService.typeGrnStatus);
  List<String> get projectStatusDropdownItemsWithId =>
      getDropdownItemsWithIdByTypeId(OptionsService.typeProjectStatus);

  // Store/Item specific dropdown items with ID
  List<String> get uomDropdownItemsWithId =>
      getDropdownItemsWithIdByTypeId(typeUnitOfMeasurement);
  List<String> get gstSlabDropdownItemsWithId =>
      getDropdownItemsWithIdByTypeId(typeGstSlab);

  // Convenience methods for HR/employee fields
  List<Option> get bloodGroupOptions => getOptionsByTypeId(typeBloodGroup);
  List<Option> get qualificationOptions =>
      getOptionsByTypeId(typeQualification);
  List<Option> get designationOptions => getOptionsByTypeId(typeDesignation);
  List<Option> get positionOptions => getOptionsByTypeId(typePosition);
  List<Option> get attendanceTypeOptions =>
      getOptionsByTypeId(typeAttendanceType);
  List<Option> get undefinedOptions => getOptionsByTypeId(typeUndefined);
  List<Option> get universalYesNoOptions =>
      getOptionsByTypeId(typeUniversalYesNo);

  List<String> get bloodGroupDropdownItems =>
      getDropdownItemsByTypeId(typeBloodGroup);
  List<String> get qualificationDropdownItems =>
      getDropdownItemsByTypeId(typeQualification);
  List<String> get designationDropdownItems =>
      getDropdownItemsByTypeId(typeDesignation);
  List<String> get positionDropdownItems =>
      getDropdownItemsByTypeId(typePosition);
  List<String> get attendanceTypeDropdownItems =>
      getDropdownItemsByTypeId(typeAttendanceType);
  List<String> get undefinedDropdownItems =>
      getDropdownItemsByTypeId(typeUndefined);

  // Clear error
  void clearError() {
    _errorMessage.value = '';
  }

  // Clear data
  void clearData() {
    _optionsData.value = null;
    _errorMessage.value = '';
  }

  // Add this method to get Option by typeId and optionId
  Option? getOptionByTypeAndId(int typeId, int optionId) {
    final options = getOptionsByTypeId(typeId);
    try {
      return options.firstWhere((option) => option.optionId == optionId);
    } catch (e) {
      return null;
    }
  }
}
