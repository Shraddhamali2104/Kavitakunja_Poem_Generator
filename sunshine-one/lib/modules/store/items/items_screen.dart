import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:myoffice_sunshine/utils/standard_table_style.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import '../../../../controllers/options_controller.dart';
import '../../../../utils/snackbar_message.dart';
import 'dart:convert';
import 'dart:html' as html; // ✅ Web only
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

class ItemsController extends GetxController {
  var items = <Map<String, dynamic>>[].obs;
  var allItems =
      <Map<String, dynamic>>[].obs; // Store all items for client-side filtering
  var isLoading = false.obs;
  var errorMessage = ''.obs;
  var total = 0.obs;
  var page = 1.obs;
  var limit = 20.obs;
  var totalPages = 1.obs;
  var searchText = ''.obs;
  var showItemForm = false.obs;
  var editingItem = Rxn<Map<String, dynamic>>();
  var isViewingItem = false.obs; // For view button loading state

  // New variables for filtering
  var selectedItemTypeId = Rxn<int>();
  var selectedItemId = Rxn<int>();
  var availableItemTypes = <Map<String, dynamic>>[].obs;

  // Computed property for filtered items
  List<Map<String, dynamic>> get filteredItems {
    if (searchText.value.isEmpty) {
      return items;
    }

    final searchLower = searchText.value.toLowerCase();
    final currentItemTypeId = selectedItemTypeId.value;
    final itemTypeName = getItemTypeNameById(currentItemTypeId ?? 0);

    return items.where((item) {
      // Search in ID
      if (item['id']?.toString().toLowerCase().contains(searchLower) == true) {
        return true;
      }

      // Search in description
      if (item['description']?.toString().toLowerCase().contains(searchLower) ==
          true) {
        return true;
      }

      // Search in HSN code
      if (item['hsn_code']?.toString().toLowerCase().contains(searchLower) ==
          true) {
        return true;
      }

      // Search in category (for RM and Asset)
      if (itemTypeName != 'Service' && itemTypeName != 'Finished Goods') {
        final categoryName = getCategoryNameById(item['category_id']);
        // Only search in category if it's not in loading state
        if (categoryName != 'Loading...' &&
            categoryName.toLowerCase().contains(searchLower)) {
          return true;
        }
      }

      // Search in rate (for Finished Goods)
      if (itemTypeName == 'Finished Goods') {
        if (item['rate']?.toString().toLowerCase().contains(searchLower) ==
            true) {
          return true;
        }
      }

      // Search in SAC code (for Service)
      if (itemTypeName == 'Service') {
        if (item['sac_code']?.toString().toLowerCase().contains(searchLower) ==
            true) {
          return true;
        }
      }

      return false;
    }).toList();
  }

  // final List<String> buyItemTypes = [
  //   'RM',
  //   'Asset',
  //   'Service',
  // ];

  String? selectedBuyType;

  @override
  void onInit() {
    super.onInit();
    loadItemTypes();
    // Set default item type to RM (54) when page loads
    selectedItemTypeId.value = 54;
    // Ensure options are loaded before fetching items
    _ensureOptionsLoaded();
  }

  // Ensure options are loaded before fetching items
  Future<void> _ensureOptionsLoaded() async {
    final optionsController = Get.find<OptionsController>();

    // If options are not loaded yet, wait for them to load
    if (!optionsController.hasData) {
      await optionsController.fetchOptions();
    }

    // Now fetch items after options are loaded
    fetchItems();
  }

  // Validate category IDs in current items
  void validateCategoryIds() {
    final optionsController = Get.find<OptionsController>();
    if (!optionsController.hasData) {
      debugPrint('Options not loaded yet, cannot validate category IDs');
      return;
    }

    final currentItemTypeId = selectedItemTypeId.value;
    final itemTypeName = getItemTypeNameById(currentItemTypeId ?? 0);

    // Only validate for RM and Asset items that have categories
    if (itemTypeName == 'RM' || itemTypeName == 'Asset') {
      for (final item in items) {
        final categoryId = item['category_id'];
        if (categoryId != null) {
          final categoryName = optionsController.getOptionNameById(categoryId);
          if (categoryName == null) {
            debugPrint(
              'Invalid category ID $categoryId for item ${item['id']} (${item['description']})',
            );
            debugPrint(
              'Invalid category ID $categoryId for item ${item['id']} (${item['description']})',
            );
          }
        }
      }
    }
  }

  // Refresh category names when options are loaded
  void refreshCategoryNames() {
    // Trigger a refresh of the items list to update category names
    items.refresh();
    // Validate category IDs after refresh
    validateCategoryIds();
  }

  // Load item types from options controller
  void loadItemTypes() {
    final optionsController = Get.find<OptionsController>();
    final itemTypeOptions = optionsController.itemTypeOptions;

    availableItemTypes.value = itemTypeOptions
        .map((option) => {'id': option.optionId, 'name': option.optionName})
        .toList();

    availableItemTypes.value = itemTypeOptions
        .map((option) => {'id': option.optionId, 'name': option.optionName})
        .toList();

    // Using debugPrint instead of print for production code
    debugPrint('Loaded item types: $availableItemTypes');
  }

  // Map tab indices to item type names with their corresponding item_type_id
  final Map<String, int> _tabItemTypeIds = {
    'RM': 54,
    'Asset': 55,
    'Finished Goods': 51,
    'Service': 56,
  };

  // Get item type ID by name using the predefined mapping
  int? getItemTypeIdByName(String typeName) {
    return _tabItemTypeIds[typeName];
  }

  // Get item type name by ID
  String? getItemTypeNameById(int typeId) {
    for (var entry in _tabItemTypeIds.entries) {
      if (entry.value == typeId) {
        return entry.key;
      }
    }
    return null;
  }

  // Get option ID by name using options controller
  int? getOptionIdByName(String typeName) {
    final optionsController = Get.find<OptionsController>();
    return optionsController.getOptionIdByName(typeName);
  }

  // Get category name by ID using options controller
  String getCategoryNameById(int? categoryId) {
    if (categoryId == null) return '';

    final optionsController = Get.find<OptionsController>();

    // Check if options are loaded
    if (!optionsController.hasData) {
      return 'Loading...'; // Show loading state instead of unknown category
    }

    final categoryName = optionsController.getOptionNameById(categoryId);
    if (categoryName == null) {
      // Log the unknown category ID for debugging
      debugPrint('Unknown category ID: $categoryId');
      return 'Unknown Category (ID: $categoryId)'; // Include the ID for debugging
    }

    return categoryName;
  }

  Future<void> fetchItems() async {
    isLoading.value = true;
    errorMessage.value = '';

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) {
      items.value = [];
      total.value = 0;
      totalPages.value = 1;
      errorMessage.value =
          'Authentication token not found. Please login again.';
      isLoading.value = false;
      SnackbarUtils.showError(
        'Authentication token not found. Please login again.',
      );
      return;
    }

    if (token == null) {
      items.value = [];
      total.value = 0;
      totalPages.value = 1;
      errorMessage.value =
          'Authentication token not found. Please login again.';
      isLoading.value = false;
      SnackbarUtils.showError(
        'Authentication token not found. Please login again.',
      );
      return;
    }

    try {
      // Build query parameters
      final queryParams = <String, String>{
        'page': page.value.toString(),
        'limit': limit.value.toString(),
        // Remove search parameter since we're doing client-side filtering
        // 'search': searchText.value,
      };

      // Add item_id if selected for specific item filtering
      if (selectedItemId.value != null) {
        queryParams['item_id'] = selectedItemId.value.toString();
      }

      // Build the URL with item_type_id in the path
      final itemTypeId =
          selectedItemTypeId.value ?? 54; // Default to RM if not set
      final uri = Uri.parse(
        'https://1.sunshineiot.in/api/v2/store/item/all/$itemTypeId',
      ).replace(queryParameters: queryParams);

      // Using debugPrint instead of print for production code
      debugPrint('Request URL: $uri');

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      // Using debugPrint instead of print for production code
      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        allItems.value = List<Map<String, dynamic>>.from(data['data'] ?? []);
        items.value =
            allItems.value; // Initialize filtered items with all items
        total.value = data['total'] ?? 0;
        page.value = data['page'] ?? 1;
        limit.value = data['limit'] ?? 10;
        totalPages.value = data['totalPages'] ?? 1;
        errorMessage.value = '';

        // Validate category IDs after items are loaded
        validateCategoryIds();
      } else {
        items.value = [];
        total.value = 0;
        totalPages.value = 1;
        errorMessage.value = 'Failed to fetch items: ${response.statusCode}';
      }
    } catch (e) {
      items.value = [];
      total.value = 0;
      totalPages.value = 1;
      errorMessage.value = 'Error: ${e.toString()}';
    } finally {
      isLoading.value = false;
    }
  }

  void onPageChanged(int newPage) {
    page.value = newPage;
    fetchItems();
  }

  void onLimitChanged(int newLimit) {
    limit.value = newLimit;
    page.value = 1;
    fetchItems();
  }

  // Set item type filter
  void setItemTypeFilter(int? itemTypeId) {
    selectedItemTypeId.value = itemTypeId;
    selectedItemId.value = null; // Clear item ID filter when changing type
    page.value = 1;
    fetchItems();
    // Refresh category names after fetching items
    refreshCategoryNames();
  }

  // Set specific item filter
  void setItemFilter(int? itemId) {
    selectedItemId.value = itemId;
    page.value = 1;
    fetchItems();
  }

  // Clear all filters
  void clearFilters() {
    selectedItemTypeId.value = null;
    selectedItemId.value = null;
    searchText.value = '';
    page.value = 1;
    fetchItems();
  }
}

class ItemTypeTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  const ItemTypeTabBar({
    required this.selectedIndex,
    required this.onTabSelected,
    super.key,
  });

  static const _tabLabels = [
    'Raw Material',
    'Asset',
    'Finished Goods',
    'Service',
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_tabLabels.length, (i) {
                final isSelected = i == selectedIndex;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTabSelected(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.ease,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                      ), // reduced from 12
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.ease,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 14, // reduced from 16
                            letterSpacing: 0.2,
                          ),
                          child: Text(_tabLabels[i]),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

class ItemTable extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final ItemsController controller;
  final void Function(Map<String, dynamic> item) onViewItem;

  const ItemTable({
    required this.items,
    required this.controller,
    required this.onViewItem,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No items found.'));
    }

    // Get current item type
    final currentItemTypeId = controller.selectedItemTypeId.value;
    final itemTypeName = controller.getItemTypeNameById(currentItemTypeId ?? 0);

    // Define headers
    List<String> headers;
    if (itemTypeName == 'Finished Goods') {
      headers = ['ID', 'Description', 'HSN', 'Rate', 'Actions'];
    } else if (itemTypeName == 'Service') {
      headers = ['ID', 'Description', 'SAC Code', 'Actions'];
    } else {
      headers = ['ID', 'Description', 'HSN', 'Category', 'Actions'];
    }
    final widths = <int, TableColumnWidth>{
      for (int i = 0; i < headers.length; i++) i: const FlexColumnWidth(1),
    };

    // Build rows
    final rows = items.map((item) {
      Widget actionsWidget = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // View
          Obx(
            () => IconButton(
              icon: const Icon(Icons.visibility, size: 14),
              tooltip: controller.isViewingItem.value ? 'Loading...' : 'View',
              onPressed: controller.isViewingItem.value
                  ? null
                  : () => onViewItem(item),
              style: IconButton.styleFrom(
                backgroundColor: Colors.blue.shade50,
                foregroundColor: Colors.blue.shade700,
                padding: const EdgeInsets.all(4),
              ),
            ),
          ),

          const SizedBox(width: 6),
          // Edit
          IconButton(
            icon: const Icon(Icons.edit, size: 14),
            tooltip: 'Edit',
            onPressed: () {
              final currentItemTypeId = controller.selectedItemTypeId.value;
              final itemTypeName = controller.getItemTypeNameById(
                currentItemTypeId ?? 0,
              );
              final itemId = item['id'] as int?;
              if (itemTypeName == 'RM') {
                Get.toNamed(
                  '/dashboard/store/items/buy/rm',
                  arguments: itemId != null ? {'itemId': itemId} : item,
                );
              } else if (itemTypeName == 'Asset') {
                Get.toNamed(
                  '/dashboard/store/items/buy/asset',
                  arguments: itemId != null ? {'itemId': itemId} : item,
                );
              } else if (itemTypeName == 'Service') {
                Get.toNamed(
                  '/dashboard/store/items/buy/service',
                  arguments: itemId != null ? {'itemId': itemId} : item,
                );
              } else {
                Get.toNamed('/dashboard/store/items/add', arguments: item);
              }
            },
            style: IconButton.styleFrom(
              backgroundColor: Colors.orange.shade50,
              foregroundColor: Colors.orange.shade700,
              padding: const EdgeInsets.all(4),
            ),
          ),

          const SizedBox(width: 6),
          // Delete
          IconButton(
            icon: const Icon(Icons.delete, size: 14),
            tooltip: 'Delete',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Delete Item'),
                  content: const Text(
                    'Are you sure you want to delete this item?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Get.back(result: false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Get.back(result: true),
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                try {
                  final prefs = await SharedPreferences.getInstance();
                  final token = prefs.getString('jwt_token');
                  if (token == null) {
                    throw Exception('Authentication token not found.');
                  }
                  final itemId = item['id']?.toString();
                  final itemTypeId = controller.selectedItemTypeId.value ?? 54;
                  final response = await http.delete(
                    Uri.parse(
                      'https://1.sunshineiot.in/api/v2/store/item/$itemTypeId/$itemId',
                    ),
                    headers: {'Authorization': 'Bearer $token'},
                  );
                  if (response.statusCode == 200) {
                    final data = json.decode(response.body);
                    if (data['deleted'] == true) {
                      if (context.mounted) {
                        SnackbarUtils.showSuccess('Item deleted successfully');
                      }
                      controller.fetchItems();
                    } else {
                      throw Exception('Failed to delete item');
                    }
                  } else {
                    throw Exception(
                      'Failed to delete item: ${response.statusCode}',
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    SnackbarUtils.showError('Error: ${e.toString()}');
                  }
                }
              }
            },
            style: IconButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red.shade700,
              padding: const EdgeInsets.all(4),
            ),
          ),
        ],
      );

      if (itemTypeName == 'Finished Goods') {
        return [
          Text(item['id']?.toString() ?? ''),
          Text(item['description']?.toString() ?? ''),
          Text(item['hsn_code']?.toString() ?? ''),
          Text(item['rate']?.toString() ?? ''),
          actionsWidget,
        ];
      } else if (itemTypeName == 'Service') {
        return [
          Text(item['id']?.toString() ?? ''),
          Text(item['description']?.toString() ?? ''),
          Text(item['sac_code']?.toString() ?? ''),
          actionsWidget,
        ];
      } else {
        return [
          Text(item['id']?.toString() ?? ''),
          Text(item['description']?.toString() ?? ''),
          Text(item['hsn_code']?.toString() ?? ''),
          Text(controller.getCategoryNameById(item['category_id'])),
          actionsWidget,
        ];
      }
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: CustomTable(headers: headers, rows: rows, columnWidths: widths),
    );
  }
}

class ItemsDashboardView extends StatefulWidget {
  const ItemsDashboardView({super.key});

  @override
  State<ItemsDashboardView> createState() => _ItemsDashboardViewState();
}

class _ItemsDashboardViewState extends State<ItemsDashboardView> {
  final ItemsController controller = Get.put(ItemsController());
  final TextEditingController _searchController = TextEditingController();
  final RxInt selectedTab = 0.obs;

  @override
  void initState() {
    super.initState();
    _searchController.text = controller.searchText.value;
    _searchController.addListener(() {
      if (_searchController.text != controller.searchText.value) {
        controller.searchText.value = _searchController.text;
      }
    });
    ever(selectedTab, (int tabIndex) {
      final tabTypes = ['RM', 'Asset', 'Finished Goods', 'Service'];
      if (tabIndex < tabTypes.length) {
        final itemTypeName = tabTypes[tabIndex];
        final itemTypeId = controller.getItemTypeIdByName(itemTypeName);
        controller.setItemTypeFilter(itemTypeId);
      }
    });
  }

  void _onAddPressed() {
    final tabTypes = ['RM', 'Asset', 'Finished Goods', 'Service'];
    final type = tabTypes[selectedTab.value];
    if (type == 'RM') {
      Get.toNamed('/dashboard/store/items/buy/rm');
    } else if (type == 'Asset') {
      Get.toNamed('/dashboard/store/items/buy/asset');
    } else if (type == 'Service') {
      Get.toNamed('/dashboard/store/items/buy/service');
    } else if (type == 'Finished Goods') {
      Get.toNamed(
        '/dashboard/store/items/add',
        arguments: {'item_type': 'Finished Goods'},
      );
    }
  }

  String get _addButtonTooltip {
    final tabTypes = ['RM', 'Asset', 'Finished Goods', 'Service'];
    final type = tabTypes[selectedTab.value];
    switch (type) {
      case 'RM':
        return 'Add Raw Material';
      case 'Asset':
        return 'Add Asset';
      case 'Finished Goods':
        return 'Add Finished Goods';
      case 'Service':
        return 'Add Service';
      default:
        return 'Add Item';
    }
  }

  Future<void> _showItemViewDialog(Map<String, dynamic> item) async {
    controller.isViewingItem.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) {
        SnackbarUtils.showError(
          'Authentication token not found. Please login again.',
        );
        return;
      }
      final itemId = item['id']?.toString();
      final itemTypeId = controller.selectedItemTypeId.value ?? 54;
      final response = await http.get(
        Uri.parse(
          'https://1.sunshineiot.in/api/v2/store/item/$itemTypeId/$itemId',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final itemData = json.decode(response.body);
        final currentItemTypeId = controller.selectedItemTypeId.value;
        final itemTypeName = controller.getItemTypeNameById(
          currentItemTypeId ?? 0,
        );

        // ✅ Generate detailRows same as your existing code
        List<DataRow> detailRows;
        if (itemTypeName == 'Service') {
          detailRows = [
            _itemDetailRow('ID', itemData['id']),
            _itemDetailRow('Type ID', itemData['type_id']),
            _itemDetailRow('Type Name', itemData['type_name'] ?? 'N/A'),
            _itemDetailRow('Description', itemData['description'] ?? 'N/A'),
            _itemDetailRow('SAC Code', itemData['sac_code'] ?? 'N/A'),
            _itemDetailRow(
              'Created At',
              _formatDateTime(itemData['created_at']),
            ),
            _itemDetailRow('Created By', itemData['created_by_name'] ?? 'N/A'),
          ];
        } else if (itemTypeName == 'Finished Goods') {
          detailRows = [
            _itemDetailRow('ID', itemData['id']),
            _itemDetailRow('Description', itemData['description'] ?? 'N/A'),
            _itemDetailRow('Model No', itemData['model_no'] ?? 'N/A'),
            _itemDetailRow('HSN Code', itemData['hsn_code'] ?? 'N/A'),
            _itemDetailRow('SPQ', itemData['spq'] ?? 'N/A'),
            _itemDetailRow('MOQ', itemData['moq'] ?? 'N/A'),
            _itemDetailRow('Rate', itemData['rate'] ?? 'N/A'),
            _itemDetailRow(
              'Created At',
              _formatDateTime(itemData['created_at']),
            ),
            _itemDetailRow('Created By', itemData['created_by_name'] ?? 'N/A'),
          ];
        } else if (itemTypeName == 'Asset') {
          detailRows = [
            _itemDetailRow('ID', itemData['id']),
            _itemDetailRow('UIN', itemData['uin'] ?? 'N/A'),
            _itemDetailRow('Short Code', itemData['short_code'] ?? 'N/A'),
            _itemDetailRow('Description', itemData['description'] ?? 'N/A'),
            _itemDetailRow('Make', itemData['make'] ?? 'N/A'),
            _itemDetailRow('UOM', itemData['uom'] ?? 'N/A'),
            _itemDetailRow('Category', itemData['category'] ?? 'N/A'),
            _itemDetailRow('HSN Code', itemData['hsn_code'] ?? 'N/A'),
            _itemDetailRow(
              'Supplier Test Required',
              itemData['supplier_test_required'] == 1 ? 'Yes' : 'No',
            ),
            _itemDetailRow('IQC', itemData['iqc'] == 1 ? 'Yes' : 'No'),
            _itemDetailRow('GST Slab', itemData['gst_slab'] ?? 'N/A'),
            _itemDetailRow(
              'Created At',
              _formatDateTime(itemData['created_at']),
            ),
            _itemDetailRow('Created By', itemData['created_by_name'] ?? 'N/A'),
          ];
        } else {
          detailRows = [
            _itemDetailRow('ID', itemData['id']),
            _itemDetailRow('UIN', itemData['uin'] ?? 'N/A'),
            _itemDetailRow('Short Code', itemData['short_code'] ?? 'N/A'),
            _itemDetailRow('Description', itemData['description'] ?? 'N/A'),
            _itemDetailRow('Make', itemData['make'] ?? 'N/A'),
            _itemDetailRow('UOM', itemData['uom'] ?? 'N/A'),
            _itemDetailRow('Category', itemData['category'] ?? 'N/A'),
            _itemDetailRow('HSN Code', itemData['hsn_code'] ?? 'N/A'),
            _itemDetailRow('SPQ', itemData['spq'] ?? 'N/A'),
            _itemDetailRow('MOQ', itemData['moq'] ?? 'N/A'),
            _itemDetailRow(
              'Supplier Test Required',
              itemData['supplier_test_required'] == 1 ? 'Yes' : 'No',
            ),
            _itemDetailRow('IQC', itemData['iqc'] == 1 ? 'Yes' : 'No'),
            _itemDetailRow(
              'Sampling Percent',
              itemData['sampling_percent'] ?? 'N/A',
            ),
            _itemDetailRow('GST Slab', itemData['gst_slab'] ?? 'N/A'),
            _itemDetailRow(
              'Created At',
              _formatDateTime(itemData['created_at']),
            ),
            _itemDetailRow('Created By', itemData['created_by_name'] ?? 'N/A'),
          ];
        }

        showDialog(
          context: Get.context!,
          builder: (context) {
            return AlertDialog(
              title: Text(
                '${itemTypeName ?? 'Item'} Details',
                style: const TextStyle(color: Colors.black),
              ),
              backgroundColor: Colors.white,
              content: SingleChildScrollView(
                child: Container(
                  color: Colors.white,
                  child: Column(
                    children: detailRows.map((row) {
                      final field = row.cells[0].child as Text;
                      final value = row.cells[1].child as Text;
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.shade50,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                field.data!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 3,
                              child: Text(
                                value.data!,
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: [
                // ✅ Download PDF
                TextButton.icon(
                  icon: const Icon(Icons.download, color: Colors.blue),
                  label: const Text(
                    "Download",
                    style: TextStyle(color: Colors.black),
                  ),
                  onPressed: () async {
                    final pdf = pw.Document();
                    pdf.addPage(
                      pw.Page(
                        pageFormat: PdfPageFormat.a4,
                        build: (pw.Context context) {
                          return pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                "${itemTypeName ?? 'Item'} Details",
                                style: pw.TextStyle(
                                  fontSize: 20,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 16),
                              pw.Table.fromTextArray(
                                headers: ['Field', 'Value'],
                                data: detailRows.map((row) {
                                  final field =
                                      (row.cells[0].child as Text).data ?? '';
                                  final value =
                                      (row.cells[1].child as Text).data ?? '';
                                  return [field, value];
                                }).toList(),
                                headerStyle: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white,
                                ),
                                headerDecoration: const pw.BoxDecoration(
                                  color: PdfColors.blueGrey,
                                ),
                                cellStyle: const pw.TextStyle(fontSize: 12),
                                cellAlignment: pw.Alignment.centerLeft,
                                border: pw.TableBorder.all(
                                  color: PdfColors.grey,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    );

                    final bytes = await pdf.save();
                    final blob = html.Blob([bytes], 'application/pdf');
                    final url = html.Url.createObjectUrlFromBlob(blob);
                    final anchor = html.AnchorElement(href: url)
                      ..download = "${itemTypeName}_Details.pdf"
                      ..click();
                    html.Url.revokeObjectUrl(url);
                  },
                ),

                // ✅ Print PDF
                TextButton.icon(
                  icon: const Icon(Icons.print, color: Colors.orange),
                  label: const Text(
                    "Print",
                    style: TextStyle(color: Colors.black),
                  ),
                  onPressed: () async {
                    final pdf = pw.Document();
                    pdf.addPage(
                      pw.Page(
                        pageFormat: PdfPageFormat.a4,
                        build: (pw.Context context) {
                          return pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                "${itemTypeName ?? 'Item'} Details",
                                style: pw.TextStyle(
                                  fontSize: 20,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 16),
                              pw.Table.fromTextArray(
                                headers: ['Field', 'Value'],
                                data: detailRows.map((row) {
                                  final field =
                                      (row.cells[0].child as Text).data ?? '';
                                  final value =
                                      (row.cells[1].child as Text).data ?? '';
                                  return [field, value];
                                }).toList(),
                                headerStyle: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white,
                                ),
                                headerDecoration: const pw.BoxDecoration(
                                  color: PdfColors.blueGrey,
                                ),
                                cellStyle: const pw.TextStyle(fontSize: 12),
                                cellAlignment: pw.Alignment.centerLeft,
                                border: pw.TableBorder.all(
                                  color: PdfColors.grey,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    );

                    final bytes = await pdf.save();
                    final blob = html.Blob([bytes], 'application/pdf');
                    final url = html.Url.createObjectUrlFromBlob(blob);
                    html.window.open(url, "_blank");
                    html.Url.revokeObjectUrl(url);
                  },
                ),

                // ✅ Share (via Gmail)
                TextButton.icon(
                  icon: const Icon(Icons.share, color: Colors.green),
                  label: const Text(
                    "Share",
                    style: TextStyle(color: Colors.black),
                  ),
                  onPressed: () {
                    final body = detailRows
                        .map((row) {
                          final field = (row.cells[0].child as Text).data ?? '';
                          final value = (row.cells[1].child as Text).data ?? '';
                          return "$field: $value";
                        })
                        .join("\n");

                    final gmailUrl =
                        "https://mail.google.com/mail/?view=cm&fs=1&su=${Uri.encodeComponent("${itemTypeName ?? 'Item'} Details")}&body=${Uri.encodeComponent(body)}";
                    html.window.open(gmailUrl, "_blank");
                  },
                ),

                // ✅ Always show Close
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text(
                    'Close',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            );
          },
        );
      } else {
        SnackbarUtils.showError(
          'Failed to fetch item details: ${response.statusCode}',
        );
      }
    } catch (e) {
      SnackbarUtils.showError('Error: ${e.toString()}');
    } finally {
      controller.isViewingItem.value = false;
    }
  }

  DataRow _itemDetailRow(String label, dynamic value) {
    return DataRow(
      cells: [
        DataCell(
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        DataCell(
          Text(
            value?.toString() ?? '',
            style: const TextStyle(color: Colors.black),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return '';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Material(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              // Tab bar for item types
              ItemTypeTabBar(
                selectedIndex: selectedTab.value,
                onTabSelected: (index) => selectedTab.value = index,
              ),
              // Row of filter/search/action controls
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Title
                    Text(
                      selectedTab.value == 0
                          ? 'Raw Material List'
                          : selectedTab.value == 1
                          ? 'Asset List'
                          : selectedTab.value == 2
                          ? 'Finished Goods List'
                          : 'Service List',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.filter_list, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                'Filter: ${controller.selectedItemTypeId.value != null ? controller.getItemTypeNameById(controller.selectedItemTypeId.value!) ?? 'Unknown' : 'All'}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (controller.selectedItemTypeId.value != null)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: controller.clearFilters,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 220,
                          height: 33,
                          child: TextField(
                            controller: _searchController,
                            autofocus: false,
                            style: const TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 12,
                              ),
                              hintText: 'Search all columns...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        _searchController.clear();
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: _addButtonTooltip,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Add'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _onAddPressed,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // List/table view of items and pagination (scrollable)
              Expanded(
                child: controller.isLoading.value
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              switchInCurve: Curves.easeIn,
                              switchOutCurve: Curves.easeOut,
                              child: ItemTable(
                                key: ValueKey(selectedTab.value),
                                items: controller.filteredItems,
                                controller: controller,
                                onViewItem: _showItemViewDialog,
                              ),
                            ),
                            if (!controller.isLoading.value &&
                                controller.filteredItems.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Text('Items per page: '),
                                        DropdownButton<int>(
                                          value: controller.limit.value,
                                          items: [10, 20, 50, 100]
                                              .map(
                                                (limit) => DropdownMenuItem(
                                                  value: limit,
                                                  child: Text(limit.toString()),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (newLimit) {
                                            if (newLimit != null) {
                                              controller.onLimitChanged(
                                                newLimit,
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Showing ${controller.filteredItems.length} of ${controller.items.length} items',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.first_page),
                                          onPressed: null,
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.chevron_left),
                                          onPressed: null,
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade300,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            '1',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.chevron_right),
                                          onPressed: null,
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.last_page),
                                          onPressed: null,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class ItemsScreen extends StatelessWidget {
  const ItemsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const ItemsDashboardView();
  }
}
