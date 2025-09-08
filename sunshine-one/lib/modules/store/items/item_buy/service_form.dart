import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer';
import 'package:get/get.dart';
import '../../../../controllers/options_controller.dart';
import '../../../../models/option_model.dart';
import '../../../../utils/snackbar_message.dart';

class ServiceForm extends StatefulWidget {
  final int? itemId;

  const ServiceForm({super.key, this.itemId});

  factory ServiceForm.fromArguments() {
    final arguments = Get.arguments;
    // Accept both 'itemId' and 'id' for edit mode
    final itemId = arguments?['itemId'] ?? arguments?['id'];
    debugPrint(
      'ServiceForm.fromArguments: arguments= [32m$arguments [0m, itemId= [32m$itemId [0m',
    );
    return ServiceForm(itemId: itemId);
  }

  @override
  State<ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends State<ServiceForm> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _sacCodeController = TextEditingController();

  final OptionsController _optionsController = Get.put(OptionsController());

  RxInt selectedServiceTypeId = RxInt(0);
  bool isLoading = false;
  bool _isLoadingData = false;
  String? _originalSacCode; // Track original SAC code for edit mode
  String? _originalDescription; // Track original description for edit mode
  int? _originalTypeId; // Track original type ID for edit mode

  bool get _isEditMode => widget.itemId != null;

  @override
  void initState() {
    super.initState();
    debugPrint(
      'ServiceForm: widget.itemId= [32m${widget.itemId} [0m, _isEditMode= [32m$_isEditMode [0m',
    );
    // Fetch options first, then fetch item data if in edit mode
    _optionsController.fetchOptions().then((_) {
      if (_isEditMode) {
        _fetchItemData();
      }
    });

    // Handle legacy arguments for backward compatibility
    final item = Get.arguments;
    if (item != null && !_isEditMode) {
      if (item['type_id'] != null) {
        selectedServiceTypeId.value = item['type_id'];
      }
      if (item['description'] != null)
        _descriptionController.text = item['description'];
      if (item['sac_code'] != null) _sacCodeController.text = item['sac_code'];
    }
  }

  Future<void> _fetchItemData() async {
    if (!_isEditMode) return;
    setState(() {
      _isLoadingData = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null || token.isEmpty) {
        debugPrint('JWT token is missing for fetching item data!');
        return;
      }
      final itemTypeId = 56; // Service typeId
      final response = await http.get(
        Uri.parse(
          'https://1.sunshineiot.in/api/v2/store/item/$itemTypeId/${widget.itemId}',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final itemData = json.decode(response.body);
        debugPrint('Fetched service data: $itemData');
        // Handle deeply nested responses
        final service =
            itemData['data']?['service'] ?? itemData['data'] ?? itemData;
        debugPrint('Service object for form: $service');
        _populateFormWithData(service);
      } else {
        debugPrint('Error fetching service data: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
      }
    } catch (e) {
      debugPrint('Exception fetching service data: $e');
    } finally {
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  void _populateFormWithData(Map<String, dynamic> itemData) {
    debugPrint('Populating form with data: $itemData');
    debugPrint('itemData[description]:  [32m${itemData['description']} [0m');
    debugPrint('itemData[sac_code]:  [32m${itemData['sac_code']} [0m');
    debugPrint('itemData[type_id]:  [32m${itemData['type_id']} [0m');
    // Populate text fields
    _descriptionController.text = itemData['description']?.toString() ?? '';
    debugPrint(
      'Set _descriptionController.text:  [32m${_descriptionController.text} [0m',
    );
    _sacCodeController.text = itemData['sac_code']?.toString() ?? '';
    debugPrint(
      'Set _sacCodeController.text:  [32m${_sacCodeController.text} [0m',
    );
    // Store original values for edit mode
    _originalDescription = itemData['description']?.toString();
    _originalSacCode = itemData['sac_code']?.toString();
    _originalTypeId = itemData['type_id'];
    debugPrint('Original values stored:');
    debugPrint('  Description: $_originalDescription');
    debugPrint('  SAC Code: $_originalSacCode');
    debugPrint('  Type ID: $_originalTypeId');
    // Set dropdown values
    _setDropdownValues(itemData);
    debugPrint(
      'Set selectedServiceTypeId.value: ${selectedServiceTypeId.value}',
    );
    setState(() {});
  }

  void _setDropdownValues(Map<String, dynamic> itemData) {
    debugPrint('Setting dropdown values for service form...');

    // Service Type
    final serviceTypeValue =
        itemData['type_id'] ??
        itemData['type'] ??
        itemData['service_type'] ??
        itemData['service_type_id'];

    debugPrint(
      'Service Type value from API: $serviceTypeValue (type: ${serviceTypeValue.runtimeType})',
    );

    if (serviceTypeValue != null) {
      final serviceTypeOptions = _optionsController.serviceTypeOptions;
      debugPrint(
        'Available Service Type options: ${serviceTypeOptions.map((o) => '${o.optionId}:${o.optionName}').toList()}',
      );

      Option? serviceTypeOption;

      // Try different matching strategies
      if (serviceTypeValue is int) {
        debugPrint('Service Type value is int: $serviceTypeValue');
        // If it's an integer, try to find by optionId first
        serviceTypeOption = serviceTypeOptions.firstWhere(
          (option) => option.optionId == serviceTypeValue,
          orElse: () => Option(optionId: 0, optionName: ''),
        );
        debugPrint(
          'Found by optionId: ${serviceTypeOption.optionId != 0 ? 'YES' : 'NO'}',
        );

        // If not found by ID, try to find by numeric value in optionName
        if (serviceTypeOption.optionId == 0) {
          debugPrint('Trying to match by numeric value in optionName...');
          serviceTypeOption = serviceTypeOptions.firstWhere(
            (option) =>
                double.tryParse(option.optionName) ==
                serviceTypeValue.toDouble(),
            orElse: () => Option(optionId: 0, optionName: ''),
          );
          debugPrint(
            'Found by numeric optionName: ${serviceTypeOption.optionId != 0 ? 'YES' : 'NO'}',
          );
        }
      } else if (serviceTypeValue is String) {
        debugPrint('Service Type value is string: $serviceTypeValue');
        // Try exact match first
        serviceTypeOption = serviceTypeOptions.firstWhere(
          (option) =>
              option.optionName.toLowerCase() == serviceTypeValue.toLowerCase(),
          orElse: () => Option(optionId: 0, optionName: ''),
        );
        debugPrint(
          'Found by exact string match: ${serviceTypeOption.optionId != 0 ? 'YES' : 'NO'}',
        );

        // If not found, try partial match
        if (serviceTypeOption.optionId == 0) {
          serviceTypeOption = serviceTypeOptions.firstWhere(
            (option) =>
                option.optionName.toLowerCase().contains(
                  serviceTypeValue.toLowerCase(),
                ) ||
                serviceTypeValue.toLowerCase().contains(
                  option.optionName.toLowerCase(),
                ),
            orElse: () => Option(optionId: 0, optionName: ''),
          );
          debugPrint(
            'Found by partial string match: ${serviceTypeOption.optionId != 0 ? 'YES' : 'NO'}',
          );
        }

        // If still not found, try to parse as number
        if (serviceTypeOption.optionId == 0) {
          final numericValue = double.tryParse(serviceTypeValue);
          if (numericValue != null) {
            serviceTypeOption = serviceTypeOptions.firstWhere(
              (option) => double.tryParse(option.optionName) == numericValue,
              orElse: () => Option(optionId: 0, optionName: ''),
            );
            debugPrint(
              'Found by parsed numeric value: ${serviceTypeOption.optionId != 0 ? 'YES' : 'NO'}',
            );
          }
        }
      } else if (serviceTypeValue is double) {
        debugPrint('Service Type value is double: $serviceTypeValue');
        serviceTypeOption = serviceTypeOptions.firstWhere(
          (option) => double.tryParse(option.optionName) == serviceTypeValue,
          orElse: () => Option(optionId: 0, optionName: ''),
        );
        debugPrint(
          'Found by double match: ${serviceTypeOption.optionId != 0 ? 'YES' : 'NO'}',
        );
      }

      if (serviceTypeOption != null && serviceTypeOption.optionId != 0) {
        selectedServiceTypeId.value = serviceTypeOption.optionId;
        debugPrint(
          'SUCCESS: Set Service Type to: ${selectedServiceTypeId.value}',
        );
      } else {
        debugPrint(
          'No matching Service Type option found, trying fallbacks...',
        );

        // Fallback: create a display value from the original data
        if (serviceTypeValue is int || serviceTypeValue is double) {
          debugPrint('Trying numeric fallback...');
          final matchingOption = serviceTypeOptions.firstWhere(
            (option) =>
                double.tryParse(option.optionName) ==
                serviceTypeValue.toDouble(),
            orElse: () => Option(optionId: 0, optionName: ''),
          );
          if (matchingOption.optionId != 0) {
            selectedServiceTypeId.value = matchingOption.optionId;
            debugPrint(
              'SUCCESS: Set Service Type to (numeric fallback): ${selectedServiceTypeId.value}',
            );
          } else {
            debugPrint('FAILED: No numeric fallback match found');
          }
        } else if (serviceTypeValue is String) {
          debugPrint('Trying string fallback...');
          final matchingOption = serviceTypeOptions.firstWhere(
            (option) => option.optionName.toLowerCase().contains(
              serviceTypeValue.toLowerCase(),
            ),
            orElse: () => Option(optionId: 0, optionName: ''),
          );
          if (matchingOption.optionId != 0) {
            selectedServiceTypeId.value = matchingOption.optionId;
            debugPrint(
              'SUCCESS: Set Service Type to (string fallback): ${selectedServiceTypeId.value}',
            );
          } else {
            debugPrint('FAILED: No string fallback match found');
          }
        }
      }
    } else {
      debugPrint('Service Type value is null in itemData');
    }

    debugPrint('Final selectedServiceTypeId: ${selectedServiceTypeId.value}');
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _sacCodeController.dispose();
    super.dispose();
  }

  Widget _buildServiceTypeDropdown() {
    return Obx(() {
      // Ensure the selected value exists in the options
      final validValue =
          selectedServiceTypeId.value != 0 &&
              _optionsController.serviceTypeOptions.any(
                (opt) => opt.optionId == selectedServiceTypeId.value,
              )
          ? selectedServiceTypeId.value
          : null;

      return DropdownButtonFormField<int>(
        value: validValue,
        items: _optionsController.serviceTypeOptions
            .map(
              (opt) => DropdownMenuItem(
                value: opt.optionId,
                child: Text(opt.optionName),
              ),
            )
            .toList(),
        onChanged: (val) {
          if (val != null) {
            selectedServiceTypeId.value = val;
          }
        },
        decoration: const InputDecoration(
          labelText: 'Service Type *',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        validator: (val) => val == null ? 'Please select Service Type' : null,
      );
    });
  }

  Future<void> _submitForm() async {
    debugPrint('Submit form called');
    debugPrint('Form validation: ${_formKey.currentState?.validate()}');
    debugPrint('Selected service type ID: ${selectedServiceTypeId.value}');

    if (!(_formKey.currentState?.validate() ?? false)) {
      debugPrint('Form validation failed');
      return;
    }
    if (selectedServiceTypeId.value == 0) {
      debugPrint('No service type selected');
      return;
    }

    setState(() {
      isLoading = true;
    });

    final currentDescription = _descriptionController.text.trim();
    final currentSacCode = _sacCodeController.text.trim();
    final currentTypeId = selectedServiceTypeId.value;

    Map<String, dynamic> body;

    if (_isEditMode) {
      // For edit mode, only include fields that have changed
      body = {};

      if (_originalTypeId != currentTypeId) {
        body['type_id'] = currentTypeId;
        debugPrint('Type ID changed: $_originalTypeId -> $currentTypeId');
      }

      if (_originalDescription != currentDescription) {
        body['description'] = currentDescription;
        debugPrint(
          'Description changed: "$_originalDescription" -> "$currentDescription"',
        );
      }

      if (_originalSacCode != currentSacCode) {
        body['sac_code'] = currentSacCode;
        debugPrint(
          'SAC code changed: "$_originalSacCode" -> "$currentSacCode"',
        );
      }

      debugPrint('Edit mode - only sending changed fields: $body');

      // Check if any fields have changed
      if (body.isEmpty) {
        debugPrint('No fields have changed, showing info message');
        SnackbarUtils.showError(
          'No changes detected. Please modify at least one field before updating.',
        );
        setState(() {
          isLoading = false;
        });
        return;
      }
    } else {
      // For add mode, send all required fields
      body = {
        "type_id": currentTypeId,
        "description": currentDescription,
        "sac_code": currentSacCode,
      };
      debugPrint('Add mode - sending all fields: $body');
    }

    debugPrint('Edit mode: $_isEditMode');
    debugPrint('Item ID: ${widget.itemId}');
    debugPrint('Original values:');
    debugPrint('  Type ID: $_originalTypeId');
    debugPrint('  Description: "$_originalDescription"');
    debugPrint('  SAC Code: "$_originalSacCode"');
    debugPrint('Current values:');
    debugPrint('  Type ID: $currentTypeId');
    debugPrint('  Description: "$currentDescription"');
    debugPrint('  SAC Code: "$currentSacCode"');

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null || token.isEmpty) {
        log('JWT token is missing for submit!');
        if (!mounted) return;
        SnackbarUtils.showError(
          'Authentication token missing. Please login again.',
        );
        return;
      }

      http.Response response;

      if (_isEditMode) {
        // PUT request for edit mode
        final url =
            'https://1.sunshineiot.in/api/v2/store/item/service/${widget.itemId}';
        debugPrint('PUT request to: $url');
        response = await http.put(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode(body),
        );
      } else {
        // POST request for add mode
        debugPrint(
          'POST request to: https://1.sunshineiot.in/api/v2/store/item/service',
        );
        response = await http.post(
          Uri.parse('https://1.sunshineiot.in/api/v2/store/item/service'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode(body),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        debugPrint('Success response: $responseData');

        String message;
        if (_isEditMode) {
          // Handle edit mode response
          if (responseData['updated'] == true) {
            message = 'Service updated successfully';
          } else {
            message = responseData['message'] ?? 'Service updated successfully';
          }
        } else {
          // Handle add mode response
          message = responseData['message'] ?? 'Service added successfully';
        }

        if (!mounted) return;
        SnackbarUtils.showSuccess(message);

        // Wait a bit for the snackbar to show, then navigate
        await Future.delayed(const Duration(milliseconds: 1500));
        Get.offAllNamed(
          '/dashboard/store/items',
        ); // Navigate to items screen and clear navigation stack
      } else {
        debugPrint('Request failed with status: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');

        try {
          final errorData = json.decode(response.body);
          String errorMessage =
              errorData['message'] ??
              'Failed to ${_isEditMode ? 'update' : 'add'} service';

          // Handle specific error cases
          if (response.statusCode == 409) {
            if (_isEditMode) {
              final sacCodeChanged = _originalSacCode != currentSacCode;
              if (sacCodeChanged) {
                errorMessage =
                    'Unable to update service. The new SAC code already exists in another service. Please use a different SAC code or keep the original one.';
              } else {
                errorMessage =
                    'Unable to update service. There might be a conflict with existing data. Please try again or contact support if the issue persists.';
              }
            } else {
              errorMessage =
                  'A service with this SAC code already exists. Please use a different SAC code.';
            }
          } else if (response.statusCode == 400) {
            errorMessage =
                'Invalid data provided. Please check all fields and try again.';
          } else if (response.statusCode == 401) {
            errorMessage = 'Authentication failed. Please login again.';
          } else if (response.statusCode == 403) {
            errorMessage =
                'You do not have permission to ${_isEditMode ? 'update' : 'create'} services.';
          } else if (response.statusCode == 404) {
            errorMessage =
                'Service not found. It may have been deleted or moved.';
          } else if (response.statusCode >= 500) {
            errorMessage = 'Server error occurred. Please try again later.';
          }

          SnackbarUtils.showError(errorMessage);
        } catch (e) {
          debugPrint('Error parsing response: $e');
          String errorMessage =
              'Failed to ${_isEditMode ? 'update' : 'add'} service';

          if (response.statusCode == 409) {
            errorMessage = _isEditMode
                ? 'Unable to update service. Please check the SAC code and try again.'
                : 'A service with this SAC code already exists.';
          }

          SnackbarUtils.showError(
            '$errorMessage (Status: ${response.statusCode})',
          );
        }
      }
    } catch (e) {
      log('Exception: $e');
      if (!mounted) return;
      SnackbarUtils.showError('An error occurred. Please try again later.');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      'ServiceForm.build: widget.itemId= [32m${widget.itemId} [0m, _isEditMode= [32m$_isEditMode [0m',
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Service' : 'Add Service'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEditMode ? 'Edit Service' : 'Add Service',
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_isLoadingData)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else
                      Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    _buildServiceTypeDropdown(),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _descriptionController,
                                      decoration: const InputDecoration(
                                        labelText: 'Description of Service *',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 14,
                                        ),
                                      ),
                                      validator: (v) => v == null || v.isEmpty
                                          ? 'Required'
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _sacCodeController,
                                      decoration: const InputDecoration(
                                        labelText: 'SAC Code *',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 14,
                                        ),
                                      ),
                                      validator: (v) => v == null || v.isEmpty
                                          ? 'Required'
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: _showFormOverview,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 14,
                                  ),
                                  textStyle: const TextStyle(
                                    fontFamily: 'Roboto',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                child: const Text('View'),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: isLoading ? null : _submitForm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 14,
                                  ),
                                  textStyle: const TextStyle(
                                    fontFamily: 'Roboto',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : Text(
                                        _isEditMode
                                            ? 'Update Service'
                                            : 'Submit',
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFormOverview() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(_isEditMode ? 'Edit Form Overview' : 'Form Overview'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: double.maxFinite,
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Field',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Value',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Table Rows
                  _buildTableRow(
                    'Service Type',
                    selectedServiceTypeId.value != 0
                        ? _optionsController.serviceTypeOptions
                              .firstWhere(
                                (opt) =>
                                    opt.optionId == selectedServiceTypeId.value,
                                orElse: () =>
                                    Option(optionId: 0, optionName: 'Unknown'),
                              )
                              .optionName
                        : 'Not selected',
                  ),
                  _buildTableRow(
                    'Description',
                    _descriptionController.text.isNotEmpty
                        ? _descriptionController.text
                        : 'Not filled',
                  ),
                  _buildTableRow(
                    'SAC Code',
                    _sacCodeController.text.isNotEmpty
                        ? _sacCodeController.text
                        : 'Not filled',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('Close')),
          ],
        );
      },
    );
  }

  Widget _buildTableRow(String label, String value) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
          left: BorderSide(color: Colors.grey[300]!),
          right: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: value == 'Not filled' || value == 'Not selected'
                      ? Colors.grey[600]
                      : Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
