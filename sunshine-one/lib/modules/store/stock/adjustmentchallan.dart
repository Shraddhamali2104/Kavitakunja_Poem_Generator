import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../controllers/options_controller.dart';
import '../../../utils/snackbar_message.dart';

class AdjustmentChallan extends StatefulWidget {
  const AdjustmentChallan({super.key});

  @override
  State<AdjustmentChallan> createState() => _AdjustmentChallanState();
}

class _AdjustmentChallanState extends State<AdjustmentChallan> {
  final OptionsController optionsController = Get.find();

  int? storeId;
  final TextEditingController remarksController = TextEditingController();

  List<Map<String, dynamic>> adjustmentItems = [];
  bool isLoadingItems = true;
  String? authToken;
  Map<int, List<Map<String, dynamic>>> rowItemOptions = {};

  @override
  void initState() {
    super.initState();

    // Get RM as default item type, which is typically ID 54.
    final rmOption = optionsController.itemTypeOptions.firstWhereOrNull(
      (o) => o.optionName == 'RM',
    );
    final defaultItemTypeId = rmOption?.optionId;

    adjustmentItems.add({
      'item_id': null,
      'item_name': null,
      'item_type_id': defaultItemTypeId,
      'qty': null,
      'available_qty': null,
      'adjustment_type': 'increase',
      'row_item_type_id': defaultItemTypeId,
    });

    // Ensure rowItemOptions is initialized with a placeholder for the first row
    if (defaultItemTypeId != null) {
      rowItemOptions[0] = [];
    }

    _initializeTokenAndItems();
  }

  // Combines token loading and initial item fetching
  Future<void> _initializeTokenAndItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      authToken = prefs.getString('jwt_token');
      if (authToken == null) {
        SnackbarUtils.showError('Please login to continue.');
        setState(() => isLoadingItems = false);
        return;
      }

      if (adjustmentItems.isNotEmpty &&
          adjustmentItems[0]['row_item_type_id'] != null) {
        final rowItems = await loadItemOptionsForRow(
          0,
          adjustmentItems[0]['row_item_type_id'],
        );
        setState(() {
          rowItemOptions[0] = rowItems;
          isLoadingItems = false;
        });
      } else {
        setState(() => isLoadingItems = false);
      }
    } catch (e) {
      SnackbarUtils.showError('Error loading authentication token');
      setState(() => isLoadingItems = false);
    }
  }

  Map<String, String> _getHeaders() {
    final headers = {'Content-Type': 'application/json'};
    if (authToken != null && authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    return headers;
  }

  Future<List<Map<String, dynamic>>> loadItemOptionsForRow(
    int rowIndex,
    int? itemTypeId,
  ) async {
    if (authToken == null) {
      SnackbarUtils.showError('Please login to continue.');
      return [];
    }
    try {
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
        return uniqueItems.values.toList();
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
    final rowItemTypeId = adjustmentItems[rowIndex]['row_item_type_id'];
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
          final storeData = (itemData['stores'] as List<dynamic>)
              .firstWhereOrNull((store) => store['store_id'] == storeId);
          setState(() {
            adjustmentItems[rowIndex]['item_type_id'] =
                itemData['item_type_id'];
            adjustmentItems[rowIndex]['available_qty'] = storeData != null
                ? storeData['qty']
                : 0;
            adjustmentItems[rowIndex]['qty'] = null;
          });
        } else {
          setState(() {
            adjustmentItems[rowIndex]['available_qty'] = 0;
            adjustmentItems[rowIndex]['qty'] = null;
          });
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

  void addNewRow() {
    final rmOption = optionsController.itemTypeOptions.firstWhereOrNull(
      (o) => o.optionName == 'RM',
    );
    final defaultItemTypeId = rmOption?.optionId;
    final newRowIndex = adjustmentItems.length;
    setState(() {
      adjustmentItems.add({
        'item_id': null,
        'item_name': null,
        'item_type_id': defaultItemTypeId,
        'qty': null,
        'available_qty': null,
        'adjustment_type': 'increase',
        'row_item_type_id': defaultItemTypeId,
      });
      rowItemOptions[newRowIndex] = [];
    });
    if (defaultItemTypeId != null) {
      loadItemOptionsForRow(newRowIndex, defaultItemTypeId).then((rowItems) {
        setState(() {
          rowItemOptions[newRowIndex] = rowItems;
        });
      });
    }
  }

  void removeRow(int index) {
    if (adjustmentItems.length > 1) {
      setState(() {
        adjustmentItems.removeAt(index);
        rowItemOptions.remove(index);
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

  Future<void> submitAdjustment() async {
    if (authToken == null) {
      SnackbarUtils.showError('Please login to continue.');
      return;
    }
    if (storeId == null) {
      SnackbarUtils.showError('Please select a store');
      return;
    }
    if (adjustmentItems.isEmpty) {
      SnackbarUtils.showError('Please add at least one item');
      return;
    }
    for (int i = 0; i < adjustmentItems.length; i++) {
      final item = adjustmentItems[i];
      if (item['item_id'] == null) {
        SnackbarUtils.showError('Please select item for row ${i + 1}');
        return;
      }
      if (item['qty'] == null || item['qty'] <= 0) {
        SnackbarUtils.showError('Please enter valid quantity for row ${i + 1}');
        return;
      }
      if (item['adjustment_type'] == 'decrease' &&
          item['qty'] > (item['available_qty'] ?? 0)) {
        SnackbarUtils.showError(
          'Decrease quantity cannot exceed available quantity for row ${i + 1}',
        );
        return;
      }
    }

    final body = {
      "store_id": storeId,
      "remarks": remarksController.text,
      "adjustment_items": adjustmentItems
          .map(
            (e) => {
              "item_id": e['item_id'],
              "item_type_id": e['item_type_id'],
              "qty": e['qty'],
              "adjustment_type": e['adjustment_type'],
            },
          )
          .toList(),
    };

    final url = Uri.parse('https://1.sunshineiot.in/api/v2/store/stock/adjust');
    try {
      final response = await http.post(
        url,
        headers: _getHeaders(),
        body: jsonEncode(body),
      );
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        String? challanNo;
        if (data['challan_no'] != null) {
          challanNo = data['challan_no'].toString();
        } else if (data['data'] != null && data['data']['challan_no'] != null) {
          challanNo = data['data']['challan_no'].toString();
        } else if (data['id'] != null) {
          challanNo = data['id'].toString();
        }
        if (challanNo != null && challanNo.isNotEmpty && challanNo != 'null') {
          SnackbarUtils.showSuccess(
            'Adjustment Successful! Challan: $challanNo',
          );
        } else {
          SnackbarUtils.showSuccess('Adjustment Successful!');
        }
        final rmOption = optionsController.itemTypeOptions.firstWhereOrNull(
          (o) => o.optionName == 'RM',
        );
        final defaultItemTypeId = rmOption?.optionId;
        setState(() {
          adjustmentItems.clear();
          adjustmentItems.add({
            'item_id': null,
            'item_name': null,
            'item_type_id': defaultItemTypeId,
            'qty': null,
            'available_qty': null,
            'adjustment_type': 'increase',
            'row_item_type_id': defaultItemTypeId,
          });
          remarksController.clear();
          storeId = null;
          rowItemOptions.clear();
        });
        if (defaultItemTypeId != null) {
          loadItemOptionsForRow(0, defaultItemTypeId).then((rowItems) {
            setState(() {
              rowItemOptions[0] = rowItems;
            });
          });
        }
        Get.offNamed('/dashboard/store/adjustment_log');
      } else if (response.statusCode == 401) {
        SnackbarUtils.showError('Please login to continue.');
      } else {
        try {
          final errorData = jsonDecode(response.body);
          SnackbarUtils.showError(
            'Adjustment Failed: ${errorData['message'] ?? 'Unknown error'}',
          );
        } catch (e) {
          SnackbarUtils.showError('Adjustment Failed.');
        }
      }
    } catch (e) {
      SnackbarUtils.showError('Error: $e');
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
    for (var rowItems in rowItemOptions.values) {
      final item = rowItems.firstWhereOrNull(
        (item) => item['item_id'] == itemId,
      );
      if (item != null) {
        return item['description'] ?? 'Unknown Item';
      }
    }
    return 'Unknown Item';
  }

  List<Map<String, dynamic>> getFilteredItemOptions(
    int rowIndex,
    int? rowItemTypeId,
  ) {
    if (rowItemTypeId == null) return [];
    return rowItemOptions[rowIndex] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Adjustment'),
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
                        Expanded(
                          child: Obx(
                            () => DropdownButtonFormField<int>(
                              decoration: const InputDecoration(
                                labelText: 'Store *',
                                border: OutlineInputBorder(),
                              ),
                              value: storeId,
                              items: optionsController.storeOptions
                                  .map(
                                    (opt) => DropdownMenuItem<int>(
                                      value: opt.optionId,
                                      child: Text(opt.optionName),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                setState(() {
                                  storeId = val;
                                  for (var item in adjustmentItems) {
                                    item['available_qty'] = null;
                                    item['qty'] = null;
                                  }
                                });
                                for (
                                  int i = 0;
                                  i < adjustmentItems.length;
                                  i++
                                ) {
                                  if (adjustmentItems[i]['item_id'] != null &&
                                      val != null) {
                                    fetchItemStock(
                                      adjustmentItems[i]['item_id'],
                                      val,
                                      i,
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                    Text(
                      'Adjustment Items',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (isLoadingItems)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Text('Loading items...'),
                        ),
                      )
                    else if (rowItemOptions.isEmpty ||
                        rowItemOptions[0]?.isEmpty == true)
                      Center(
                        child: Column(
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Text(
                                'No items available for default type (RM)',
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _initializeTokenAndItems(),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              Colors.grey[200],
                            ),
                            columnSpacing: 12,
                            columns: [
                              DataColumn(
                                label: Expanded(child: Text('Item Type')),
                              ),
                              DataColumn(
                                label: Expanded(child: Text('Item *')),
                              ),
                              DataColumn(
                                label: Expanded(child: Text('Current Qty')),
                              ),
                              DataColumn(
                                label: Expanded(child: Text('Type *')),
                              ),
                              DataColumn(label: Expanded(child: Text('Qty *'))),
                              DataColumn(
                                label: Expanded(child: Text('Actions')),
                              ),
                            ],
                            rows: adjustmentItems.asMap().entries.map((entry) {
                              int index = entry.key;
                              Map<String, dynamic> row = entry.value;
                              return DataRow(
                                cells: [
                                  DataCell(
                                    DropdownButtonFormField<int>(
                                      value: row['row_item_type_id'],
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        hintText: 'Type',
                                      ),
                                      items: optionsController.itemTypeOptions
                                          .map(
                                            (opt) => DropdownMenuItem<int>(
                                              value: opt.optionId,
                                              child: Text(
                                                opt.optionName,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (val) async {
                                        setState(() {
                                          row['row_item_type_id'] = val;
                                          row['item_type_id'] = val;
                                          row['item_id'] = null;
                                          row['available_qty'] = null;
                                          row['qty'] = null;
                                        });
                                        if (val != null) {
                                          final rowItems =
                                              await loadItemOptionsForRow(
                                                index,
                                                val,
                                              );
                                          setState(
                                            () => rowItemOptions[index] =
                                                rowItems,
                                          );
                                        } else {
                                          setState(
                                            () => rowItemOptions.remove(index),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  DataCell(
                                    DropdownButtonFormField<int>(
                                      value: row['item_id'],
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        hintText: 'Select Item',
                                      ),
                                      items:
                                          getFilteredItemOptions(
                                            index,
                                            row['row_item_type_id'],
                                          ).isNotEmpty
                                          ? getFilteredItemOptions(
                                                  index,
                                                  row['row_item_type_id'],
                                                )
                                                .map(
                                                  (
                                                    item,
                                                  ) => DropdownMenuItem<int>(
                                                    value: item['item_id'],
                                                    child: Text(
                                                      item['description']
                                                              ?.toString() ??
                                                          'Unknown',
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                )
                                                .toList()
                                          : [],
                                      onChanged:
                                          getFilteredItemOptions(
                                            index,
                                            row['row_item_type_id'],
                                          ).isNotEmpty
                                          ? (val) {
                                              setState(() {
                                                row['item_id'] = val;
                                                row['available_qty'] = null;
                                                row['qty'] = null;
                                              });
                                              if (val != null &&
                                                  storeId != null) {
                                                fetchItemStock(
                                                  val,
                                                  storeId!,
                                                  index,
                                                );
                                              }
                                            }
                                          : null,
                                    ),
                                  ),
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
                                  DataCell(
                                    DropdownButtonFormField<String>(
                                      value: row['adjustment_type'],
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      items: const [
                                        DropdownMenuItem<String>(
                                          value: 'increase',
                                          child: Text('Increase'),
                                        ),
                                        DropdownMenuItem<String>(
                                          value: 'decrease',
                                          child: Text('Decrease'),
                                        ),
                                      ],
                                      onChanged: (val) => setState(
                                        () => row['adjustment_type'] = val,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    TextFormField(
                                      initialValue:
                                          row['qty']?.toString() ?? '',
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        hintText: '0',
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (val) => setState(
                                        () =>
                                            row['qty'] = int.tryParse(val) ?? 0,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: adjustmentItems.length > 1
                                          ? () => removeRow(index)
                                          : null,
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          );
                        },
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
                onPressed: submitAdjustment,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Submit Adjustment',
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
