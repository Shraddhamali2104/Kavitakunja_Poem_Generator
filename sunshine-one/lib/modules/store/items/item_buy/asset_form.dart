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
        if (widget.isRequired)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              '${widget.label} *',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
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
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
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
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
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

class AssetForm extends StatefulWidget {
  final int? itemId; // Add itemId parameter for edit mode

  const AssetForm({super.key, this.itemId});

  // Factory constructor to handle arguments from Get.toNamed
  factory AssetForm.fromArguments() {
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

    return AssetForm(itemId: itemId);
  }

  @override
  State<AssetForm> createState() => _AssetFormState();
}

class _AssetFormState extends State<AssetForm> {
  final _formKey = GlobalKey<FormState>();
  final OptionsController _optionsController = Get.find<OptionsController>();

  // Form controllers
  final TextEditingController _uinController = TextEditingController();
  final TextEditingController _shortCodeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _makeController = TextEditingController();
  final TextEditingController _hsnCodeController = TextEditingController();

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
        debugPrint(
          'GST Slab options count: ${_optionsController.gstSlabOptions.length}',
        );
        debugPrint(
          'GST Slab options: ${_optionsController.gstSlabOptions.map((o) => '${o.optionId}:${o.optionName}').toList()}',
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
      debugPrint(
        'GST Slab options count: ${_optionsController.gstSlabOptions.length}',
      );
      debugPrint(
        'GST Slab options: ${_optionsController.gstSlabOptions.map((o) => '${o.optionId}:${o.optionName}').toList()}',
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
    debugPrint('Getting GST Slab options with fallback...');

    // Try by type ID first
    if (_optionsController.gstSlabOptions.isNotEmpty) {
      debugPrint(
        'Found ${_optionsController.gstSlabOptions.length} GST Slab options by type ID',
      );
      debugPrint(
        'GST Slab options by type ID: ${_optionsController.gstSlabOptions.map((o) => '${o.optionId}:${o.optionName}').toList()}',
      );
      return _optionsController.gstSlabOptions;
    }

    // Try by type name
    if (_optionsController.gstSlabOptionsByName.isNotEmpty) {
      debugPrint(
        'Found ${_optionsController.gstSlabOptionsByName.length} GST Slab options by type name',
      );
      debugPrint(
        'GST Slab options by type name: ${_optionsController.gstSlabOptionsByName.map((o) => '${o.optionId}:${o.optionName}').toList()}',
      );
      return _optionsController.gstSlabOptionsByName;
    }

    // Try to find GST Slab by searching through all types
    if (_optionsController.optionsData != null) {
      debugPrint(
        'Searching through ${_optionsController.optionsData!.types.length} types for GST Slab...',
      );
      for (var type in _optionsController.optionsData!.types) {
        debugPrint(
          'Checking type: ${type.typeName} (${type.options.length} options)',
        );
        if (type.typeName.toLowerCase().contains('gst') ||
            type.typeName.toLowerCase().contains('slab')) {
          debugPrint(
            'Found GST Slab type: ${type.typeName} with ${type.options.length} options',
          );
          debugPrint(
            'GST Slab options found: ${type.options.map((o) => '${o.optionId}:${o.optionName}').toList()}',
          );
          return type.options;
        }
      }
    }

    debugPrint('No GST Slab options found');
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
          'https://1.sunshineiot.in/api/v2/store/item/55/${widget.itemId}',
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
        debugPrint('GST Slab field in response:');
        debugPrint(
          '  gst_slab: ${itemData['gst_slab']} (type: ${itemData['gst_slab']?.runtimeType})',
        );
        debugPrint('  gst_slab_id: ${itemData['gst_slab_id']}');
        debugPrint('  gst_slab_name: ${itemData['gst_slab_name']}');
        debugPrint('  gst: ${itemData['gst']}');
        debugPrint('  gst_id: ${itemData['gst_id']}');
        debugPrint('  gst_name: ${itemData['gst_name']}');
        debugPrint('  slab: ${itemData['slab']}');
        debugPrint('  slab_id: ${itemData['slab_id']}');
        debugPrint('  slab_name: ${itemData['slab_name']}');
        debugPrint(
          'All fields containing "gst" or "slab": ${itemData.keys.where((key) => key.toLowerCase().contains('gst') || key.toLowerCase().contains('slab')).toList()}',
        );
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
        "supplier_test_required": _supplierTestRequired,
        "iqc": _iqc,
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
            'https://1.sunshineiot.in/api/v2/store/item/asset/${widget.itemId}';
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
        final addUrl = 'https://1.sunshineiot.in/api/v2/store/item/asset';
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
        title: Text(_isEditMode ? 'Edit Asset' : 'Add Asset'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
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
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _isEditMode ? 'Edit Asset Details' : 'Asset Details',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Two Column Layout
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column
                    Expanded(
                      child: Column(
                        children: [
                          // UIN
                          TextFormField(
                            controller: _uinController,
                            enabled: !_isEditMode, // Disable in edit mode
                            decoration: InputDecoration(
                              labelText: 'UIN *',
                              hintText: 'Enter UIN',
                              border: const OutlineInputBorder(),
                              filled: _isEditMode,
                              fillColor: _isEditMode ? Colors.grey[200] : null,
                            ),
                            validator: (value) {
                              if (!_isEditMode &&
                                  (value == null || value.trim().isEmpty)) {
                                return 'UIN is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Short Code
                          TextFormField(
                            controller: _shortCodeController,
                            decoration: const InputDecoration(
                              labelText: 'Short Code *',
                              hintText: 'Enter short code',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Short code is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Description
                          TextFormField(
                            controller: _descriptionController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Description *',
                              hintText: 'Enter description',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Description is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Make
                          TextFormField(
                            controller: _makeController,
                            decoration: const InputDecoration(
                              labelText: 'Make *',
                              hintText: 'Enter make/company name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Make is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // UOM Dropdown
                          SearchableDropdown(
                            label: 'Unit of Measurement',
                            hint: 'Select UOM',
                            options: _uomOptionsWithFallback,
                            value: _selectedUOM,
                            onChanged: (newValue) {
                              setState(() {
                                _selectedUOM = newValue;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select UOM';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Category Dropdown
                          SearchableDropdown(
                            label: 'Item Category',
                            hint: 'Select Item Category',
                            options: _optionsController.itemCategoryOptions,
                            value: _selectedCategory,
                            onChanged: (newValue) {
                              setState(() {
                                _selectedCategory = newValue;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select Item Category';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Right Column
                    Expanded(
                      child: Column(
                        children: [
                          // HSN Code
                          TextFormField(
                            controller: _hsnCodeController,
                            decoration: const InputDecoration(
                              labelText: 'HSN Code *',
                              hintText: 'Enter HSN code',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'HSN code is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // GST Slab Dropdown
                          SearchableDropdown(
                            label: 'GST Slab',
                            hint: 'Select GST Slab',
                            options: _gstSlabOptionsWithFallback,
                            value: _selectedGSTSlab,
                            onChanged: (newValue) {
                              setState(() {
                                _selectedGSTSlab = newValue;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select GST Slab';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Checkboxes
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Additional Options',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                CheckboxListTile(
                                  title: const Text('Supplier Test Required'),
                                  value: _supplierTestRequired,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      _supplierTestRequired = value ?? false;
                                    });
                                  },
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                CheckboxListTile(
                                  title: const Text('IQC'),
                                  value: _iqc,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      _iqc = value ?? false;
                                    });
                                  },
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _isLoading ? null : _showFormOverview,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                      ),
                      child: const Text('View'),
                    ),
                    const SizedBox(width: 20),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(_isEditMode ? 'Update' : 'Submit'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
