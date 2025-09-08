import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../controllers/options_controller.dart';
import '../../../utils/snackbar_message.dart';

class TransferChallan extends StatefulWidget {
  const TransferChallan({super.key});

  @override
  State<TransferChallan> createState() => _TransferChallanState();
}

class _TransferChallanState extends State<TransferChallan> {
  final OptionsController optionsController = Get.find();

  int? fromStoreId;
  int? toStoreId;
  final TextEditingController remarksController = TextEditingController();

  List<Map<String, dynamic>> transferItems = [];
  List<Map<String, dynamic>> itemOptions = []; // Cache for item options
  bool isLoadingItems = true; // Add loading state
  String? authToken; // Store the authentication token

  // Store row-specific item options
  Map<int, List<Map<String, dynamic>>> rowItemOptions = {};

  @override
  void initState() {
    super.initState();
    _initializeToken();
  }

  // Get token from SharedPreferences and load initial items
  Future<void> _initializeToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      authToken = prefs.getString('jwt_token');
      if (authToken == null) {
        SnackbarUtils.showError('Please login to continue.');
        setState(() {
          isLoadingItems = false;
        });
        return;
      }

      // Initialize first row after getting token
      await _initializeFirstRow();
    } catch (e) {
      SnackbarUtils.showError('Error loading authentication token');
      setState(() {
        isLoadingItems = false;
      });
    }
  }

  Future<void> _initializeFirstRow() async {
    // Get RM as default item type
    final rmOption = optionsController.itemTypeOptions.firstWhereOrNull(
      (o) => o.optionName == 'RM',
    );
    final defaultItemTypeId = rmOption?.optionId;

    setState(() {
      transferItems.add({
        'item_id': null,
        'item_name': null,
        'item_type_id': defaultItemTypeId,
        'qty': null,
        'available_qty': null,
        'row_item_type_id':
            defaultItemTypeId, // Individual row item type defaults to RM
      });
    });

    // Load initial items for the first row if it has a default item type
    if (defaultItemTypeId != null) {
      final rowItems = await loadItemOptionsForRow(0, defaultItemTypeId);
      setState(() {
        rowItemOptions[0] = rowItems;
        isLoadingItems = false;
      });
    } else {
      setState(() {
        isLoadingItems = false;
      });
    }
  }

  // Get headers with token for API calls
  Map<String, String> _getHeaders() {
    final headers = {'Content-Type': 'application/json'};

    if (authToken != null && authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    return headers;
  }

  // Load items for a specific row based on its item type - with dynamic API call
  Future<List<Map<String, dynamic>>> loadItemOptionsForRow(
    int rowIndex,
    int? itemTypeId,
  ) async {
    if (authToken == null) {
      SnackbarUtils.showError('Please login to continue.');
      return [];
    }

    try {
      // Always make API call with the specific item_type_id for this row
      final itemTypeFilter = itemTypeId?.toString() ?? '';
      final url = Uri.parse(
        'https://1.sunshineiot.in/api/v2/store/stock/all?page=1&limit=1000&search=&item_type_id=$itemTypeFilter',
      );
      final response = await http.get(url, headers: _getHeaders());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> stockItems = data['data'] ?? [];

        final Map<int, Map<String, dynamic>> uniqueItems = {};

        for (final item in stockItems) {
          final itemId = item['item_id'];
          final itemName = item['description'] ?? 'Item $itemId';
          final itemTypeId = item['item_type_id'];

          if (itemId != null && !uniqueItems.containsKey(itemId)) {
            uniqueItems[itemId] = {
              'item_id': itemId,
              'description': itemName,
              'item_type_id': itemTypeId,
            };
          }
        }

        final rowItems = uniqueItems.values.toList();
        return rowItems;
      } else if (response.statusCode == 401) {
        SnackbarUtils.showError('Please login to continue.');
        return [];
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  Future<void> fetchItemStock(int itemId, int storeId, int rowIndex) async {
    if (authToken == null) {
      SnackbarUtils.showError('Please login to continue.');
      return;
    }

    // Validate rowIndex
    if (rowIndex >= transferItems.length) {
      return;
    }

    // Get the item_type_id from the specific row for dynamic API call
    final rowItemTypeId = transferItems[rowIndex]['row_item_type_id'];
    final itemTypeFilter = rowItemTypeId?.toString() ?? '';

    final url = Uri.parse(
      'https://1.sunshineiot.in/api/v2/store/stock/all?page=1&limit=20&search=&item_type_id=$itemTypeFilter',
    );
    try {
      final response = await http.get(url, headers: _getHeaders());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> items = data['data'] ?? [];

        final itemData = items.firstWhereOrNull(
          (item) => item['item_id'] == itemId,
        );
        if (itemData != null) {
          final storeData = (itemData['stores'] as List<dynamic>?)
              ?.firstWhereOrNull((store) => store['store_id'] == storeId);

          if (mounted) {
            setState(() {
              transferItems[rowIndex]['item_type_id'] =
                  itemData['item_type_id'];
              transferItems[rowIndex]['available_qty'] = storeData != null
                  ? (storeData['qty'] ?? 0)
                  : 0;
              transferItems[rowIndex]['qty'] = null; // Don't auto-fill quantity
            });
          }
        } else {
          if (mounted) {
            setState(() {
              transferItems[rowIndex]['available_qty'] = 0;
              transferItems[rowIndex]['qty'] = null;
            });
          }
        }
      } else if (response.statusCode == 401) {
        SnackbarUtils.showError('Please login to continue.');
      } else {
        SnackbarUtils.showError('Failed to load stock.');
      }
    } catch (e) {
      SnackbarUtils.showError('Error: $e');
    }
  }

  void addNewRow() async {
    // Get RM as default item type for new rows
    final rmOption = optionsController.itemTypeOptions.firstWhereOrNull(
      (o) => o.optionName == 'RM',
    );
    final defaultItemTypeId = rmOption?.optionId;

    final newRowIndex = transferItems.length;

    setState(() {
      transferItems.add({
        'item_id': null,
        'item_name': null,
        'item_type_id': defaultItemTypeId,
        'qty': null,
        'available_qty': null,
        'row_item_type_id': defaultItemTypeId, // Default to RM
      });
      // Initialize a placeholder for new row's options
      rowItemOptions[newRowIndex] = [];
    });

    // Load items for the new row with RM as default
    if (defaultItemTypeId != null) {
      try {
        final rowItems = await loadItemOptionsForRow(
          newRowIndex,
          defaultItemTypeId,
        );
        if (mounted) {
          setState(() {
            rowItemOptions[newRowIndex] = rowItems;
          });
        }
      } catch (e) {
        print('Error loading items for new row: $e');
      }
    }
  }

  void removeRow(int index) {
    if (transferItems.length > 1) {
      setState(() {
        transferItems.removeAt(index);
        // Remove cached items for this row
        rowItemOptions.remove(index);
        // Reindex remaining row options
        final updatedRowOptions = <int, List<Map<String, dynamic>>>{};
        rowItemOptions.forEach((key, value) {
          if (key > index) {
            updatedRowOptions[key - 1] = value;
          } else if (key < index) {
            updatedRowOptions[key] = value;
          }
        });
        rowItemOptions = updatedRowOptions;
      });
    }
  }

  Future<void> submitTransfer() async {
    if (authToken == null) {
      SnackbarUtils.showError('Please login to continue.');
      return;
    }

    if (fromStoreId == null || toStoreId == null) {
      SnackbarUtils.showError('Please select both From Store and To Store');
      return;
    }
    if (transferItems.isEmpty) {
      SnackbarUtils.showError('Please add at least one item');
      return;
    }

    for (int i = 0; i < transferItems.length; i++) {
      final item = transferItems[i];
      if (item['item_id'] == null) {
        SnackbarUtils.showError('Please select item for row ${i + 1}');
        return;
      }
      if (item['qty'] == null || item['qty'] <= 0) {
        SnackbarUtils.showError('Please enter valid quantity for row ${i + 1}');
        return;
      }
      if (item['qty'] > (item['available_qty'] ?? 0)) {
        SnackbarUtils.showError(
          'Transfer quantity cannot exceed available quantity for row ${i + 1}',
        );
        return;
      }
    }

    final body = {
      "from_store_id": fromStoreId,
      "to_store_id": toStoreId,
      "remarks": remarksController.text,
      "transfer_items": transferItems
          .map(
            (e) => {
              "item_id": e['item_id'],
              "item_type_id": e['item_type_id'],
              "qty": e['qty'],
            },
          )
          .toList(),
    };

    final url = Uri.parse(
      'https://1.sunshineiot.in/api/v2/store/stock/transfer',
    );
    try {
      final response = await http.post(
        url,
        headers: _getHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        SnackbarUtils.showSuccess(
          'Transfer Successful! Challan: ${data['challan_no']}',
        );

        // Reset form state
        await _resetForm();

        // Navigate to transfer log page after successful submission
        Get.offNamed('/dashboard/store/transfer_log');
      } else if (response.statusCode == 401) {
        SnackbarUtils.showError('Please login to continue.');
      } else {
        try {
          final errorData = jsonDecode(response.body);
          SnackbarUtils.showError(
            'Transfer Failed: ${errorData['message'] ?? 'Unknown error'}',
          );
        } catch (e) {
          SnackbarUtils.showError('Transfer Failed.');
        }
      }
    } catch (e) {
      SnackbarUtils.showError('Error: $e');
    }
  }

  Future<void> _resetForm() async {
    final rmOption = optionsController.itemTypeOptions.firstWhereOrNull(
      (o) => o.optionName == 'RM',
    );
    final defaultItemTypeId = rmOption?.optionId;

    setState(() {
      transferItems.clear();
      transferItems.add({
        'item_id': null,
        'item_name': null,
        'item_type_id': defaultItemTypeId,
        'qty': null,
        'available_qty': null,
        'row_item_type_id': defaultItemTypeId, // Reset to RM default
      });
      remarksController.clear();
      fromStoreId = null;
      toStoreId = null;
      rowItemOptions.clear(); // Clear cached row items
    });

    // Load items for the reset row with RM default
    if (defaultItemTypeId != null) {
      try {
        final rowItems = await loadItemOptionsForRow(0, defaultItemTypeId);
        if (mounted) {
          setState(() {
            rowItemOptions[0] = rowItems;
          });
        }
      } catch (e) {
        print('Error resetting form: $e');
      }
    }
  }

  String getStoreName(int? storeId) {
    if (storeId == null) return '';
    final option = optionsController.storeOptions.firstWhereOrNull(
      (opt) => opt.optionId == storeId,
    );
    return option?.optionName ?? 'Unknown Store';
  }

  String getItemName(int? itemId) {
    if (itemId == null) return '';
    // Search across all row item options to find the item
    for (var rowItems in rowItemOptions.values) {
      final item = rowItems.firstWhereOrNull(
        (item) => item['item_id'] == itemId,
      );
      if (item != null) {
        return item['description']?.toString() ?? 'Unknown Item';
      }
    }
    return 'Unknown Item';
  }

  String getItemTypeName(int? itemTypeId) {
    if (itemTypeId == null) return '';
    final option = optionsController.itemTypeOptions.firstWhereOrNull(
      (opt) => opt.optionId == itemTypeId,
    );
    return option?.optionName ?? 'Unknown Type';
  }

  // Get filtered item options based on row's item type
  List<Map<String, dynamic>> getFilteredItemOptions(
    int rowIndex,
    int? rowItemTypeId,
  ) {
    if (rowItemTypeId == null) return [];
    // Return row-specific items if available, otherwise an empty list
    return rowItemOptions[rowIndex] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer Stock'),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        foregroundColor: const Color.fromARGB(255, 0, 0, 0),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Store From Dropdown
                        Expanded(
                          child: Obx(() {
                            final storeOptions = optionsController.storeOptions;
                            return DropdownButtonFormField<int>(
                              decoration: const InputDecoration(
                                labelText: 'From Store *',
                                border: OutlineInputBorder(),
                              ),
                              value: fromStoreId,
                              items: storeOptions
                                  .map(
                                    (opt) => DropdownMenuItem<int>(
                                      value: opt.optionId,
                                      child: Text(opt.optionName),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                setState(() {
                                  fromStoreId = val;
                                  // Reset available quantities when from store changes
                                  for (var item in transferItems) {
                                    item['available_qty'] = null;
                                    item['qty'] = null;
                                  }
                                });
                                // Re-fetch stock for all selected items
                                for (int i = 0; i < transferItems.length; i++) {
                                  if (transferItems[i]['item_id'] != null &&
                                      val != null) {
                                    fetchItemStock(
                                      transferItems[i]['item_id'],
                                      val,
                                      i,
                                    );
                                  }
                                }
                              },
                            );
                          }),
                        ),
                        const SizedBox(width: 16),
                        // Store To Dropdown
                        Expanded(
                          child: Obx(() {
                            final storeOptions = optionsController.storeOptions
                                .where((opt) => opt.optionId != fromStoreId)
                                .toList();
                            return DropdownButtonFormField<int>(
                              decoration: const InputDecoration(
                                labelText: 'To Store *',
                                border: OutlineInputBorder(),
                              ),
                              value: toStoreId,
                              items: storeOptions
                                  .map(
                                    (opt) => DropdownMenuItem<int>(
                                      value: opt.optionId,
                                      child: Text(opt.optionName),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                setState(() {
                                  toStoreId = val;
                                });
                              },
                            );
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Remarks
                    TextFormField(
                      controller: remarksController,
                      decoration: const InputDecoration(
                        labelText: 'Remarks',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Items Section in Table
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Transfer Items',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (isLoadingItems)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Show loading message if items are still loading
                    if (isLoadingItems)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Text('Loading items...'),
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            Colors.grey[200],
                          ),
                          columns: const [
                            DataColumn(label: Text('Item Type')),
                            DataColumn(label: Text('Item *')),
                            DataColumn(label: Text('Available Qty')),
                            DataColumn(label: Text('Transfer Qty *')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: transferItems.asMap().entries.map((entry) {
                            int index = entry.key;
                            Map<String, dynamic> row = entry.value;
                            return DataRow(
                              cells: [
                                // Item Type Dropdown for each row
                                DataCell(
                                  SizedBox(
                                    width: 150,
                                    child: Obx(() {
                                      final itemTypeOptions =
                                          optionsController.itemTypeOptions;
                                      return DropdownButtonFormField<int>(
                                        value: row['row_item_type_id'],
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                          hintText: 'Type',
                                        ),
                                        items: itemTypeOptions
                                            .map(
                                              (opt) => DropdownMenuItem<int>(
                                                value: opt.optionId,
                                                child: Text(
                                                  opt.optionName,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (val) async {
                                          setState(() {
                                            row['row_item_type_id'] = val;
                                            row['item_type_id'] = val;
                                            row['item_id'] = null;
                                            row['item_name'] = null;
                                            row['available_qty'] = null;
                                            row['qty'] = null;
                                          });

                                          // Load items for this specific row with dynamic API call
                                          if (val != null) {
                                            try {
                                              final rowItems =
                                                  await loadItemOptionsForRow(
                                                    index,
                                                    val,
                                                  );
                                              if (mounted) {
                                                setState(() {
                                                  rowItemOptions[index] =
                                                      rowItems;
                                                });
                                              }
                                            } catch (e) {
                                              print(
                                                'Error loading items for row $index: $e',
                                              );
                                            }
                                          } else {
                                            setState(() {
                                              rowItemOptions.remove(index);
                                            });
                                          }
                                        },
                                      );
                                    }),
                                  ),
                                ),

                                // Item Dropdown
                                DataCell(
                                  SizedBox(
                                    width: 300,
                                    child: Builder(
                                      builder: (context) {
                                        final filteredItems =
                                            getFilteredItemOptions(
                                              index,
                                              row['row_item_type_id'],
                                            );
                                        return DropdownButtonFormField<int>(
                                          value: row['item_id'],
                                          decoration: const InputDecoration(
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                            hintText: 'Select Item',
                                          ),
                                          items: filteredItems.isNotEmpty
                                              ? filteredItems
                                                    .map(
                                                      (
                                                        item,
                                                      ) => DropdownMenuItem<int>(
                                                        value: item['item_id'],
                                                        child: Text(
                                                          item['description']
                                                                  ?.toString() ??
                                                              'Unknown',
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    )
                                                    .toList()
                                              : [
                                                  const DropdownMenuItem<int>(
                                                    value: null,
                                                    child: Text(
                                                      'No items available',
                                                    ),
                                                  ),
                                                ],
                                          onChanged: filteredItems.isNotEmpty
                                              ? (val) {
                                                  setState(() {
                                                    row['item_id'] = val;
                                                    row['item_name'] =
                                                        getItemName(val);
                                                    row['available_qty'] = null;
                                                    row['qty'] = null;
                                                  });
                                                  if (val != null &&
                                                      fromStoreId != null) {
                                                    fetchItemStock(
                                                      val,
                                                      fromStoreId!,
                                                      index,
                                                    );
                                                  }
                                                }
                                              : null,
                                        );
                                      },
                                    ),
                                  ),
                                ),

                                // Available Qty
                                DataCell(
                                  Text(
                                    row['available_qty']?.toString() ?? '',
                                    style: TextStyle(
                                      color: (row['available_qty'] ?? 0) > 0
                                          ? Colors.green[700]
                                          : Colors.red[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                                // Transfer Qty
                                DataCell(
                                  SizedBox(
                                    width: 100,
                                    child: TextFormField(
                                      key: ValueKey(
                                        'qty_${index}_${row['item_id']}',
                                      ), // Add unique key
                                      initialValue:
                                          row['qty']?.toString() ?? '',
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        hintText: '0',
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (val) {
                                        setState(() {
                                          row['qty'] = int.tryParse(val) ?? 0;
                                        });
                                      },
                                    ),
                                  ),
                                ),

                                // Actions
                                DataCell(
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: transferItems.length > 1
                                        ? () => removeRow(index)
                                        : null,
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),

                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: addNewRow,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Item'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: submitTransfer,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Submit Transfer',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    remarksController.dispose();
    super.dispose();
  }
}
