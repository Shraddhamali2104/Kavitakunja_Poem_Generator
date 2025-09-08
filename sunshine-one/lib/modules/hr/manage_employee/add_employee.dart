import 'package:flutter/material.dart';
import 'package:myoffice_sunshine/utils/snackbar_message.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dropdown_search/dropdown_search.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http_parser/http_parser.dart';
import 'package:get/get.dart';
import '../../../controllers/options_controller.dart';
import '../../../models/option_model.dart';
import '../../../services/employee_service.dart';

List<Option> deduplicateOptions(List<Option> options) {
  final seen = <int>{};
  return options.where((o) => seen.add(o.optionId)).toList();
}

class OptionDropdown extends StatelessWidget {
  final String label;
  final List<Option> options;
  final Option? selected;
  final ValueChanged<Option?> onChanged;
  final bool isLoading;
  final String? error;

  const OptionDropdown({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.isLoading = false,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: isLoading
          ? InputDecorator(
              decoration: InputDecoration(labelText: label),
              child: const CircularProgressIndicator(),
            )
          : error != null && error!.isNotEmpty
          ? InputDecorator(
              decoration: InputDecoration(labelText: label),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            )
          : DropdownButtonFormField<Option>(
              value: selected,
              decoration: InputDecoration(labelText: label),
              items: options.map((option) {
                return DropdownMenuItem<Option>(
                  value: option,
                  child: Text(
                    option.optionName,
                    style: const TextStyle(color: Colors.black),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
              dropdownColor: Colors.white,
              style: const TextStyle(color: Colors.black),
            ),
    );
  }
}

class AddEmployee extends StatefulWidget {
  final int? empId;
  const AddEmployee({super.key, this.empId});

  @override
  AddEmployeeState createState() => AddEmployeeState();
}

class AddEmployeeState extends State<AddEmployee> {
  final _formKey = GlobalKey<FormState>();
  bool _mounted = true;
  bool _isLoading = false;

  // Form controllers
  final _empIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _telegramIdController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emeContact01Controller = TextEditingController();
  final _emeContact02Controller = TextEditingController();
  final _aadharController = TextEditingController();
  final _panController = TextEditingController();
  final _drivingLicenseController = TextEditingController();
  final _currentAddressController = TextEditingController();
  final _permanentAddressController = TextEditingController();
  final _passportController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _bankBranchController = TextEditingController();
  final _ifscController = TextEditingController();
  final _medicalHistoryController = TextEditingController();
  final _salaryController = TextEditingController();
  final _otRateController = TextEditingController();
  final _noOfLeavesController = TextEditingController();
  final _sundayController = TextEditingController();
  final _odAllowanceController = TextEditingController();
  final _lateMarkController = TextEditingController();
  final _workingHoursController = TextEditingController();
  final _contractorController = TextEditingController();
  final _empPfController = TextEditingController();
  final _empEsiController = TextEditingController();
  final _petrolAllowanceController = TextEditingController();
  final _mobileAllowanceController = TextEditingController();
  final _kidEduAllowanceController = TextEditingController();
  final _variableController = TextEditingController();
  final _noteController = TextEditingController();
  final _allowanceSalaryController = TextEditingController();

  // Date fields
  DateTime? _dob;
  DateTime? _doc;
  DateTime? _passportExpiry;
  DateTime? _doj;

  // Reporting to dropdown
  String _reportingTo = 'Select Option';
  List<String> _reportingToList = [];

  XFile? _passportPhotoFile;
  XFile? _fullViewPhotoFile;
  final ImagePicker _picker = ImagePicker();

  // Options controller and selected options
  late OptionsController optionsController;
  Option? selectedBloodGroup;
  Option? selectedQualification;
  Option? selectedDesignation;
  Option? selectedPosition;
  Option? selectedAttendanceType;
  Option? selectedPunch;
  Option? selectedOtApplicable;
  Option? selectedWfh;
  Option? selectedEmpActive;
  Option? undefinedOption;

  // Hardcoded Punch Allowed options
  final List<Option> punchOptions = [
    Option(optionId: 1, optionName: 'Mandatory'),
    Option(optionId: 2, optionName: 'Non-Mandatory'),
  ];

  // Add this field to AddEmployeeState:
  String? selectedContractor;

  bool get isEditMode => widget.empId != null;

  int? selectedPunchId;

  List<String> _contractorList = [];

  bool _isDataReady = false;

  @override
  void initState() {
    super.initState();
    _initializeOptionsController();
    // Set selectedPunchId if selectedPunch is set (for edit mode)
    if (selectedPunch != null) {
      selectedPunchId = selectedPunch!.optionId;
    }
  }

  Future<void> _initializeOptionsController() async {
    try {
      // Get or create the options controller
      if (Get.isRegistered<OptionsController>()) {
        optionsController = Get.find<OptionsController>();
      } else {
        optionsController = Get.put(OptionsController());
      }

      // Ensure options are loaded
      if (!optionsController.hasData) {
        await optionsController.fetchOptions();
      }

      // Initialize undefined option
      undefinedOption = optionsController.getOptionsByTypeId(31).firstOrNull;

      // Set default punch option
      selectedPunch = optionsController.getOptionsByTypeId(29).firstOrNull;

      // Fetch reporting list
      await _fetchReportingToList();
      // Fetch contractor list
      await _fetchContractorList();

      // If in edit mode, fetch and prefill employee data
      if (isEditMode) {
        await _fetchAndPrefillEmployee(widget.empId!);
      }

      // Trigger UI update
      if (mounted) {
        setState(() {
          _isDataReady = true;
        });
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError('Error initializing options: $e');
      }
    }
  }

  @override
  void dispose() {
    _mounted = false;
    _empIdController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _telegramIdController.dispose();
    _phoneController.dispose();
    _emeContact01Controller.dispose();
    _emeContact02Controller.dispose();
    _aadharController.dispose();
    _panController.dispose();
    _drivingLicenseController.dispose();
    _currentAddressController.dispose();
    _permanentAddressController.dispose();
    _passportController.dispose();
    _bankNameController.dispose();
    _bankBranchController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _medicalHistoryController.dispose();
    _salaryController.dispose();
    _otRateController.dispose();
    _noOfLeavesController.dispose();
    _odAllowanceController.dispose();
    _contractorController.dispose();
    _sundayController.dispose();
    _lateMarkController.dispose();
    _workingHoursController.dispose();
    _empPfController.dispose();
    _empEsiController.dispose();
    _petrolAllowanceController.dispose();
    _mobileAllowanceController.dispose();
    _kidEduAllowanceController.dispose();
    _variableController.dispose();
    _noteController.dispose();
    _allowanceSalaryController.dispose();
    super.dispose();
  }

  Future<void> _fetchReportingToList() async {
    if (!_mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('https://1.sunshineiot.in/api/v2/hr/employee/id-name'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (!_mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> employees = json.decode(response.body);
        setState(() {
          _reportingToList =
              ['Select Option'] +
              employees
                  .where((e) => e['emp_id'] != null && e['emp_name'] != null)
                  .map((e) => '${e['emp_id']} - ${e['emp_name']}')
                  .toList();
        });
      }
    } catch (e) {
      if (!_mounted) return;
      if (!mounted) return;
      SnackbarUtils.showError('Error fetching employees list: $e');
    }
  }

  Future<void> _fetchContractorList() async {
    if (!_mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final response = await http.get(
        Uri.parse('https://1.sunshineiot.in/api/v2/hr/employee/contractor'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (!_mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> contractors = json.decode(response.body);
        setState(() {
          _contractorList =
              ['Select Option'] +
              contractors
                  .where((e) => e['emp_id'] != null && e['emp_name'] != null)
                  .map((e) => '${e['emp_id']} - ${e['emp_name']}')
                  .toList();
        });
      }
    } catch (e) {
      if (!_mounted) return;
      if (!mounted) return;
      SnackbarUtils.showError('Error fetching contractors list: $e');
    }
  }

  Future<void> _fetchAndPrefillEmployee(int empId) async {
    // Fetch employee data by ID and prefill all controllers and selected options
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final response = await http.get(
      Uri.parse('https://1.sunshineiot.in/api/v2/hr/employee/all'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> employees = json.decode(response.body);
      final emp = employees.firstWhere(
        (e) => e['emp_id'].toString() == empId.toString(),
        orElse: () => null,
      );
      if (emp != null) {
        setState(() {
          _empIdController.text = emp['emp_id']?.toString() ?? '';
          _nameController.text = emp['emp_name'] ?? '';
          _emailController.text = emp['emp_email_id'] ?? '';
          _telegramIdController.text = emp['emp_telegram_id'] ?? '';
          _phoneController.text = emp['emp_phone_no'] ?? '';
          _emeContact01Controller.text = emp['emp_emergency_no_01'] ?? '';
          _emeContact02Controller.text = emp['emp_emergency_no_02'] ?? '';
          _aadharController.text = emp['emp_aadhar'] ?? '';
          _panController.text = emp['emp_pan'] ?? '';
          _drivingLicenseController.text = emp['emp_driving_license'] ?? '';
          _currentAddressController.text = emp['emp_current_address'] ?? '';
          _permanentAddressController.text = emp['emp_permanent_address'] ?? '';
          _passportController.text = emp['emp_passport_no'] ?? '';
          _bankNameController.text = emp['emp_bank_name'] ?? '';
          _accountNumberController.text = emp['emp_bank_account'] ?? '';
          _bankBranchController.text = emp['emp_bank_branch'] ?? '';
          _ifscController.text = emp['emp_bank_ifsc'] ?? '';
          _medicalHistoryController.text = emp['emp_medical_history'] ?? '';
          _salaryController.text = emp['emp_salary']?.toString() ?? '';
          _noOfLeavesController.text = emp['emp_no_leaves']?.toString() ?? '';
          _empPfController.text = emp['emp_pf_no'] ?? '';
          _empEsiController.text = emp['emp_esic_no'] ?? '';
          _petrolAllowanceController.text =
              emp['emp_petrol_allowance']?.toString() ?? '';
          _mobileAllowanceController.text =
              emp['emp_mobile_allowance']?.toString() ?? '';
          _kidEduAllowanceController.text =
              emp['emp_kid_education']?.toString() ?? '';
          _variableController.text = emp['emp_variable']?.toString() ?? '';
          _noteController.text = emp['emp_note'] ?? '';
          _contractorController.text = emp['emp_contractor'] ?? '';
          // Date fields
          _dob = emp['emp_dob'] != null
              ? DateTime.tryParse(emp['emp_dob'].toString())
              : null;
          _doc = emp['emp_docel'] != null
              ? DateTime.tryParse(emp['emp_docel'].toString())
              : null;
          _passportExpiry = emp['emp_passport_valid_till'] != null
              ? DateTime.tryParse(emp['emp_passport_valid_till'].toString())
              : null;
          _doj = emp['emp_date_of_joining'] != null
              ? DateTime.tryParse(emp['emp_date_of_joining'].toString())
              : null;
          // Dropdowns
          selectedBloodGroup = optionsController.getOptionByTypeAndId(
            27,
            int.tryParse(emp['emp_blood_group'].toString()) ?? 0,
          );
          selectedQualification = optionsController.getOptionByTypeAndId(
            28,
            int.tryParse(emp['emp_qualification'].toString()) ?? 0,
          );
          selectedDesignation = optionsController.getOptionByTypeAndId(
            26,
            int.tryParse(emp['emp_designation'].toString()) ?? 0,
          );
          selectedPosition = optionsController.getOptionByTypeAndId(
            25,
            int.tryParse(emp['emp_position'].toString()) ?? 0,
          );
          selectedAttendanceType = optionsController.getOptionByTypeAndId(
            30,
            int.tryParse(emp['emp_attendance_type'].toString()) ?? 0,
          );
          selectedPunch = optionsController.getOptionByTypeAndId(
            29,
            int.tryParse(emp['emp_is_punch_allowed'].toString()) ?? 0,
          );
          selectedOtApplicable = optionsController.getOptionByTypeAndId(
            29,
            int.tryParse(emp['emp_is_ot_applicable'].toString()) ?? 0,
          );
          selectedWfh = optionsController.getOptionByTypeAndId(
            29,
            int.tryParse(emp['emp_work_from_home'].toString()) ?? 0,
          );
          selectedEmpActive = optionsController.getOptionByTypeAndId(
            29,
            int.tryParse(emp['emp_active_status'].toString()) ?? 0,
          );
          _reportingTo = _reportingToList.firstWhere(
            (item) => item.startsWith('${emp['emp_reporting_to']} -'),
            orElse: () => 'Select Option',
          );
          selectedContractor =
              emp['emp_contractor'] != null && emp['emp_contractor'] != 'null'
              ? _contractorList.firstWhere(
                  (item) => item.startsWith('${emp['emp_contractor']} -'),
                  orElse: () => '',
                )
              : null;
          selectedPunchId = selectedPunch?.optionId;
        });
      }
    }
  }

  Future<void> _pickPassportPhoto() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _passportPhotoFile = pickedFile;
      });
    }
  }

  Future<void> _pickFullViewPhoto() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _fullViewPhotoFile = pickedFile;
      });
    }
  }

  Future<void> _submitForm() async {
    debugPrint('=== FORM SUBMISSION START ===');
    debugPrint('Form validation: ${_formKey.currentState?.validate()}');

    if (!_formKey.currentState!.validate()) {
      debugPrint('Form validation failed - stopping submission');
      return;
    }

    debugPrint('Form validation passed - proceeding with submission');
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('=== INITIALIZING REQUEST ===');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      debugPrint('Token available: ${token != null}');

      final url = Uri.parse('https://1.sunshineiot.in/api/v2/hr/employee/');
      debugPrint('Request URL: $url');

      // Helper function to safely parse numeric values
      int? safeParseInt(String? value) {
        debugPrint('safeParseInt called with: "$value"');
        if (value == null || value.isEmpty || value.trim().isEmpty) {
          debugPrint('safeParseInt: returning null (empty value)');
          return null;
        }
        final parsed = int.tryParse(value.trim());
        debugPrint('safeParseInt: parsed result: $parsed');
        return parsed;
      }

      // Helper function to safely parse double values
      // double? safeParseDouble(String? value) {
      //   debugPrint('safeParseDouble called with: "$value"');
      //   if (value == null || value.isEmpty || value.trim().isEmpty) {
      //     debugPrint('safeParseDouble: returning null (empty value)');
      //     return null;
      //   }
      //   final parsed = double.tryParse(value.trim());
      //   debugPrint('safeParseDouble: parsed result: $parsed');
      //   return parsed;
      // }

      // Helper function to safely get option ID
      int? safeGetOptionId(Option? option) {
        debugPrint('safeGetOptionId called with: ${option?.optionName}');
        final result = option?.optionId;
        debugPrint('safeGetOptionId: returning $result');
        return result;
      }

      // Helper function to clean string values
      String? cleanString(String? value) {
        debugPrint('cleanString called with: "$value"');
        if (value == null || value.trim().isEmpty) {
          debugPrint('cleanString: returning null (empty value)');
          return null;
        }
        final result = value.trim();
        debugPrint('cleanString: returning "$result"');
        return result;
      }

      // Helper function to safely extract employee ID
      int? safeExtractEmployeeId(String? displayValue) {
        debugPrint('safeExtractEmployeeId called with: "$displayValue"');
        if (displayValue == null ||
            displayValue == 'Select Option' ||
            displayValue.trim().isEmpty) {
          debugPrint(
            'safeExtractEmployeeId: returning null (empty/select option)',
          );
          return null;
        }
        if (displayValue.contains(' - ')) {
          final idPart = displayValue.split(' - ').first.trim();
          final result = int.tryParse(idPart);
          debugPrint(
            'safeExtractEmployeeId: extracted ID: $result from "$idPart"',
          );
          return result;
        }
        final result = int.tryParse(displayValue.trim());
        debugPrint('safeExtractEmployeeId: parsed result: $result');
        return result;
      }

      // Helper function to validate and clean numeric string
      String? cleanNumericString(String? value) {
        debugPrint('cleanNumericString called with: "$value"');
        if (value == null || value.trim().isEmpty) {
          debugPrint('cleanNumericString: returning null (empty value)');
          return null;
        }
        final cleaned = value.trim();
        if (double.tryParse(cleaned) != null) {
          debugPrint(
            'cleanNumericString: returning "$cleaned" (valid numeric)',
          );
          return cleaned;
        }
        debugPrint('cleanNumericString: returning null (invalid numeric)');
        return null;
      }

      // Helper function to safely format dates
      String? safeFormatDate(DateTime? date) {
        debugPrint('safeFormatDate called with: $date');
        if (date == null) {
          debugPrint('safeFormatDate: returning null (null date)');
          return null;
        }
        try {
          final result = date.toIso8601String().split('T').first;
          debugPrint('safeFormatDate: returning "$result"');
          return result;
        } catch (e) {
          debugPrint('Error formatting date: $e');
          return null;
        }
      }

      debugPrint('=== CONTROLLER VALUES CHECK ===');
      debugPrint('_empIdController.text: "${_empIdController.text}"');
      debugPrint('_nameController.text: "${_nameController.text}"');
      debugPrint('_emailController.text: "${_emailController.text}"');
      debugPrint('_salaryController.text: "${_salaryController.text}"');
      debugPrint('_noOfLeavesController.text: "${_noOfLeavesController.text}"');
      debugPrint(
        '_petrolAllowanceController.text: "${_petrolAllowanceController.text}"',
      );
      debugPrint(
        '_mobileAllowanceController.text: "${_mobileAllowanceController.text}"',
      );
      debugPrint(
        '_kidEduAllowanceController.text: "${_kidEduAllowanceController.text}"',
      );
      debugPrint('_variableController.text: "${_variableController.text}"');
      debugPrint(
        '_allowanceSalaryController.text: "${_allowanceSalaryController.text}"',
      );

      debugPrint('=== SELECTED OPTIONS CHECK ===');
      debugPrint(
        'selectedBloodGroup: ${selectedBloodGroup?.optionName} (ID: ${selectedBloodGroup?.optionId})',
      );
      debugPrint(
        'selectedQualification: ${selectedQualification?.optionName} (ID: ${selectedQualification?.optionId})',
      );
      debugPrint(
        'selectedDesignation: ${selectedDesignation?.optionName} (ID: ${selectedDesignation?.optionId})',
      );
      debugPrint(
        'selectedPosition: ${selectedPosition?.optionName} (ID: ${selectedPosition?.optionId})',
      );
      debugPrint(
        'selectedAttendanceType: ${selectedAttendanceType?.optionName} (ID: ${selectedAttendanceType?.optionId})',
      );
      debugPrint(
        'selectedPunch: ${selectedPunch?.optionName} (ID: ${selectedPunch?.optionId})',
      );
      debugPrint(
        'selectedOtApplicable: ${selectedOtApplicable?.optionName} (ID: ${selectedOtApplicable?.optionId})',
      );
      debugPrint(
        'selectedWfh: ${selectedWfh?.optionName} (ID: ${selectedWfh?.optionId})',
      );
      debugPrint(
        'selectedEmpActive: ${selectedEmpActive?.optionName} (ID: ${selectedEmpActive?.optionId})',
      );

      debugPrint('=== DATE VALUES CHECK ===');
      debugPrint('_dob: $_dob');
      debugPrint('_doc: $_doc');
      debugPrint('_passportExpiry: $_passportExpiry');
      debugPrint('_doj: $_doj');

      debugPrint('=== REPORTING VALUES CHECK ===');
      debugPrint('_reportingTo: "$_reportingTo"');
      debugPrint('selectedContractor: "$selectedContractor"');

      // Individual field validation and debugging
      debugPrint('=== FIELD VALIDATION START ===');

      final empId = isEditMode
          ? widget.empId
          : (safeParseInt(_empIdController.text) ?? 0);
      debugPrint('emp_id: $empId (type: ${empId.runtimeType})');

      final empName = cleanString(_nameController.text);
      debugPrint('emp_name: $empName (type: ${empName.runtimeType})');

      final empEmail = cleanString(_emailController.text);
      debugPrint('emp_email_id: $empEmail (type: ${empEmail.runtimeType})');

      final empTelegram = cleanString(_telegramIdController.text);
      debugPrint(
        'emp_telegram_id: $empTelegram (type: ${empTelegram.runtimeType})',
      );

      final empPhone = cleanString(_phoneController.text);
      debugPrint('emp_phone_no: $empPhone (type: ${empPhone.runtimeType})');

      final empEmergency01 = cleanString(_emeContact01Controller.text);
      debugPrint(
        'emp_emergency_no_01: $empEmergency01 (type: ${empEmergency01.runtimeType})',
      );

      final empEmergency02 = cleanString(_emeContact02Controller.text);
      debugPrint(
        'emp_emergency_no_02: $empEmergency02 (type: ${empEmergency02.runtimeType})',
      );

      final empAadhar = cleanString(_aadharController.text);
      debugPrint('emp_aadhar: $empAadhar (type: ${empAadhar.runtimeType})');

      final empPan = cleanString(_panController.text);
      debugPrint('emp_pan: $empPan (type: ${empPan.runtimeType})');

      final empDrivingLicense = cleanString(_drivingLicenseController.text);
      debugPrint(
        'emp_driving_license: $empDrivingLicense (type: ${empDrivingLicense.runtimeType})',
      );

      final empCurrentAddress = cleanString(_currentAddressController.text);
      debugPrint(
        'emp_current_address: $empCurrentAddress (type: ${empCurrentAddress.runtimeType})',
      );

      final empPermanentAddress = cleanString(_permanentAddressController.text);
      debugPrint(
        'emp_permanent_address: $empPermanentAddress (type: ${empPermanentAddress.runtimeType})',
      );

      final empDob = safeFormatDate(_dob);
      debugPrint('emp_dob: $empDob (type: ${empDob.runtimeType})');

      final empDocel = safeFormatDate(_doc);
      debugPrint('emp_docel: $empDocel (type: ${empDocel.runtimeType})');

      final empBloodGroup = safeGetOptionId(selectedBloodGroup);
      debugPrint(
        'emp_blood_group: $empBloodGroup (type: ${empBloodGroup.runtimeType})',
      );

      final empQualification = safeGetOptionId(selectedQualification);
      debugPrint(
        'emp_qualification: $empQualification (type: ${empQualification.runtimeType})',
      );

      final empPassportNo = cleanString(_passportController.text);
      debugPrint(
        'emp_passport_no: $empPassportNo (type: ${empPassportNo.runtimeType})',
      );

      final empPassportValidTill = safeFormatDate(_passportExpiry);
      debugPrint(
        'emp_passport_valid_till: $empPassportValidTill (type: ${empPassportValidTill.runtimeType})',
      );

      final empBankName = cleanString(_bankNameController.text);
      debugPrint(
        'emp_bank_name: $empBankName (type: ${empBankName.runtimeType})',
      );

      final empBankAccount = cleanString(_accountNumberController.text);
      debugPrint(
        'emp_bank_account: $empBankAccount (type: ${empBankAccount.runtimeType})',
      );

      final empBankBranch = cleanString(_bankBranchController.text);
      debugPrint(
        'emp_bank_branch: $empBankBranch (type: ${empBankBranch.runtimeType})',
      );

      final empBankIfsc = cleanString(_ifscController.text);
      debugPrint(
        'emp_bank_ifsc: $empBankIfsc (type: ${empBankIfsc.runtimeType})',
      );

      final empDateOfJoining = safeFormatDate(_doj);
      debugPrint(
        'emp_date_of_joining: $empDateOfJoining (type: ${empDateOfJoining.runtimeType})',
      );

      final empMedicalHistory = cleanString(_medicalHistoryController.text);
      debugPrint(
        'emp_medical_history: $empMedicalHistory (type: ${empMedicalHistory.runtimeType})',
      );

      final empDesignation = safeGetOptionId(selectedDesignation);
      debugPrint(
        'emp_designation: $empDesignation (type: ${empDesignation.runtimeType})',
      );

      final empReportingTo = safeExtractEmployeeId(_reportingTo);
      debugPrint(
        'emp_reporting_to: $empReportingTo (type: ${empReportingTo.runtimeType})',
      );

      final empPosition = safeGetOptionId(selectedPosition);
      debugPrint(
        'emp_position: $empPosition (type: ${empPosition.runtimeType})',
      );

      final empIsPunchAllowed = safeGetOptionId(selectedPunch);
      debugPrint(
        'emp_is_punch_allowed: $empIsPunchAllowed (type: ${empIsPunchAllowed.runtimeType})',
      );

      final empAttendanceType = safeGetOptionId(selectedAttendanceType);
      debugPrint(
        'emp_attendance_type: $empAttendanceType (type: ${empAttendanceType.runtimeType})',
      );

      final empSalary = cleanNumericString(_salaryController.text);
      debugPrint('emp_salary: $empSalary (type: ${empSalary.runtimeType})');

      final empIsOtApplicable = safeGetOptionId(selectedOtApplicable);
      debugPrint(
        'emp_is_ot_applicable: $empIsOtApplicable (type: ${empIsOtApplicable.runtimeType})',
      );

      final empNoLeaves = safeParseInt(_noOfLeavesController.text);
      debugPrint(
        'emp_no_leaves: $empNoLeaves (type: ${empNoLeaves.runtimeType})',
      );

      final empWorkFromHome = safeGetOptionId(selectedWfh);
      debugPrint(
        'emp_work_from_home: $empWorkFromHome (type: ${empWorkFromHome.runtimeType})',
      );

      final empActiveStatus = safeGetOptionId(selectedEmpActive);
      debugPrint(
        'emp_active_status: $empActiveStatus (type: ${empActiveStatus.runtimeType})',
      );

      final empNote = cleanString(_noteController.text);
      debugPrint('emp_note: $empNote (type: ${empNote.runtimeType})');

      final empContractor = selectedContractor == null
          ? null
          : safeExtractEmployeeId(selectedContractor);
      debugPrint(
        'emp_contractor: $empContractor (type: ${empContractor.runtimeType})',
      );

      final empPetrolAllowance = cleanNumericString(
        _petrolAllowanceController.text,
      );
      debugPrint(
        'emp_petrol_allowance: $empPetrolAllowance (type: ${empPetrolAllowance.runtimeType})',
      );

      final empMobileAllowance = cleanNumericString(
        _mobileAllowanceController.text,
      );
      debugPrint(
        'emp_mobile_allowance: $empMobileAllowance (type: ${empMobileAllowance.runtimeType})',
      );

      final empKidEducation = cleanNumericString(
        _kidEduAllowanceController.text,
      );
      debugPrint(
        'emp_kid_education: $empKidEducation (type: ${empKidEducation.runtimeType})',
      );

      final empVariable = cleanNumericString(_variableController.text);
      debugPrint(
        'emp_variable: $empVariable (type: ${empVariable.runtimeType})',
      );

      final empAllowanceSalary = cleanNumericString(
        _allowanceSalaryController.text,
      );
      debugPrint(
        'emp_allowance_salary: $empAllowanceSalary (type: ${empAllowanceSalary.runtimeType})',
      );

      // Image field validation
      debugPrint('=== IMAGE FIELD VALIDATION ===');
      debugPrint('_passportPhotoFile: ${_passportPhotoFile?.name ?? 'null'}');
      debugPrint('_fullViewPhotoFile: ${_fullViewPhotoFile?.name ?? 'null'}');

      debugPrint('=== FIELD VALIDATION END ===');

      debugPrint('=== BUILDING REQUEST BODY ===');
      final Map<String, dynamic> body = {
        "emp_id": empId,
        "emp_name": empName,
        "emp_email_id": empEmail,
        "emp_telegram_id": empTelegram,
        "emp_phone_no": empPhone,
        "emp_emergency_no_01": empEmergency01,
        "emp_emergency_no_02": empEmergency02,
        "emp_aadhar": empAadhar,
        "emp_pan": empPan,
        "emp_driving_license": empDrivingLicense,
        "emp_current_address": empCurrentAddress,
        "emp_permanent_address": empPermanentAddress,
        "emp_dob": empDob,
        "emp_docel": empDocel,
        "emp_blood_group": empBloodGroup,
        "emp_qualification": empQualification,
        "emp_passport_no": empPassportNo,
        "emp_passport_valid_till": empPassportValidTill,
        "emp_bank_name": empBankName,
        "emp_bank_account": empBankAccount,
        "emp_bank_branch": empBankBranch,
        "emp_bank_ifsc": empBankIfsc,
        "emp_date_of_joining": empDateOfJoining,
        "emp_medical_history": empMedicalHistory,
        "emp_passport_size_photo": "",
        "emp_full_view_photo": "",
        "emp_designation": empDesignation,
        "emp_reporting_to": empReportingTo,
        "emp_position": empPosition,
        "emp_is_punch_allowed": empIsPunchAllowed,
        "emp_attendance_type": empAttendanceType,
        "emp_salary": empSalary,
        "emp_is_ot_applicable": empIsOtApplicable,
        "emp_no_leaves": empNoLeaves,
        "emp_work_from_home": empWorkFromHome,
        "emp_left_date": null,
        "emp_active_status": empActiveStatus,
        "emp_location": "pune",
        "emp_note": empNote,
        "emp_contractor": empContractor,
        "emp_petrol_allowance": empPetrolAllowance,
        "emp_mobile_allowance": empMobileAllowance,
        "emp_kid_education": empKidEducation,
        "emp_variable": empVariable,
        "emp_allowance_salary": empAllowanceSalary,
      };

      debugPrint('=== CLEANING REQUEST BODY ===');
      debugPrint('Original body size: ${body.length}');

      // Remove null values and empty strings to prevent NaN errors
      body.removeWhere((key, value) {
        final shouldRemove = value == null || value == "" || value == "null";
        if (shouldRemove) {
          debugPrint('Removing field "$key" with value: $value');
        }
        return shouldRemove;
      });

      debugPrint('After null removal, body size: ${body.length}');

      // Debug: Print the cleaned body
      debugPrint('Cleaned request body: ${jsonEncode(body)}');

      // Validate that no NaN values are present
      body.forEach((key, value) {
        if (value != null && value.toString().toLowerCase() == 'nan') {
          debugPrint('ERROR: NaN value found for key: $key');
          body.remove(key);
        }
      });

      // Additional validation: Check for any invalid numeric values
      final keysToRemove = <String>[];
      body.forEach((key, value) {
        if (value != null) {
          final strValue = value.toString();
          if (strValue.toLowerCase() == 'nan' ||
              strValue.toLowerCase() == 'infinity' ||
              strValue.toLowerCase() == '-infinity') {
            debugPrint(
              'ERROR: Invalid numeric value found for key: $key, value: $value',
            );
            keysToRemove.add(key);
          }
        }
      });

      // Remove invalid keys
      for (final key in keysToRemove) {
        debugPrint('Removing invalid key: $key');
        body.remove(key);
      }

      debugPrint('=== PREPARING HTTP REQUEST ===');
      final request = http.MultipartRequest(
        empId == null ? 'POST' : 'PUT',
        Uri.parse('https://1.sunshineiot.in/api/v2/hr/employee'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['data'] = jsonEncode(body);

      debugPrint('Request headers: ${request.headers}');
      debugPrint('Request fields count: ${request.fields.length}');

      // Image file handling with validation
      if (_passportPhotoFile != null) {
        try {
          debugPrint('Adding passport photo file: ${_passportPhotoFile!.name}');
          if (kIsWeb) {
            final bytes = await _passportPhotoFile!.readAsBytes();
            request.files.add(
              http.MultipartFile.fromBytes(
                'file1',
                bytes,
                filename: _passportPhotoFile!.name,
                contentType: MediaType('image', 'jpeg'),
              ),
            );
          } else {
            request.files.add(
              await http.MultipartFile.fromPath(
                'file1',
                _passportPhotoFile!.path,
              ),
            );
          }
          debugPrint('Passport photo file added successfully');
        } catch (e) {
          debugPrint('ERROR: Error adding passport photo file: $e');
        }
      } else {
        debugPrint('No passport photo file to add');
      }

      if (_fullViewPhotoFile != null) {
        try {
          debugPrint(
            'Adding full view photo file: ${_fullViewPhotoFile!.name}',
          );
          if (kIsWeb) {
            final bytes = await _fullViewPhotoFile!.readAsBytes();
            request.files.add(
              http.MultipartFile.fromBytes(
                'file2',
                bytes,
                filename: _fullViewPhotoFile!.name,
                contentType: MediaType('image', 'jpeg'),
              ),
            );
          } else {
            request.files.add(
              await http.MultipartFile.fromPath(
                'file2',
                _fullViewPhotoFile!.path,
              ),
            );
          }
          debugPrint('Full view photo file added successfully');
        } catch (e) {
          debugPrint('ERROR: Error adding full view photo file: $e');
        }
      } else {
        debugPrint('No full view photo file to add');
      }

      debugPrint('Final request body: ${jsonEncode(body)}');
      debugPrint('Request files count: ${request.files.length}');

      debugPrint('=== SENDING REQUEST ===');
      final streamedResponse = await request.send();
      debugPrint('Response status code: ${streamedResponse.statusCode}');

      final response = await http.Response.fromStream(streamedResponse);
      debugPrint('Response body: ${response.body}');

      if (!mounted) {
        debugPrint('Widget not mounted, returning');
        return;
      }

      final data = json.decode(response.body);
      debugPrint('Parsed response data: $data');

      if (response.statusCode == 200 && data['success'] == true) {
        debugPrint(
          'SUCCESS: Employee ${isEditMode ? 'updated' : 'added'} successfully',
        );
        SnackbarUtils.showSuccess(
          'Employee ${isEditMode ? 'updated' : 'added'} successfully',
        );
        // Refresh the employee list after add/edit
        await EmployeeService().refreshEmployees();
        // Use GetX navigation to go back to the list
        Get.offNamed('/dashboard/hr/manage_employee');
      } else {
        debugPrint('ERROR: Response indicates failure');
        debugPrint('Status code: ${response.statusCode}');
        debugPrint('Success flag: ${data['success']}');
        debugPrint('Message: ${data['message']}');
        SnackbarUtils.showError(
          'Failed to ${isEditMode ? 'update' : 'add'} employee: ${data['message']}',
        );
      }
    } catch (e) {
      debugPrint('=== EXCEPTION CAUGHT ===');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error message: $e');
      debugPrint('Stack trace: ${StackTrace.current}');

      if (!mounted) {
        debugPrint('Widget not mounted during error, returning');
        return;
      }

      SnackbarUtils.showError('Error $e');
    } finally {
      debugPrint('=== CLEANUP ===');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        debugPrint('Loading state set to false');
      } else {
        debugPrint('Widget not mounted during cleanup');
      }
      debugPrint('=== FORM SUBMISSION END ===');
    }
  }

  // Modular input decoration
  InputDecoration _inputDecoration(String label, {bool enabled = true}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: enabled ? Colors.black : Colors.grey),
      filled: true,
      fillColor: enabled ? Colors.white : Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.black, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  // Modular text field widget
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool isRequired = false,
    TextInputType? keyboardType,
    int? maxLines,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        decoration: _inputDecoration(
          isRequired ? '$label *' : label,
          enabled: enabled,
        ),
        keyboardType: keyboardType,
        maxLines: maxLines ?? 1,
        validator:
            validator ??
            (isRequired
                ? (value) {
                    if (value == null || value.isEmpty) {
                      controller.text = 'NA';
                      return null;
                    }
                    return null;
                  }
                : null),
      ),
    );
  }

  // Modular dropdown widget with search for reporting to
  Widget _buildReportingToDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownSearch<String>(
        selectedItem: _reportingTo == 'Select Option' ? null : _reportingTo,
        popupProps: PopupProps.menu(
          showSearchBox: true,
          searchFieldProps: TextFieldProps(
            decoration: InputDecoration(
              hintText: 'Search Reporting To...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            style: const TextStyle(color: Colors.black),
          ),
          constraints: const BoxConstraints(maxHeight: 300),
          menuProps: const MenuProps(backgroundColor: Colors.white),
          itemBuilder: (context, item, isSelected) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(item, style: const TextStyle(color: Colors.black)),
          ),
        ),
        dropdownDecoratorProps: DropDownDecoratorProps(
          dropdownSearchDecoration: _inputDecoration('Reporting To *'),
        ),
        items: _reportingToList
            .where((item) => item != 'Select Option')
            .toList(),
        itemAsString: (item) => item,
        dropdownBuilder: (context, selectedItem) => selectedItem == null
            ? Text(
                'Select Reporting To',
                style: const TextStyle(color: Colors.black),
              )
            : Text(selectedItem, style: const TextStyle(color: Colors.black)),
        dropdownButtonProps: const DropdownButtonProps(
          icon: Icon(Icons.arrow_drop_down, color: Colors.black),
          color: Colors.black,
        ),
        onChanged: (String? newValue) {
          setState(() {
            _reportingTo = newValue ?? 'Select Option';
          });
        },
        validator: (value) {
          if (value == null || value == 'Select Option') {
            return 'Please select Reporting To';
          }
          return null;
        },
      ),
    );
  }

  // Modular date picker widget
  Widget _buildDatePicker({
    required String label,
    required DateTime? selectedDate,
    required Function(DateTime?) onDateSelected,
    required DateTime firstDate,
    required DateTime lastDate,
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () async {
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: selectedDate ?? DateTime.now(),
            firstDate: firstDate,
            lastDate: lastDate,
          );
          if (picked != null) {
            onDateSelected(picked);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[50],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRequired ? '$label *' : label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedDate == null
                          ? 'NA'
                          : '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 16, color: Colors.black),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.calendar_today, color: Colors.black),
            ],
          ),
        ),
      ),
    );
  }

  // Modular section header
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    // Deduplicate and check selected values for all dropdowns
    final bloodGroupOptions = deduplicateOptions(
      optionsController.bloodGroupOptions,
    );
    if (selectedBloodGroup != null &&
        !bloodGroupOptions.any(
          (o) => o.optionId == selectedBloodGroup!.optionId,
        )) {
      selectedBloodGroup = null;
    }
    final qualificationOptions = deduplicateOptions(
      optionsController.qualificationOptions,
    );
    if (selectedQualification != null &&
        !qualificationOptions.any(
          (o) => o.optionId == selectedQualification!.optionId,
        )) {
      selectedQualification = null;
    }
    final designationOptions = deduplicateOptions(
      optionsController.designationOptions,
    );
    if (selectedDesignation != null &&
        !designationOptions.any(
          (o) => o.optionId == selectedDesignation!.optionId,
        )) {
      selectedDesignation = null;
    }
    final positionOptions = deduplicateOptions(
      optionsController.positionOptions,
    );
    if (selectedPosition != null &&
        !positionOptions.any((o) => o.optionId == selectedPosition!.optionId)) {
      selectedPosition = null;
    }
    final attendanceTypeOptions = deduplicateOptions(
      optionsController.attendanceTypeOptions,
    );
    if (selectedAttendanceType != null &&
        !attendanceTypeOptions.any(
          (o) => o.optionId == selectedAttendanceType!.optionId,
        )) {
      selectedAttendanceType = null;
    }
    // Use universal yes/no for Employee Active, Work from Home, OT Applicable
    final universalYesNoOptions = deduplicateOptions(
      optionsController.universalYesNoOptions,
    );
    if (selectedEmpActive != null &&
        !universalYesNoOptions.any(
          (o) => o.optionId == selectedEmpActive!.optionId,
        )) {
      selectedEmpActive = null;
    }
    if (selectedWfh != null &&
        !universalYesNoOptions.any(
          (o) => o.optionId == selectedWfh!.optionId,
        )) {
      selectedWfh = null;
    }
    if (selectedOtApplicable != null &&
        !universalYesNoOptions.any(
          (o) => o.optionId == selectedOtApplicable!.optionId,
        )) {
      selectedOtApplicable = null;
    }

    if (!_isDataReady) {
      return const Center(child: CircularProgressIndicator());
    }

    return Material(
      child: Container(
        color: Colors.white,
        padding: EdgeInsets.all(isWeb ? 24 : 16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Page Description for layman users
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: const Text(
                      'Add Employee: Please fill out all the required details below to add a new employee. Fields marked with * are mandatory. If you do not have information for a field, you can leave it as "NA". For dropdowns or dates, if no option is available, "NA" will be shown automatically. This page is designed to be simple and user-friendly for everyone.',
                      style: TextStyle(fontSize: 15, color: Colors.black87),
                    ),
                  ),
                ),

                // Personal Information Section
                _buildSectionHeader('Personal Information'),
                if (isMobile)
                  // Mobile layout - single column
                  Column(
                    children: [
                      _buildTextField(
                        controller: _empIdController,
                        label: 'Employee ID',
                        isRequired: true,
                        enabled: !isEditMode,
                      ),
                      if (isEditMode)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            'Employee ID cannot be changed in edit mode',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      _buildTextField(
                        controller: _nameController,
                        label: 'Name',
                        isRequired: true,
                      ),
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        isRequired: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      _buildTextField(
                        controller: _telegramIdController,
                        label: 'Telegram Chat ID',
                        isRequired: true,
                      ),
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Phone Number',
                        isRequired: true,
                        keyboardType: TextInputType.phone,
                      ),
                      _buildTextField(
                        controller: _emeContact01Controller,
                        label: 'Emergency Contact (01)',
                        isRequired: true,
                        keyboardType: TextInputType.phone,
                      ),
                      _buildTextField(
                        controller: _emeContact02Controller,
                        label: 'Emergency Contact (02)',
                        keyboardType: TextInputType.phone,
                      ),
                      _buildTextField(
                        controller: _aadharController,
                        label: 'Aadhar Card No.',
                        isRequired: true,
                      ),
                      _buildTextField(
                        controller: _panController,
                        label: 'Pan Card No.',
                      ),
                      _buildTextField(
                        controller: _drivingLicenseController,
                        label: 'Driving License No.',
                        isRequired: true,
                      ),
                      _buildTextField(
                        controller: _currentAddressController,
                        label: 'Current Address',
                        isRequired: true,
                        maxLines: 2,
                      ),
                      _buildTextField(
                        controller: _permanentAddressController,
                        label: 'Permanent Address',
                        isRequired: true,
                        maxLines: 2,
                      ),
                      _buildDatePicker(
                        label: 'Date of Birth',
                        selectedDate: _dob,
                        onDateSelected: (date) => setState(() => _dob = date),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                        isRequired: true,
                      ),
                      _buildDatePicker(
                        label: 'Date of Celebration',
                        selectedDate: _doc,
                        onDateSelected: (date) => setState(() => _doc = date),
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2100),
                        isRequired: true,
                      ),
                      bloodGroupOptions.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Blood Group',
                                ),
                                child: const Text(
                                  'No options available',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            )
                          : OptionDropdown(
                              label: 'Blood Group',
                              options: bloodGroupOptions,
                              selected: selectedBloodGroup,
                              onChanged: (option) =>
                                  setState(() => selectedBloodGroup = option),
                              isLoading: optionsController.isLoading,
                              error: null,
                            ),
                      qualificationOptions.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Qualification',
                                ),
                                child: const Text(
                                  'No options available',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            )
                          : OptionDropdown(
                              label: 'Qualification',
                              options: qualificationOptions,
                              selected: selectedQualification,
                              onChanged: (option) => setState(
                                () => selectedQualification = option,
                              ),
                              isLoading: optionsController.isLoading,
                              error: null,
                            ),
                      _buildTextField(
                        controller: _passportController,
                        label: 'Passport No.',
                      ),
                      _buildDatePicker(
                        label: 'Passport Expiry Date',
                        selectedDate: _passportExpiry,
                        onDateSelected: (date) =>
                            setState(() => _passportExpiry = date),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      ),
                      _buildTextField(
                        controller: _bankNameController,
                        label: 'Bank Name',
                        isRequired: true,
                      ),
                      _buildTextField(
                        controller: _bankBranchController,
                        label: 'Bank Branch',
                        isRequired: true,
                      ),
                      _buildTextField(
                        controller: _accountNumberController,
                        label: 'Account Number',
                        isRequired: true,
                      ),
                      _buildTextField(
                        controller: _ifscController,
                        label: 'IFSC Number',
                        isRequired: true,
                      ),
                      _buildDatePicker(
                        label: 'Date of Joining',
                        selectedDate: _doj,
                        onDateSelected: (date) => setState(() => _doj = date),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        isRequired: true,
                      ),
                      _buildTextField(
                        controller: _medicalHistoryController,
                        label: 'Medical History',
                        isRequired: true,
                        maxLines: 2,
                      ),
                    ],
                  )
                else
                  // Desktop layout - two columns
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _buildTextField(
                              controller: _empIdController,
                              label: 'Employee ID',
                              isRequired: true,
                              enabled: !isEditMode,
                            ),
                            if (isEditMode)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(
                                  'Employee ID cannot be changed in edit mode',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            _buildTextField(
                              controller: _nameController,
                              label: 'Name',
                              isRequired: true,
                            ),
                            _buildTextField(
                              controller: _emailController,
                              label: 'Email',
                              isRequired: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter email';
                                }
                                if (!value.contains('@')) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            _buildTextField(
                              controller: _telegramIdController,
                              label: 'Telegram Chat ID',
                              isRequired: true,
                            ),
                            _buildTextField(
                              controller: _phoneController,
                              label: 'Phone Number',
                              isRequired: true,
                              keyboardType: TextInputType.phone,
                            ),
                            _buildTextField(
                              controller: _emeContact01Controller,
                              label: 'Emergency Contact (01)',
                              isRequired: true,
                              keyboardType: TextInputType.phone,
                            ),
                            _buildTextField(
                              controller: _emeContact02Controller,
                              label: 'Emergency Contact (02)',
                              keyboardType: TextInputType.phone,
                            ),
                            _buildTextField(
                              controller: _aadharController,
                              label: 'Aadhar Card No.',
                              isRequired: true,
                            ),
                            _buildTextField(
                              controller: _panController,
                              label: 'Pan Card No.',
                            ),
                            _buildTextField(
                              controller: _drivingLicenseController,
                              label: 'Driving License No.',
                              isRequired: true,
                            ),
                            _buildTextField(
                              controller: _currentAddressController,
                              label: 'Current Address',
                              isRequired: true,
                              maxLines: 2,
                            ),
                            _buildTextField(
                              controller: _permanentAddressController,
                              label: 'Permanent Address',
                              isRequired: true,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          children: [
                            _buildDatePicker(
                              label: 'Date of Birth',
                              selectedDate: _dob,
                              onDateSelected: (date) =>
                                  setState(() => _dob = date),
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                              isRequired: true,
                            ),
                            _buildDatePicker(
                              label: 'Date of Celebration',
                              selectedDate: _doc,
                              onDateSelected: (date) =>
                                  setState(() => _doc = date),
                              firstDate: DateTime(1900),
                              lastDate: DateTime(2100),
                              isRequired: true,
                            ),
                            bloodGroupOptions.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Blood Group',
                                      ),
                                      child: const Text(
                                        'No options available',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  )
                                : OptionDropdown(
                                    label: 'Blood Group',
                                    options: bloodGroupOptions,
                                    selected: selectedBloodGroup,
                                    onChanged: (option) => setState(
                                      () => selectedBloodGroup = option,
                                    ),
                                    isLoading: optionsController.isLoading,
                                    error: null,
                                  ),
                            qualificationOptions.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Qualification',
                                      ),
                                      child: const Text(
                                        'No options available',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  )
                                : OptionDropdown(
                                    label: 'Qualification',
                                    options: qualificationOptions,
                                    selected: selectedQualification,
                                    onChanged: (option) => setState(
                                      () => selectedQualification = option,
                                    ),
                                    isLoading: optionsController.isLoading,
                                    error: null,
                                  ),
                            _buildTextField(
                              controller: _passportController,
                              label: 'Passport No.',
                            ),
                            _buildDatePicker(
                              label: 'Passport Expiry Date',
                              selectedDate: _passportExpiry,
                              onDateSelected: (date) =>
                                  setState(() => _passportExpiry = date),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100),
                            ),
                            _buildTextField(
                              controller: _bankNameController,
                              label: 'Bank Name',
                              isRequired: true,
                            ),
                            _buildTextField(
                              controller: _bankBranchController,
                              label: 'Bank Branch',
                              isRequired: true,
                            ),
                            _buildTextField(
                              controller: _accountNumberController,
                              label: 'Account Number',
                              isRequired: true,
                            ),
                            _buildTextField(
                              controller: _ifscController,
                              label: 'IFSC Number',
                              isRequired: true,
                            ),
                            _buildDatePicker(
                              label: 'Date of Joining',
                              selectedDate: _doj,
                              onDateSelected: (date) =>
                                  setState(() => _doj = date),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              isRequired: true,
                            ),
                            _buildTextField(
                              controller: _medicalHistoryController,
                              label: 'Medical History',
                              isRequired: true,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                SizedBox(height: isMobile ? 24 : 32),

                // Professional Information Section
                _buildSectionHeader('Professional Information'),
                if (isMobile)
                  // Mobile layout - single column
                  Column(
                    children: [
                      designationOptions.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Designation',
                                ),
                                child: const Text(
                                  'No options available',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            )
                          : OptionDropdown(
                              label: 'Designation',
                              options: designationOptions,
                              selected: selectedDesignation,
                              onChanged: (option) =>
                                  setState(() => selectedDesignation = option),
                              isLoading: optionsController.isLoading,
                              error: null,
                            ),
                      // Punch Dropdown (Masked, using optionId)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: DropdownButtonFormField<int>(
                          value: selectedPunchId,
                          decoration: const InputDecoration(labelText: 'Punch'),
                          items: universalYesNoOptions.map((o) {
                            return DropdownMenuItem<int>(
                              value: o.optionId,
                              child: Text(
                                o.optionName.toLowerCase() == 'yes'
                                    ? 'Mandatory'
                                    : o.optionName.toLowerCase() == 'no'
                                    ? 'Not Mandatory'
                                    : o.optionName,
                                style: const TextStyle(color: Colors.black),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedPunchId = value;
                              selectedPunch = universalYesNoOptions.firstWhere(
                                (o) => o.optionId == value,
                                orElse: () => universalYesNoOptions.first,
                              );
                              if (selectedPunch != null &&
                                  selectedPunch!.optionName.toLowerCase() ==
                                      'no') {
                                // Set attendance type to Yearly
                                final yearlyOption = attendanceTypeOptions
                                    .firstWhereOrNull(
                                      (o) => o.optionName
                                          .toLowerCase()
                                          .contains('yearly'),
                                    );
                                if (yearlyOption != null) {
                                  selectedAttendanceType = yearlyOption;
                                }
                              }
                            });
                          },
                          isExpanded: true,
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.black,
                          ),
                          dropdownColor: Colors.white,
                          style: const TextStyle(color: Colors.black),
                          validator: (value) {
                            if (value == null) {
                              return 'Please select Punch';
                            }
                            return null;
                          },
                        ),
                      ),
                      _buildReportingToDropdown(),
                      positionOptions.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Position',
                                ),
                                child: const Text(
                                  'No options available',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            )
                          : OptionDropdown(
                              label: 'Position',
                              options: positionOptions,
                              selected: selectedPosition,
                              onChanged: (option) =>
                                  setState(() => selectedPosition = option),
                              isLoading: optionsController.isLoading,
                              error: null,
                            ),
                      if (selectedPosition?.optionName == 'Contract Based')
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: DropdownButtonFormField<String>(
                            value: selectedContractor,
                            decoration: _inputDecoration('Contractor *'),
                            items: _contractorList
                                .where((item) => item != 'Select Option')
                                .map(
                                  (item) => DropdownMenuItem<String>(
                                    value: item,
                                    child: Text(
                                      item,
                                      style: const TextStyle(
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setState(() => selectedContractor = value),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select Contractor';
                              }
                              return null;
                            },
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.black,
                            ),
                            dropdownColor: Colors.white,
                            style: const TextStyle(color: Colors.black),
                          ),
                        ),
                      attendanceTypeOptions.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Attendance Type',
                                ),
                                child: const Text(
                                  'No options available',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            )
                          : DropdownButtonFormField<Option>(
                              decoration: const InputDecoration(
                                labelText: 'Attendance Type',
                              ),
                              items: attendanceTypeOptions.map((option) {
                                return DropdownMenuItem<Option>(
                                  value: option,
                                  child: Text(
                                    option.optionName,
                                    style: const TextStyle(color: Colors.black),
                                  ),
                                );
                              }).toList(),
                              onChanged:
                                  (selectedPunchId != null &&
                                      universalYesNoOptions
                                              .firstWhereOrNull(
                                                (o) =>
                                                    o.optionId ==
                                                    selectedPunchId,
                                              )
                                              ?.optionName
                                              .toLowerCase() ==
                                          'no')
                                  ? null
                                  : (option) => setState(
                                      () => selectedAttendanceType = option,
                                    ),
                              value:
                                  (selectedPunchId != null &&
                                      universalYesNoOptions
                                              .firstWhereOrNull(
                                                (o) =>
                                                    o.optionId ==
                                                    selectedPunchId,
                                              )
                                              ?.optionName
                                              .toLowerCase() ==
                                          'no')
                                  ? attendanceTypeOptions.firstWhere(
                                      (o) => o.optionName
                                          .toLowerCase()
                                          .contains('yearly'),
                                      orElse: () => attendanceTypeOptions.first,
                                    )
                                  : selectedAttendanceType,
                              selectedItemBuilder: (context) {
                                return attendanceTypeOptions.map((option) {
                                  if (selectedPunchId != null &&
                                      universalYesNoOptions
                                              .firstWhereOrNull(
                                                (o) =>
                                                    o.optionId ==
                                                    selectedPunchId,
                                              )
                                              ?.optionName
                                              .toLowerCase() ==
                                          'no' &&
                                      option.optionName.toLowerCase().contains(
                                        'yearly',
                                      )) {
                                    return Text(
                                      'Yearly',
                                      style: const TextStyle(
                                        color: Colors.black,
                                      ),
                                    );
                                  }
                                  return Text(
                                    option.optionName,
                                    style: const TextStyle(color: Colors.black),
                                  );
                                }).toList();
                              },
                              dropdownColor: Colors.white,
                              style: const TextStyle(color: Colors.black),
                              icon: const Icon(
                                Icons.arrow_drop_down,
                                color: Colors.black,
                              ),
                            ),
                      universalYesNoOptions.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Employee Active',
                                ),
                                child: const Text(
                                  'No options available',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            )
                          : OptionDropdown(
                              label: 'Employee Active',
                              options: universalYesNoOptions,
                              selected: selectedEmpActive,
                              onChanged: (option) =>
                                  setState(() => selectedEmpActive = option),
                              isLoading: optionsController.isLoading,
                              error: null,
                            ),
                      universalYesNoOptions.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Work from Home',
                                ),
                                child: const Text(
                                  'No options available',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            )
                          : OptionDropdown(
                              label: 'Work from Home',
                              options: universalYesNoOptions,
                              selected: selectedWfh,
                              onChanged: (option) =>
                                  setState(() => selectedWfh = option),
                              isLoading: optionsController.isLoading,
                              error: null,
                            ),
                      universalYesNoOptions.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'OT Applicable',
                                ),
                                child: const Text(
                                  'No options available',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            )
                          : OptionDropdown(
                              label: 'OT Applicable',
                              options: universalYesNoOptions,
                              selected: selectedOtApplicable,
                              onChanged: (option) =>
                                  setState(() => selectedOtApplicable = option),
                              isLoading: optionsController.isLoading,
                              error: null,
                            ),
                      _buildTextField(
                        controller: _noOfLeavesController,
                        label: 'No of Leaves',
                        isRequired: true,
                        keyboardType: TextInputType.number,
                      ),
                      // Add PF No. and ESIC No. fields here
                      _buildTextField(
                        controller: _empPfController,
                        label: 'PF No.',
                        isRequired: false,
                      ),
                      _buildTextField(
                        controller: _empEsiController,
                        label: 'ESIC No.',
                        isRequired: false,
                      ),
                    ],
                  )
                else
                  // Desktop layout - two columns
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            designationOptions.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Designation',
                                      ),
                                      child: const Text(
                                        'No options available',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  )
                                : OptionDropdown(
                                    label: 'Designation',
                                    options: designationOptions,
                                    selected: selectedDesignation,
                                    onChanged: (option) => setState(
                                      () => selectedDesignation = option,
                                    ),
                                    isLoading: optionsController.isLoading,
                                    error: null,
                                  ),
                            // Punch Dropdown (Masked, using optionId)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: DropdownButtonFormField<int>(
                                value: selectedPunchId,
                                decoration: const InputDecoration(
                                  labelText: 'Punch',
                                ),
                                items: universalYesNoOptions.map((o) {
                                  return DropdownMenuItem<int>(
                                    value: o.optionId,
                                    child: Text(
                                      o.optionName.toLowerCase() == 'yes'
                                          ? 'Mandatory'
                                          : o.optionName.toLowerCase() == 'no'
                                          ? 'Not Mandatory'
                                          : o.optionName,
                                      style: const TextStyle(
                                        color: Colors.black,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedPunchId = value;
                                    selectedPunch = universalYesNoOptions
                                        .firstWhere(
                                          (o) => o.optionId == value,
                                          orElse: () =>
                                              universalYesNoOptions.first,
                                        );
                                    if (selectedPunch != null &&
                                        selectedPunch!.optionName
                                                .toLowerCase() ==
                                            'no') {
                                      // Set attendance type to Yearly
                                      final yearlyOption = attendanceTypeOptions
                                          .firstWhereOrNull(
                                            (o) => o.optionName
                                                .toLowerCase()
                                                .contains('yearly'),
                                          );
                                      if (yearlyOption != null) {
                                        selectedAttendanceType = yearlyOption;
                                      }
                                    }
                                  });
                                },
                                isExpanded: true,
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.black,
                                ),
                                dropdownColor: Colors.white,
                                style: const TextStyle(color: Colors.black),
                                validator: (value) {
                                  if (value == null) {
                                    return 'Please select Punch';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            _buildReportingToDropdown(),
                            positionOptions.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Position',
                                      ),
                                      child: const Text(
                                        'No options available',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  )
                                : OptionDropdown(
                                    label: 'Position',
                                    options: positionOptions,
                                    selected: selectedPosition,
                                    onChanged: (option) => setState(
                                      () => selectedPosition = option,
                                    ),
                                    isLoading: optionsController.isLoading,
                                    error: null,
                                  ),
                            if (selectedPosition?.optionName ==
                                'Contract Based')
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: DropdownButtonFormField<String>(
                                  value: selectedContractor,
                                  decoration: _inputDecoration('Contractor *'),
                                  items: _contractorList
                                      .where((item) => item != 'Select Option')
                                      .map(
                                        (item) => DropdownMenuItem<String>(
                                          value: item,
                                          child: Text(
                                            item,
                                            style: const TextStyle(
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) => setState(
                                    () => selectedContractor = value,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select Contractor';
                                    }
                                    return null;
                                  },
                                  icon: const Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.black,
                                  ),
                                  dropdownColor: Colors.white,
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ),
                            attendanceTypeOptions.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Attendance Type',
                                      ),
                                      child: const Text(
                                        'No options available',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  )
                                : DropdownButtonFormField<Option>(
                                    decoration: const InputDecoration(
                                      labelText: 'Attendance Type',
                                    ),
                                    items: attendanceTypeOptions.map((option) {
                                      return DropdownMenuItem<Option>(
                                        value: option,
                                        child: Text(
                                          option.optionName,
                                          style: const TextStyle(
                                            color: Colors.black,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged:
                                        (selectedPunchId != null &&
                                            universalYesNoOptions
                                                    .firstWhereOrNull(
                                                      (o) =>
                                                          o.optionId ==
                                                          selectedPunchId,
                                                    )
                                                    ?.optionName
                                                    .toLowerCase() ==
                                                'no')
                                        ? null
                                        : (option) => setState(
                                            () =>
                                                selectedAttendanceType = option,
                                          ),
                                    value:
                                        (selectedPunchId != null &&
                                            universalYesNoOptions
                                                    .firstWhereOrNull(
                                                      (o) =>
                                                          o.optionId ==
                                                          selectedPunchId,
                                                    )
                                                    ?.optionName
                                                    .toLowerCase() ==
                                                'no')
                                        ? attendanceTypeOptions.firstWhere(
                                            (o) => o.optionName
                                                .toLowerCase()
                                                .contains('yearly'),
                                            orElse: () =>
                                                attendanceTypeOptions.first,
                                          )
                                        : selectedAttendanceType,
                                    selectedItemBuilder: (context) {
                                      return attendanceTypeOptions.map((
                                        option,
                                      ) {
                                        if (selectedPunchId != null &&
                                            universalYesNoOptions
                                                    .firstWhereOrNull(
                                                      (o) =>
                                                          o.optionId ==
                                                          selectedPunchId,
                                                    )
                                                    ?.optionName
                                                    .toLowerCase() ==
                                                'no' &&
                                            option.optionName
                                                .toLowerCase()
                                                .contains('yearly')) {
                                          return Text(
                                            'Yearly',
                                            style: const TextStyle(
                                              color: Colors.black,
                                            ),
                                          );
                                        }
                                        return Text(
                                          option.optionName,
                                          style: const TextStyle(
                                            color: Colors.black,
                                          ),
                                        );
                                      }).toList();
                                    },
                                    dropdownColor: Colors.white,
                                    style: const TextStyle(color: Colors.black),
                                    icon: const Icon(
                                      Icons.arrow_drop_down,
                                      color: Colors.black,
                                    ),
                                  ),
                            // const SizedBox(width: 32,)
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        child: Column(
                          children: [
                            universalYesNoOptions.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Employee Active',
                                      ),
                                      child: const Text(
                                        'No options available',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  )
                                : OptionDropdown(
                                    label: 'Employee Active',
                                    options: universalYesNoOptions,
                                    selected: selectedEmpActive,
                                    onChanged: (option) => setState(
                                      () => selectedEmpActive = option,
                                    ),
                                    isLoading: optionsController.isLoading,
                                    error: null,
                                  ),
                            universalYesNoOptions.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Work from Home',
                                      ),
                                      child: const Text(
                                        'No options available',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  )
                                : OptionDropdown(
                                    label: 'Work from Home',
                                    options: universalYesNoOptions,
                                    selected: selectedWfh,
                                    onChanged: (option) =>
                                        setState(() => selectedWfh = option),
                                    isLoading: optionsController.isLoading,
                                    error: null,
                                  ),
                            universalYesNoOptions.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'OT Applicable',
                                      ),
                                      child: const Text(
                                        'No options available',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  )
                                : OptionDropdown(
                                    label: 'OT Applicable',
                                    options: universalYesNoOptions,
                                    selected: selectedOtApplicable,
                                    onChanged: (option) => setState(
                                      () => selectedOtApplicable = option,
                                    ),
                                    isLoading: optionsController.isLoading,
                                    error: null,
                                  ),
                            _buildTextField(
                              controller: _noOfLeavesController,
                              label: 'No of Leaves',
                              isRequired: true,
                              keyboardType: TextInputType.number,
                            ),
                            // Add PF No. and ESIC No. fields here
                            _buildTextField(
                              controller: _empPfController,
                              label: 'PF No.',
                              isRequired: false,
                            ),
                            _buildTextField(
                              controller: _empEsiController,
                              label: 'ESIC No.',
                              isRequired: false,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                SizedBox(height: isMobile ? 24 : 32),

                // Allowance Information Section
                _buildSectionHeader('Allowance Information'),
                if (isMobile)
                  // Mobile layout - single column
                  Column(
                    children: [
                      _buildTextField(
                        controller: _salaryController,
                        label: 'Salary',
                        isRequired: true,
                        keyboardType: TextInputType.number,
                      ),
                      _buildTextField(
                        controller: _petrolAllowanceController,
                        label: 'Petrol Allowance (Monthly)',
                        keyboardType: TextInputType.number,
                      ),
                      _buildTextField(
                        controller: _mobileAllowanceController,
                        label: 'Mobile Allowance (Monthly)',
                        keyboardType: TextInputType.number,
                      ),
                      _buildTextField(
                        controller: _kidEduAllowanceController,
                        label: 'Kid Education Allowance (Yearly)',
                        keyboardType: TextInputType.number,
                      ),
                      _buildTextField(
                        controller: _variableController,
                        label: 'Employee Variable',
                        keyboardType: TextInputType.number,
                      ),
                      _buildTextField(
                        controller: _allowanceSalaryController,
                        label: 'Allowance Salary',
                        isRequired: false,
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  )
                else
                  // Desktop layout - two columns
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _buildTextField(
                              controller: _salaryController,
                              label: 'Salary',
                              isRequired: true,
                              keyboardType: TextInputType.number,
                            ),
                            _buildTextField(
                              controller: _petrolAllowanceController,
                              label: 'Petrol Allowance (Monthly)',
                              keyboardType: TextInputType.number,
                            ),
                            _buildTextField(
                              controller: _mobileAllowanceController,
                              label: 'Mobile Allowance (Monthly)',
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          children: [
                            _buildTextField(
                              controller: _kidEduAllowanceController,
                              label: 'Kid Education Allowance (Yearly)',
                              keyboardType: TextInputType.number,
                            ),
                            _buildTextField(
                              controller: _variableController,
                              label: 'Employee Variable',
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                SizedBox(height: isMobile ? 16 : 16),

                _buildTextField(
                  controller: _noteController,
                  label: 'Note',
                  maxLines: 2,
                ),

                SizedBox(height: isMobile ? 24 : 32),

                // Employee Photos Section
                _buildSectionHeader('Employee Photos'),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          ElevatedButton(
                            onPressed: _pickPassportPhoto,
                            child: const Text('Pick Passport Photo'),
                          ),
                          if (_passportPhotoFile != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: kIsWeb
                                  ? Image.network(
                                      _passportPhotoFile!.path,
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      File(_passportPhotoFile!.path),
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          ElevatedButton(
                            onPressed: _pickFullViewPhoto,
                            child: const Text('Pick Full View Photo'),
                          ),
                          if (_fullViewPhotoFile != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: kIsWeb
                                  ? Image.network(
                                      _fullViewPhotoFile!.path,
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      File(_fullViewPhotoFile!.path),
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: isMobile ? 24 : 32),

                // Submit Button
                if (isMobile)
                  // Mobile layout - full width button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              isEditMode ? 'Update' : 'Submit',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  )
                else
                  // Desktop layout - centered button
                  Center(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              isEditMode ? 'Update' : 'Submit',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
