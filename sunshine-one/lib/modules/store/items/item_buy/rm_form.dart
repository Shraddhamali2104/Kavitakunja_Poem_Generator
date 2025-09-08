import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../controllers/options_controller.dart';
import '../../../../services/options_service.dart';
import '../../../../utils/snackbar_message.dart';
import '../../../../models/option_model.dart';

// Custom Searchable Dropdown Widget
class SearchableDropdown extends StatefulWidget {
  final String label;
  final String hint;
  final List<Option> options;
  final String? value;
  final Function(String?) onChanged;
  final String? Function(String?)? validator;
  final bool isRequired;

  const SearchableDropdown({
    super.key,
    required this.label,
    required this.hint,
    required this.options,
    required this.value,
    required this.onChanged,
    this.validator,
    this.isRequired = true,
  });

  @override
  State<SearchableDropdown> createState() => _SearchableDropdownState();
}

class _SearchableDropdownState extends State<SearchableDropdown> {
  final TextEditingController _searchController = TextEditingController();
  List<Option> _filteredOptions = [];
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _filteredOptions = widget.options;
    _searchController.addListener(_filterOptions);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterOptions() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredOptions = widget.options;
      } else {
        _filteredOptions = widget.options
            .where(
              (option) =>
                  option.optionName.toLowerCase().contains(query) ||
                  option.optionId.toString().contains(query),
            )
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _isOpen = !_isOpen;
              if (_isOpen) {
                _searchController.clear();
                _filteredOptions = widget.options;
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.value != null
                        ? widget.options
                                  .firstWhere(
                                    (option) =>
                                        '${option.optionId} - ${option.optionName}' ==
                                        widget.value,
                                    orElse: () =>
                                        Option(optionId: 0, optionName: ''),
                                  )
                                  .optionName
                                  .isNotEmpty
                              ? widget.options
                                    .firstWhere(
                                      (option) =>
                                          '${option.optionId} - ${option.optionName}' ==
                                          widget.value,
                                    )
                                    .optionName
                              : 'Select ${widget.label}'
                        : widget.hint,
                    style: TextStyle(
                      color: widget.value != null ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
                Icon(
                  _isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),

        if (_isOpen)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
              color: Colors.white,
            ),
            child: Column(
              children: [
                // Search TextField
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search ${widget.label}...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                // Options List
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: _filteredOptions.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'No options available',
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _filteredOptions.length,
                          itemBuilder: (context, index) {
                            final option = _filteredOptions[index];
                            final optionValue =
                                '${option.optionId} - ${option.optionName}';
                            final isSelected = widget.value == optionValue;

                            return ListTile(
                              title: Text(option.optionName),
                              selected: isSelected,
                              selectedTileColor: Colors.blue.withValues(
                                alpha: 0.1,
                              ),
                              onTap: () {
                                widget.onChanged(optionValue);
                                setState(() {
                                  _isOpen = false;
                                });
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class RMForm extends StatefulWidget {
  final int? itemId; // Add itemId parameter for edit mode

  const RMForm({super.key, this.itemId});

  // Factory constructor to handle arguments from Get.toNamed
  factory RMForm.fromArguments() {
    final arguments = Get.arguments;
    int? itemId;

    if (arguments != null) {
      if (arguments is Map<String, dynamic>) {
        if (arguments.containsKey('itemId')) {
          itemId = arguments['itemId'] as int?;
        } else if (arguments.containsKey('id')) {
          itemId = arguments['id'] as int?;
        }
      }
    }

    return RMForm(itemId: itemId);
  }

  @override
  State<RMForm> createState() => _RMFormState();
}

class _RMFormState extends State<RMForm> {
  final _formKey = GlobalKey<FormState>();
  final OptionsController _optionsController = Get.find<OptionsController>();

  // Form controllers
  final TextEditingController _uinController = TextEditingController();
  final TextEditingController _shortCodeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _makeController = TextEditingController();
  final TextEditingController _hsnCodeController = TextEditingController();
  final TextEditingController _spqController = TextEditingController();
  final TextEditingController _moqController = TextEditingController();
  final TextEditingController _samplingPercentController =
      TextEditingController();

  // Selected values
  String? _selectedUOM;
  String? _selectedCategory;
  String? _selectedGSTSlab;

  // Boolean values
  bool _supplierTestRequired = false;
  bool _iqc = false;

  // Loading state
  bool _isLoading = false;
  bool _isLoadingData = false;

  // Getter for edit mode
  bool get _isEditMode => widget.itemId != null;

  @override
  void initState() {
    super.initState();
    // Ensure options are loaded first, then fetch item data if in edit mode
    if (!_optionsController.hasData) {
      _optionsController.fetchOptions().then((_) {
        debugPrint(
          'Options loaded. Category options count: ${_optionsController.itemCategoryOptions.length}',
        );
        // If in edit mode, fetch item data after options are loaded
        if (_isEditMode) {
          _fetchItemData();
        }
      });
    } else {
      debugPrint(
        'Options already loaded. Category options count: ${_optionsController.itemCategoryOptions.length}',
      );
      // If in edit mode, fetch item data
      if (_isEditMode) {
        _fetchItemData();
      }
    }
  }

  // Helper method to get UOM options with fallback
  List<Option> get _uomOptionsWithFallback {
    // Try by type ID first
    if (_optionsController.uomOptions.isNotEmpty) {
      return _optionsController.uomOptions;
    }

    // Try by type name
    if (_optionsController.uomOptionsByName.isNotEmpty) {
      return _optionsController.uomOptionsByName;
    }

    // Try alternative name
    if (_optionsController.uomOptionsByNameAlt.isNotEmpty) {
      return _optionsController.uomOptionsByNameAlt;
    }

    // Try to find UOM by searching through all types
    if (_optionsController.optionsData != null) {
      for (var type in _optionsController.optionsData!.types) {
        if (type.typeName.toLowerCase().contains('uom') ||
            type.typeName.toLowerCase().contains('unit') ||
            type.typeName.toLowerCase().contains('measurement')) {
          return type.options;
        }
      }
    }

    return [];
  }

  // Helper method to get GST Slab options with fallback
  List<Option> get _gstSlabOptionsWithFallback {
    // Try by type ID first
    if (_optionsController.gstSlabOptions.isNotEmpty) {
      return _optionsController.gstSlabOptions;
    }

    // Try by type name
    if (_optionsController.gstSlabOptionsByName.isNotEmpty) {
      return _optionsController.gstSlabOptionsByName;
    }

    // Try to find GST Slab by searching through all types
    if (_optionsController.optionsData != null) {
      for (var type in _optionsController.optionsData!.types) {
        if (type.typeName.toLowerCase().contains('gst') ||
            type.typeName.toLowerCase().contains('slab')) {
          return type.options;
        }
      }
    }

    return [];
  }

  // Helper method to get Category options with fallback
  List<Option> get _categoryOptionsWithFallback {
    debugPrint('Getting category options with fallback...');

    // Try by type ID first
    if (_optionsController.itemCategoryOptions.isNotEmpty) {
      debugPrint(
        'Found ${_optionsController.itemCategoryOptions.length} category options by type ID',
      );
      return _optionsController.itemCategoryOptions;
    }

    // Try to find Category by searching through all types
    if (_optionsController.optionsData != null) {
      debugPrint(
        'Searching through ${_optionsController.optionsData!.types.length} types for category...',
      );
      for (var type in _optionsController.optionsData!.types) {
        debugPrint(
          'Checking type: ${type.typeName} (${type.options.length} options)',
        );
        if (type.typeName.toLowerCase().contains('category') ||
            type.typeName.toLowerCase().contains('item category')) {
          debugPrint(
            'Found category type: ${type.typeName} with ${type.options.length} options',
          );
          return type.options;
        }
      }
    }

    debugPrint('No category options found');
    return [];
  }

  // Fetch item data for edit mode
  Future<void> _fetchItemData() async {
    if (widget.itemId == null) return;

    setState(() {
      _isLoadingData = true;
    });

    try {
      // Ensure options are loaded before fetching item data
      if (!_optionsController.hasData) {
        await _optionsController.fetchOptions();
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        SnackbarUtils.showError(
          'Authentication token not found. Please login again.',
        );
        return;
      }

      final response = await http.get(
        Uri.parse(
          'https://1.sunshineiot.in/api/v2/store/item/54/${widget.itemId}',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final itemData = json.decode(response.body);
        debugPrint('Fetched item data: $itemData');
        debugPrint('Item data keys: ${itemData.keys.toList()}');
        debugPrint('Category-related fields in response:');
        debugPrint('  category_id: ${itemData['category_id']}');
        debugPrint('  category: ${itemData['category']}');
        debugPrint('  category_name: ${itemData['category_name']}');
        _populateFormWithData(itemData);
      } else {
        debugPrint(
          'Failed to fetch item data. Status: ${response.statusCode}, Body: ${response.body}',
        );
        SnackbarUtils.showError(
          'Failed to fetch item data: ${response.statusCode}',
        );
      }
    } catch (e) {
      SnackbarUtils.showError('Error fetching item data: ${e.toString()}');
    } finally {
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  // Populate form with fetched data
  void _populateFormWithData(Map<String, dynamic> itemData) {
    debugPrint('Populating form with data: $itemData');
    debugPrint(
      'supplier_test_required: ${itemData['supplier_test_required']} (type: ${itemData['supplier_test_required'].runtimeType})',
    );
    debugPrint(
      'iqc: ${itemData['iqc']} (type: ${itemData['iqc'].runtimeType})',
    );

    setState(() {
      _uinController.text = itemData['uin']?.toString() ?? '';
      _shortCodeController.text = itemData['short_code']?.toString() ?? '';
      _descriptionController.text = itemData['description']?.toString() ?? '';
      _makeController.text = itemData['make']?.toString() ?? '';
      _hsnCodeController.text = itemData['hsn_code']?.toString() ?? '';
      _spqController.text = itemData['spq']?.toString() ?? '';
      _moqController.text = itemData['moq']?.toString() ?? '';
      _samplingPercentController.text =
          itemData['sampling_percent']?.toString() ?? '';

      // Convert integer to boolean for checkbox fields
      _supplierTestRequired =
          itemData['supplier_test_required'] == 1 ||
          itemData['supplier_test_required'] == true;
      _iqc = itemData['iqc'] == 1 || itemData['iqc'] == true;

      // Set dropdown values
      _setDropdownValues(itemData);
    });

    // Force UI update after a short delay to ensure dropdowns are properly set
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {});
        debugPrint('UI updated. Current category value: $_selectedCategory');
      }
    });
  }

  // Set dropdown values based on fetched data
  void _setDropdownValues(Map<String, dynamic> itemData) {
    debugPrint(
      'Setting dropdown values for: uom=${itemData['uom']}, category_id=${itemData['category_id']}, gst_slab=${itemData['gst_slab']}',
    );

    // Set UOM
    final uomValue = itemData['uom'];
    if (uomValue != null) {
      debugPrint(
        'Looking for UOM with value: $uomValue (type: ${uomValue.runtimeType})',
      );
      final uomOptions = _uomOptionsWithFallback;
      debugPrint(
        'Available UOM options: ${uomOptions.map((o) => '${o.optionId}:${o.optionName}').toList()}',
      );

      if (uomOptions.isNotEmpty) {
        Option? uomOption;

        // Try different matching strategies
        if (uomValue is int) {
          // If it's an integer, try to find by optionId
          uomOption = uomOptions.firstWhere(
            (option) => option.optionId == uomValue,
            orElse: () => Option(optionId: 0, optionName: ''),
          );
        } else if (uomValue is String) {
          // If it's a string, try to find by optionName
          uomOption = uomOptions.firstWhere(
            (option) =>
                option.optionName.toLowerCase() == uomValue.toLowerCase(),
            orElse: () => Option(optionId: 0, optionName: ''),
          );

          // If not found by exact match, try partial match
          if (uomOption.optionId == 0) {
            uomOption = uomOptions.firstWhere(
              (option) =>
                  option.optionName.toLowerCase().contains(
                    uomValue.toLowerCase(),
                  ) ||
                  uomValue.toLowerCase().contains(
                    option.optionName.toLowerCase(),
                  ),
              orElse: () => Option(optionId: 0, optionName: ''),
            );
          }
        }

        if (uomOption != null && uomOption.optionId != 0) {
          _selectedUOM = '${uomOption.optionId} - ${uomOption.optionName}';
          debugPrint('Set UOM to: $_selectedUOM');
        } else {
          // Fallback: create a display value from the original data
          if (uomValue is int) {
            final uomName = _optionsController.getOptionNameById(uomValue);
            if (uomName != null) {
              _selectedUOM = '$uomValue - $uomName';
              debugPrint('Set UOM to (fallback): $_selectedUOM');
            }
          } else if (uomValue is String) {
            // For string values, we might need to find the corresponding option
            final matchingOption = uomOptions.firstWhere(
              (option) => option.optionName.toLowerCase().contains(
                uomValue.toLowerCase(),
              ),
              orElse: () => Option(optionId: 0, optionName: ''),
            );
            if (matchingOption.optionId != 0) {
              _selectedUOM =
                  '${matchingOption.optionId} - ${matchingOption.optionName}';
              debugPrint('Set UOM to (string fallback): $_selectedUOM');
            }
          }
        }
      }
    }

    // Set Category
    final categoryValue =
        itemData['category_id'] ??
        itemData['category'] ??
        itemData['category_name'];
    if (categoryValue != null) {
      debugPrint(
        'Looking for Category with value: $categoryValue (type: ${categoryValue.runtimeType})',
      );
      debugPrint(
        'All category-related fields: category_id=${itemData['category_id']}, category=${itemData['category']}, category_name=${itemData['category_name']}',
      );
      final categoryOptions = _categoryOptionsWithFallback;
      debugPrint(
        'Available Category options: ${categoryOptions.map((o) => '${o.optionId}:${o.optionName}').toList()}',
      );
      debugPrint('Category options count: ${categoryOptions.length}');

      if (categoryOptions.isNotEmpty) {
        Option? categoryOption;

        // Try different matching strategies
        if (categoryValue is int) {
          // If it's an integer, try to find by optionId
          categoryOption = categoryOptions.firstWhere(
            (option) => option.optionId == categoryValue,
            orElse: () => Option(optionId: 0, optionName: ''),
          );
        } else if (categoryValue is String) {
          // If it's a string, try to find by optionName
          categoryOption = categoryOptions.firstWhere(
            (option) =>
                option.optionName.toLowerCase() == categoryValue.toLowerCase(),
            orElse: () => Option(optionId: 0, optionName: ''),
          );

          // If not found by exact match, try partial match
          if (categoryOption.optionId == 0) {
            categoryOption = categoryOptions.firstWhere(
              (option) =>
                  option.optionName.toLowerCase().contains(
                    categoryValue.toLowerCase(),
                  ) ||
                  categoryValue.toLowerCase().contains(
                    option.optionName.toLowerCase(),
                  ),
              orElse: () => Option(optionId: 0, optionName: ''),
            );
          }
        }

        if (categoryOption != null && categoryOption.optionId != 0) {
          _selectedCategory =
              '${categoryOption.optionId} - ${categoryOption.optionName}';
          debugPrint('Set Category to: $_selectedCategory');
        } else {
          // Fallback: create a display value from the original data
          if (categoryValue is int) {
            final categoryName = _optionsController.getOptionNameById(
              categoryValue,
            );
            if (categoryName != null) {
              _selectedCategory = '$categoryValue - $categoryName';
              debugPrint('Set Category to (fallback): $_selectedCategory');
            }
          } else if (categoryValue is String) {
            // For string values, we might need to find the corresponding option
            final matchingOption = categoryOptions.firstWhere(
              (option) => option.optionName.toLowerCase().contains(
                categoryValue.toLowerCase(),
              ),
              orElse: () => Option(optionId: 0, optionName: ''),
            );
            if (matchingOption.optionId != 0) {
              _selectedCategory =
                  '${matchingOption.optionId} - ${matchingOption.optionName}';
              debugPrint(
                'Set Category to (string fallback): $_selectedCategory',
              );
            }
          }
        }
      }
    }

    // Set GST Slab - Use optionId for matching
    final gstSlabValue = itemData['gst_slab'];
    if (gstSlabValue != null) {
      debugPrint(
        'Looking for GST Slab with value: $gstSlabValue (type: ${gstSlabValue.runtimeType})',
      );
      final gstSlabOptions = _gstSlabOptionsWithFallback;
      debugPrint(
        'Available GST Slab options: ${gstSlabOptions.map((o) => '${o.optionId}:${o.optionName}').toList()}',
      );

      if (gstSlabOptions.isNotEmpty) {
        Option? gstSlabOption;

        // For GST slab, we expect the API to return the optionId
        if (gstSlabValue is int) {
          // If it's an integer, try to find by optionId
          gstSlabOption = gstSlabOptions.firstWhere(
            (option) => option.optionId == gstSlabValue,
            orElse: () => Option(optionId: 0, optionName: ''),
          );
        } else if (gstSlabValue is String) {
          // If it's a string, try to parse as integer first (optionId)
          final parsedId = int.tryParse(gstSlabValue);
          if (parsedId != null) {
            gstSlabOption = gstSlabOptions.firstWhere(
              (option) => option.optionId == parsedId,
              orElse: () => Option(optionId: 0, optionName: ''),
            );
          }

          // If not found by ID, try to find by optionName
          if (gstSlabOption == null || gstSlabOption.optionId == 0) {
            gstSlabOption = gstSlabOptions.firstWhere(
              (option) =>
                  option.optionName.toLowerCase() == gstSlabValue.toLowerCase(),
              orElse: () => Option(optionId: 0, optionName: ''),
            );
          }
        }

        if (gstSlabOption != null && gstSlabOption.optionId != 0) {
          _selectedGSTSlab =
              '${gstSlabOption.optionId} - ${gstSlabOption.optionName}';
          debugPrint('Set GST Slab to: $_selectedGSTSlab');
        } else {
          // Fallback: create a display value from the original data
          if (gstSlabValue is int) {
            final gstSlabName = _optionsController.getOptionNameById(
              gstSlabValue,
            );
            if (gstSlabName != null) {
              _selectedGSTSlab = '$gstSlabValue - $gstSlabName';
              debugPrint('Set GST Slab to (fallback): $_selectedGSTSlab');
            }
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _uinController.dispose();
    _shortCodeController.dispose();
    _descriptionController.dispose();
    _makeController.dispose();
    _hsnCodeController.dispose();
    _spqController.dispose();
    _moqController.dispose();
    _samplingPercentController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedUOM == null ||
        _selectedCategory == null ||
        _selectedGSTSlab == null) {
      SnackbarUtils.showError('Please select all required dropdown options');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      // Extract option IDs
      final uomId = OptionsService.extractOptionId(_selectedUOM!);
      final categoryId = OptionsService.extractOptionId(_selectedCategory!);
      final gstSlabId = OptionsService.extractOptionId(_selectedGSTSlab!);

      if (gstSlabId == null) {
        SnackbarUtils.showError('Invalid GST Slab selection');
        return;
      }

      final requestBody = {
        "short_code": _shortCodeController.text.trim(),
        "description": _descriptionController.text.trim(),
        "make": _makeController.text.trim(),
        "uom": uomId,
        "category_id": categoryId,
        "hsn_code": _hsnCodeController.text.trim(),
        "spq": int.tryParse(_spqController.text) ?? 0,
        "moq": int.tryParse(_moqController.text) ?? 0,
        "supplier_test_required": _supplierTestRequired,
        "iqc": _iqc,
        "sampling_percent":
            double.tryParse(_samplingPercentController.text) ?? 0.0,
        "gst_slab": gstSlabId,
      };

      // Add UIN only for add mode (not for edit mode)
      if (!_isEditMode) {
        requestBody["uin"] = _uinController.text.trim();
      }

      http.Response response;

      if (_isEditMode) {
        // Edit mode - use PUT request
        final updateUrl =
            'https://1.sunshineiot.in/api/v2/store/item/rm/${widget.itemId}';
        debugPrint('Updating item with URL: $updateUrl');
        debugPrint('Update request body: $requestBody');

        response = await http.put(
          Uri.parse(updateUrl),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode(requestBody),
        );

        debugPrint('Update response status: ${response.statusCode}');
        debugPrint('Update response body: ${response.body}');
      } else {
        // Add mode - use POST request
        final addUrl = 'https://1.sunshineiot.in/api/v2/store/item/rm';
        debugPrint('Adding item with URL: $addUrl');
        debugPrint('Add request body: $requestBody');

        response = await http.post(
          Uri.parse(addUrl),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode(requestBody),
        );

        debugPrint('Add response status: ${response.statusCode}');
        debugPrint('Add response body: ${response.body}');
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        try {
          final responseData = json.decode(response.body);

          final message =
              responseData['message'] ??
              (_isEditMode
                  ? 'Item updated successfully'
                  : 'Item added successfully');

          // Show success message first
          SnackbarUtils.showSuccess(message);
          // Wait a bit for the snackbar to show, then navigate to item screen
          await Future.delayed(const Duration(milliseconds: 1500));
          Get.offAllNamed(
            '/dashboard/store/items',
          ); // Navigate to items screen and clear navigation stack
        } catch (e) {
          SnackbarUtils.showError('Error parsing response: $e');
        }
      } else {
        try {
          final errorData = json.decode(response.body);
          final errorMessage =
              errorData['message'] ??
              (_isEditMode ? 'Failed to update item' : 'Failed to add item');
          SnackbarUtils.showError(errorMessage);
        } catch (e) {
          final errorMessage = _isEditMode
              ? 'Failed to update item'
              : 'Failed to add item';
          SnackbarUtils.showError('$errorMessage: ${response.statusCode}');
        }
      }
    } catch (e) {
      SnackbarUtils.showError('Error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showFormOverview() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Form Overview'),
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
                    'UIN',
                    _uinController.text.isNotEmpty
                        ? _uinController.text
                        : 'Not filled',
                  ),
                  _buildTableRow(
                    'Short Code',
                    _shortCodeController.text.isNotEmpty
                        ? _shortCodeController.text
                        : 'Not filled',
                  ),
                  _buildTableRow(
                    'Description',
                    _descriptionController.text.isNotEmpty
                        ? _descriptionController.text
                        : 'Not filled',
                  ),
                  _buildTableRow(
                    'Make',
                    _makeController.text.isNotEmpty
                        ? _makeController.text
                        : 'Not filled',
                  ),
                  _buildTableRow(
                    'HSN Code',
                    _hsnCodeController.text.isNotEmpty
                        ? _hsnCodeController.text
                        : 'Not filled',
                  ),
                  _buildTableRow(
                    'SPQ',
                    _spqController.text.isNotEmpty
                        ? _spqController.text
                        : 'Not filled',
                  ),
                  _buildTableRow(
                    'MOQ',
                    _moqController.text.isNotEmpty
                        ? _moqController.text
                        : 'Not filled',
                  ),
                  _buildTableRow(
                    'Sampling Percent',
                    _samplingPercentController.text.isNotEmpty
                        ? _samplingPercentController.text
                        : 'Not filled',
                  ),
                  _buildTableRow(
                    'Unit of Measurement',
                    _selectedUOM ?? 'Not selected',
                  ),
                  _buildTableRow(
                    'Item Category',
                    _selectedCategory ?? 'Not selected',
                  ),
                  _buildTableRow(
                    'GST Slab',
                    _selectedGSTSlab ?? 'Not selected',
                  ),
                  _buildTableRow(
                    'Supplier Test Required',
                    _supplierTestRequired ? 'Yes' : 'No',
                  ),
                  _buildTableRow('IQC', _iqc ? 'Yes' : 'No'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Raw Material' : 'Add Raw Material'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Obx(() {
        if (_optionsController.isLoading || _isLoadingData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_optionsController.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: ${_optionsController.errorMessage}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _optionsController.fetchOptions(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 Section Card: Item Details
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade200, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section Header
                      Row(
                        children: const [
                          Icon(
                            Icons.inventory_2_outlined,
                            color: Colors.blue,
                            size: 22,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Item Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 🔹 Two-column Layout
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // LEFT COLUMN
                          Expanded(
                            child: Column(
                              children: [
                                _buildTextField(
                                  controller: _uinController,
                                  label: "UIN *",
                                  hint: "Enter UIN",
                                  enabled: !_isEditMode,
                                  isRequired: !_isEditMode,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _shortCodeController,
                                  label: "Short Code *",
                                  hint: "Enter short code",
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _descriptionController,
                                  label: "Description *",
                                  hint: "Enter description",
                                  maxLines: 3,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _makeController,
                                  label: "Make *",
                                  hint: "Enter make/company",
                                ),
                                const SizedBox(height: 16),
                                SearchableDropdown(
                                  label: "Unit of Measurement",
                                  hint: "Select UOM",
                                  options: _uomOptionsWithFallback,
                                  value: _selectedUOM,
                                  onChanged: (value) {
                                    setState(() => _selectedUOM = value);
                                  },
                                  validator: (value) =>
                                      value == null || value.isEmpty
                                      ? "Please select UOM"
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                SearchableDropdown(
                                  label: "Item Category",
                                  hint: "Select Item Category",
                                  options:
                                      _optionsController.itemCategoryOptions,
                                  value: _selectedCategory,
                                  onChanged: (value) {
                                    setState(() => _selectedCategory = value);
                                  },
                                  validator: (value) =>
                                      value == null || value.isEmpty
                                      ? "Please select Category"
                                      : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),

                          // RIGHT COLUMN
                          Expanded(
                            child: Column(
                              children: [
                                _buildTextField(
                                  controller: _hsnCodeController,
                                  label: "HSN Code *",
                                  hint: "Enter HSN code",
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _spqController,
                                  label: "SPQ *",
                                  hint: "Enter SPQ",
                                  keyboardType: TextInputType.number,
                                  numberOnly: true,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _moqController,
                                  label: "MOQ *",
                                  hint: "Enter MOQ",
                                  keyboardType: TextInputType.number,
                                  numberOnly: true,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _samplingPercentController,
                                  label: "Sampling Percent *",
                                  hint: "Enter % value",
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  numberOnly: true,
                                ),
                                const SizedBox(height: 16),
                                SearchableDropdown(
                                  label: "GST Slab",
                                  hint: "Select GST Slab",
                                  options: _gstSlabOptionsWithFallback,
                                  value: _selectedGSTSlab,
                                  onChanged: (value) {
                                    setState(() => _selectedGSTSlab = value);
                                  },
                                  validator: (value) =>
                                      value == null || value.isEmpty
                                      ? "Please select GST slab"
                                      : null,
                                ),
                                const SizedBox(height: 16),

                                // 🔹 Additional Options
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Additional Options",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SwitchListTile(
                                        title: const Text(
                                          "Supplier Test Required",
                                        ),
                                        value: _supplierTestRequired,
                                        onChanged: (value) {
                                          setState(
                                            () => _supplierTestRequired = value,
                                          );
                                        },
                                      ),
                                      SwitchListTile(
                                        title: const Text("IQC"),
                                        value: _iqc,
                                        onChanged: (value) {
                                          setState(() => _iqc = value);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // 🔹 Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _showFormOverview,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.visibility),
                      label: const Text("View"),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.save_alt),
                      label: Text(_isEditMode ? "Update" : "Submit"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

        /// 🔹 Helper widget for cleaner text fields
      }),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool enabled = true,
    int maxLines = 1,
    bool isRequired = true,
    TextInputType? keyboardType,
    bool numberOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        filled: !enabled,
        fillColor: !enabled ? Colors.grey.shade100 : null,
      ),
      validator: (value) {
        if (isRequired && (value == null || value.trim().isEmpty)) {
          return "$label is required";
        }
        if (numberOnly && value != null && value.isNotEmpty) {
          if (double.tryParse(value) == null) {
            return "Please enter a valid number";
          }
        }
        return null;
      },
    );
  }
}
