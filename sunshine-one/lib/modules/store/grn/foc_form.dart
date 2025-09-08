import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:myoffice_sunshine/utils/snackbar_message.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../../controllers/options_controller.dart';
import '../../../models/option_model.dart';

class FocForm extends StatefulWidget {
  const FocForm({super.key});

  @override
  State<FocForm> createState() => _FocFormState();
}

class _FocFormState extends State<FocForm> {
  final _formKey = GlobalKey<FormState>();
  double totalCalculatedAmount = 0.0;
  final billingAmountController = TextEditingController();

  // Initialize options controller
  late final OptionsController optionsController;

  // GRN status will be set to "Drafted" by default
  String selectedGrnStatus = 'Drafted';

  final grnNoController = TextEditingController();
  final grnDateController = TextEditingController(
    text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
  );
  final inwardBnController = TextEditingController();
  final monthOfInvoiceController = TextEditingController(
    text: DateFormat('MMMM, yyyy').format(DateTime.now()),
  );
  final invoiceNoController = TextEditingController();
  final invoiceDateController = TextEditingController();
  final poNoController = TextEditingController();
  final vendorChallanController = TextEditingController();
  final returnDateController = TextEditingController();
  final repairStatusController = TextEditingController();
  final warrantyPeriodController = TextEditingController();
  final remarksController = TextEditingController();
  final storeIdController = TextEditingController();

  List<Map<String, dynamic>> itemEntries = [
    {
      'item_id': null,
      'item_type_id': 54, // Default to RM
      'poQty': '',
      'actualQty': '',
      'rate': '',
      'invoiceTotal': 0.0,
      'poTotal': '',
    },
  ];

  List<Map<String, dynamic>> availableItemList = [];
  List<Map<String, dynamic>> supplierList = [];
  int? selectedSupplierId;
  String? selectedSupplierName;
  List<Map<String, dynamic>> grnTypeList = [];
  int? selectedGrnTypeId;
  int? selectedStoreId; // Default store ID

  bool isLoading = false;
  bool isSubmitting = false; // For tracking submission progress
  DateTime? selectedGrnDate;
  DateTime? selectedInvoiceDate;
  int? editingGrnId; // If set, we are in edit mode
  bool isEditMode = false;

  @override
  void initState() {
    super.initState();
    try {
      optionsController = Get.put(OptionsController());
    } catch (e) {
      // Fallback if options controller fails
      log('Error initializing options controller: $e');
    }
    // fetchAvailableItems();
    fetchSuppliers();
    fetchGrnTypes();

    // GRN status is set to "Drafted" by default

    try {
      selectedGrnDate = DateFormat('yyyy-MM-dd').parse(grnDateController.text);
    } catch (_) {
      selectedGrnDate = DateTime.now();
    }

    // Fetch items for default RM type on startup and ensure options are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Ensure options are loaded
      try {
        await optionsController.fetchOptions();
      } catch (e) {
        log('Error fetching options in post frame callback: $e');
      }
      
      // Detect edit mode from route/arguments
      final paramsId = int.tryParse(Get.parameters['id'] ?? '');
      final args = Get.arguments is Map ? (Get.arguments as Map) : null;
      final argId = args != null ? (args['id'] as int?) : null;
      editingGrnId = paramsId ?? argId;
      isEditMode = editingGrnId != null || (args != null && args['isEdit'] == true);

      if (isEditMode && editingGrnId != null) {
        await _loadGrnForEdit(editingGrnId!);
      } else {
        if (itemEntries.isNotEmpty && itemEntries[0]['item_type_id'] != null) {
          _fetchItemsForType(itemEntries[0]['item_type_id']);
        }
      }
    });
  }

  Future<void> fetchSuppliers() async {
    setState(() {
      isLoading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }
      final response = await http.get(
        Uri.parse('https://1.sunshineiot.in/api/v2/purchase/supplier/id-name'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> suppliers = json.decode(response.body);
        setState(() {
          supplierList = suppliers
              .map(
                (e) => {
                  'id': e['id'],
                  'supplier_name': e['supplier_name'] ?? '',
                },
              )
              .toList();
          if (supplierList.isNotEmpty) {
            selectedSupplierId = supplierList[0]['id'];
            selectedSupplierName = supplierList[0]['supplier_name'];
          } else {
            selectedSupplierId = null;
            selectedSupplierName = null;
          }
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchGrnTypes() async {
    setState(() {
      isLoading = true;
    });
    try {
      // Use the central options controller directly
      await optionsController.fetchOptions();

      // Get GRN types directly from options controller
      final grnTypeOptions = optionsController.grnTypeOptions;

      if (grnTypeOptions.isEmpty) {
        // If no GRN types from options controller, create a fallback with default ID 67
        log('No GRN types available from options controller, using fallback');
        setState(() {
          grnTypeList = [
            {'id': 67, 'grn_type': 'Foc (Default)'},
          ];
          selectedGrnTypeId = 67;
          isLoading = false;
        });
        return;
      }

      // Convert options to the expected format
      final List<Map<String, dynamic>> convertedTypes = grnTypeOptions
          .map(
            (option) => {'id': option.optionId, 'grn_type': option.optionName},
          )
          .toList();

      setState(() {
        grnTypeList = convertedTypes;

        // Find Foc type using options controller's helper methods
        Option? gstOption;
        try {
          gstOption = grnTypeOptions.firstWhere(
            (option) =>
                option.optionName.toLowerCase().contains('gst') ||
                option.optionName.toLowerCase().contains('goods') ||
                option.optionName.toLowerCase().contains('tax'),
          );
        } catch (e) {
          gstOption = null;
        }

        if (gstOption != null) {
          selectedGrnTypeId = gstOption.optionId;
          log(
            'Found GST type from options controller: ID ${gstOption.optionId}, Name: ${gstOption.optionName}',
          );
        } else {
          // Use default GRN type ID 67 if GST not found
          selectedGrnTypeId = 67;
          log('No GST type found, using default GRN type ID: 67');
        }
        isLoading = false;
      });

      // Log for debugging
      log('GRN Types loaded from options controller: ${grnTypeList.length}');
      log(
        'Available types: ${grnTypeOptions.map((o) => '${o.optionId} - ${o.optionName}').join(', ')}',
      );
      log('Selected GST type ID: $selectedGrnTypeId');
    } catch (e) {
      // If there's an error, provide fallback with default ID 67
      log('Error in fetchGrnTypes: $e, using fallback');
      setState(() {
        grnTypeList = [
          {'id': 67, 'grn_type': 'GST-Non Returnable (Default)'},
        ];
        selectedGrnTypeId = 67;
        isLoading = false;
      });
    }
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isDate = false,
    DateTime? selectedDate,
    void Function(DateTime)? onDatePicked,
  }) {
    if (isDate) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: GestureDetector(
          onTap: () async {
            FocusScope.of(context).unfocus();
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              setState(() {
                controller.text = DateFormat('yyyy-MM-dd').format(picked);
                if (onDatePicked != null) onDatePicked(picked);
              });
            }
          },
          child: AbsorbPointer(
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                suffixIcon: const Icon(Icons.calendar_today),
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildStoreIdDropdown() {
    return Obx(() {
      final storeOptions = optionsController.storeOptions;
      log('[DEBUG] Store options count: ${storeOptions.length}');
      for (final store in storeOptions) {
        log(
          '[DEBUG] Store option: id=${store.optionId}, name=${store.optionName}',
        );
      }
      log('[DEBUG] Current selectedStoreId: $selectedStoreId');

      if (storeOptions.isEmpty) {
        log('[DEBUG] No stores available for dropdown');
        return DropdownSearch<Option>(
          items: const [],
          selectedItem: null,
          dropdownDecoratorProps: const DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              labelText: 'Store',
              hintText: 'Select Store',
              border: OutlineInputBorder(),
            ),
          ),
          popupProps: PopupProps.menu(
            showSearchBox: true,
            menuProps: const MenuProps(backgroundColor: Colors.white),
            searchFieldProps: const TextFieldProps(
              decoration: InputDecoration(
                hintText: 'Search Store...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
              ),
              style: TextStyle(
                color: Colors.black,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          itemAsString: (item) => '',
          dropdownBuilder: (context, item) => const Text(
            'No stores available',
            style: TextStyle(
              color: Colors.black,
              backgroundColor: Colors.white,
            ),
          ),
          onChanged: null,
          dropdownButtonProps: const DropdownButtonProps(
            icon: Icon(Icons.arrow_drop_down, color: Colors.black),
          ),
        );
      }

      // No default selection, only show selectedStoreId if set
      Option? selectedOption = storeOptions.firstWhereOrNull(
        (store) => store.optionId == selectedStoreId,
      );

      return DropdownSearch<Option>(
        selectedItem: selectedOption,
        items: storeOptions,
        dropdownDecoratorProps: const DropDownDecoratorProps(
          dropdownSearchDecoration: InputDecoration(
            labelText: 'Store',
            hintText: 'Select Store',
            border: OutlineInputBorder(),
          ),
        ),
        popupProps: PopupProps.menu(
          showSearchBox: true,
          menuProps: const MenuProps(backgroundColor: Colors.white),
          searchFieldProps: const TextFieldProps(
            decoration: InputDecoration(
              hintText: 'Search Store...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
            style: TextStyle(
              color: Colors.black,
              backgroundColor: Colors.white,
            ),
          ),
          itemBuilder: (context, item, isSelected) => Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              item.optionName,
              style: const TextStyle(color: Colors.black),
            ),
          ),
        ),
        itemAsString: (item) => item.optionName,
        dropdownBuilder: (context, item) {
          if (item == null) {
            return const Text(
              'Select Store',
              style: TextStyle(
                color: Colors.grey,
                backgroundColor: Colors.white,
              ),
            );
          }
          return Text(
            item.optionName,
            style: const TextStyle(
              color: Colors.black,
              backgroundColor: Colors.white,
            ),
          );
        },
        onChanged: (option) {
          log(
            '[DEBUG] Store dropdown changed: id=${option?.optionId}, name=${option?.optionName}',
          );
          setState(() {
            selectedStoreId = option?.optionId;
          });
        },
        validator: (option) => option == null ? 'Please select Store' : null,
        dropdownButtonProps: const DropdownButtonProps(
          icon: Icon(Icons.arrow_drop_down, color: Colors.black),
        ),
      );
    });
  }

  Widget _buildSupplierDropdown() {
    if (supplierList.isEmpty) {
      return DropdownSearch<int>(
        items: const [],
        selectedItem: null,
        dropdownDecoratorProps: const DropDownDecoratorProps(
          dropdownSearchDecoration: InputDecoration(
            labelText: 'Supplier Name',
            fillColor: Colors.white,
            filled: true,
            border: OutlineInputBorder(),
          ),
        ),
        popupProps: PopupProps.menu(
          menuProps: const MenuProps(backgroundColor: Colors.white),
          itemBuilder: (context, item, isSelected) => Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'No suppliers available',
              style: const TextStyle(color: Colors.black),
            ),
          ),
          searchFieldProps: const TextFieldProps(
            decoration: InputDecoration(
              hintText: 'Search Supplier...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
            style: TextStyle(
              color: Colors.black,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        itemAsString: (item) => '',
        dropdownBuilder: (context, item) => const Text(
          'No suppliers available',
          style: TextStyle(color: Colors.black, backgroundColor: Colors.white),
        ),
        onChanged: null,
        dropdownButtonProps: const DropdownButtonProps(
          icon: Icon(Icons.arrow_drop_down, color: Colors.black),
        ),
      );
    }
    int? dropdownValue =
        (supplierList.any((s) => s['id'] == selectedSupplierId))
        ? selectedSupplierId
        : supplierList[0]['id'];
    return DropdownSearch<int>(
      selectedItem: dropdownValue,
      items: supplierList.map((supplier) => supplier['id'] as int).toList(),
      dropdownDecoratorProps: const DropDownDecoratorProps(
        dropdownSearchDecoration: InputDecoration(
          labelText: 'Supplier Name',
          fillColor: Colors.white,
          filled: true,
          border: OutlineInputBorder(),
        ),
      ),
      popupProps: PopupProps.menu(
        menuProps: const MenuProps(backgroundColor: Colors.white),
        itemBuilder: (context, item, isSelected) => Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            supplierList.firstWhere(
                  (s) => s['id'] == item,
                  orElse: () => {'id': -1, 'supplier_name': 'Unknown Supplier'},
                )['supplier_name'] ??
                '',
            style: const TextStyle(color: Colors.black),
          ),
        ),
        searchFieldProps: const TextFieldProps(
          decoration: InputDecoration(
            hintText: 'Search Supplier...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
          style: TextStyle(color: Colors.black, backgroundColor: Colors.white),
        ),
      ),
      itemAsString: (item) =>
          supplierList.firstWhere(
            (s) => s['id'] == item,
            orElse: () => {'id': -1, 'supplier_name': 'Unknown Supplier'},
          )['supplier_name'] ??
          '',
      dropdownBuilder: (context, item) => Text(
        item == null
            ? ''
            : supplierList.firstWhere(
                    (s) => s['id'] == item,
                    orElse: () => {
                      'id': -1,
                      'supplier_name': 'Unknown Supplier',
                    },
                  )['supplier_name'] ??
                  '',
        style: const TextStyle(
          color: Colors.black,
          backgroundColor: Colors.white,
        ),
      ),
      onChanged: (value) {
        final selected = supplierList.firstWhere(
          (s) => s['id'] == value,
          orElse: () => {'id': null, 'supplier_name': ''},
        );
        setState(() {
          selectedSupplierId = selected['id'];
          selectedSupplierName = selected['supplier_name'];
        });
      },
      dropdownButtonProps: const DropdownButtonProps(
        icon: Icon(Icons.arrow_drop_down, color: Colors.black),
      ),
    );
  }

  Widget _buildItemEntry(int index) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _buildItemTypeDropdown(index)),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownSearch<int>(
                    selectedItem:
                        availableItemList.any(
                          (item) => item['id'] == itemEntries[index]['item_id'],
                        )
                        ? itemEntries[index]['item_id']
                        : null,
                    items: availableItemList
                        .map((item) => item['id'] as int)
                        .toList(),
                    dropdownDecoratorProps: const DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(
                        labelText: 'Item (UIN)',
                        hintText: 'Select Item',
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    popupProps: PopupProps.menu(
                      menuProps: const MenuProps(backgroundColor: Colors.white),
                      itemBuilder: (context, item, isSelected) {
                        final itemData = availableItemList.firstWhere(
                          (i) => i['id'] == item,
                          orElse: () => {
                            'id': -1,
                            'description': 'Unknown Item',
                          },
                        );
                        return Container(
                          color: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Text(
                            itemData['description']?.toString() ?? '',
                            style: const TextStyle(color: Colors.black),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                      searchFieldProps: const TextFieldProps(
                        decoration: InputDecoration(
                          hintText: 'Search by UIN or Description...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                        ),
                        style: TextStyle(
                          color: Colors.black,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    itemAsString: (item) {
                      final itemData = availableItemList.firstWhere(
                        (i) => i['id'] == item,
                        orElse: () => {'id': -1, 'description': 'Unknown Item'},
                      );
                      return itemData['description']?.toString() ?? '';
                    },
                    dropdownBuilder: (context, item) {
                      if (item == null) {
                        return const Text(
                          'Select Item',
                          style: TextStyle(
                            color: Colors.grey,
                            backgroundColor: Colors.white,
                          ),
                        );
                      }
                      final itemData = availableItemList.firstWhere(
                        (i) => i['id'] == item,
                        orElse: () => {'id': -1, 'description': 'Unknown Item'},
                      );
                      return Text(
                        itemData['description']?.toString() ?? '',
                        style: const TextStyle(
                          color: Colors.black,
                          backgroundColor: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                    onChanged: (value) {
                      setState(() {
                        itemEntries[index]['item_id'] = value;
                      });
                    },
                    dropdownButtonProps: const DropdownButtonProps(
                      icon: Icon(Icons.arrow_drop_down, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: itemEntries[index]['poQty'] ?? '',
                    decoration: const InputDecoration(
                      labelText: 'PO Qty',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      setState(() {
                        itemEntries[index]['poQty'] = val;
                        _updateItemTotal(index);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    initialValue: itemEntries[index]['actualQty'] ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Actual Qty',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      setState(() {
                        itemEntries[index]['actualQty'] = val;
                        _updateItemTotal(index);
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: itemEntries[index]['rate'] ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Rate/Unit',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      setState(() {
                        itemEntries[index]['rate'] = val;
                        _updateItemTotal(index);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    initialValue: itemEntries[index]['poTotal'] ?? '',
                    decoration: const InputDecoration(
                      labelText: 'PO Total (Manual)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => itemEntries[index]['poTotal'] = val,
                  ),
                ),
              ],
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Invoice Total: ₹${(itemEntries[index]['invoiceTotal'] ?? 0.0).toStringAsFixed(2)}",
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Delete Item',
                  onPressed: () {
                    setState(() {
                      itemEntries.removeAt(index);
                      _calculateTotalBilling();
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _updateItemTotal(int index) {
    try {
      double rate = double.tryParse(itemEntries[index]['rate'] ?? '') ?? 0;
      double actualQty =
          double.tryParse(itemEntries[index]['actualQty'] ?? '') ?? 0;
      itemEntries[index]['invoiceTotal'] = rate * actualQty;
    } catch (_) {}
    _calculateTotalBilling();
  }

  void _calculateTotalBilling() {
    double total = 0;
    for (var item in itemEntries) {
      total += item['invoiceTotal'] ?? 0;
    }
    setState(() {
      totalCalculatedAmount = total;
    });
  }

  int _getMonthNumber(String monthYear) {
    try {
      final date = DateFormat('MMMM, yyyy').parse(monthYear);
      return date.month;
    } catch (_) {
      return DateTime.now().month;
    }
  }

  void _showPreview() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'FOC Form Preview',
            style: TextStyle(color: Colors.black),
          ),
          backgroundColor: Colors.white,
          content: SingleChildScrollView(
            child: Container(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'GRN Type: FOC',
                    style: TextStyle(color: Colors.black),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'GRN No: ${grnNoController.text}',
                    style: const TextStyle(color: Colors.black),
                  ),
                  Text(
                    'GRN Date: ${grnDateController.text}',
                    style: const TextStyle(color: Colors.black),
                  ),
                  Text(
                    'Inward B/N: ${inwardBnController.text}',
                    style: const TextStyle(color: Colors.black),
                  ),
                  Text(
                    'Month of Invoice: ${monthOfInvoiceController.text}',
                    style: const TextStyle(color: Colors.black),
                  ),
                  Text(
                    'Supplier Name: ${selectedSupplierName ?? ''}',
                    style: const TextStyle(color: Colors.black),
                  ),
                  Text(
                    'Invoice No: ${invoiceNoController.text}',
                    style: const TextStyle(color: Colors.black),
                  ),
                  Text(
                    'Invoice Date: ${invoiceDateController.text}',
                    style: const TextStyle(color: Colors.black),
                  ),
                  Text(
                    'PO No: ${poNoController.text}',
                    style: const TextStyle(color: Colors.black),
                  ),
                  Text(
                    'Store ID: ${selectedStoreId ?? 'Not selected'}',
                    style: const TextStyle(color: Colors.black),
                  ),
                  Text(
                    'Remarks: ${remarksController.text}',
                    style: const TextStyle(color: Colors.black),
                  ),
                  Text(
                    'GRN Status: $selectedGrnStatus',
                    style: const TextStyle(color: Colors.black),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Items:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  DataTable(
                    headingRowColor: WidgetStateProperty.all(Colors.white),
                    dataRowColor: WidgetStateProperty.all(Colors.white),
                    columns: const [
                      DataColumn(
                        label: Text(
                          'UIN',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'PO Qty',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Actual Qty',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Rate',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Invoice Total',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'PO Total',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ],
                    rows: itemEntries.map<DataRow>((item) {
                      final uin = availableItemList.firstWhere(
                        (i) => i['id'] == item['item_id'],
                        orElse: () => {'uin': ''},
                      )['uin'];
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              uin?.toString() ?? '',
                              style: const TextStyle(color: Colors.black),
                            ),
                          ),
                          DataCell(
                            Text(
                              item['poQty']?.toString() ?? '',
                              style: const TextStyle(color: Colors.black),
                            ),
                          ),
                          DataCell(
                            Text(
                              item['actualQty']?.toString() ?? '',
                              style: const TextStyle(color: Colors.black),
                            ),
                          ),
                          DataCell(
                            Text(
                              item['rate']?.toString() ?? '',
                              style: const TextStyle(color: Colors.black),
                            ),
                          ),
                          DataCell(
                            Text(
                              item['invoiceTotal'] != null
                                  ? '\u20b9${item['invoiceTotal'].toStringAsFixed(2)}'
                                  : '',
                              style: const TextStyle(color: Colors.black),
                            ),
                          ),
                          DataCell(
                            Text(
                              item['poTotal']?.toString() ?? '',
                              style: const TextStyle(color: Colors.black),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Manual Billing Amount: \u20b9${billingAmountController.text}',
                    style: const TextStyle(color: Colors.black),
                  ),
                  Text(
                    'Calculated Billing Amount: \u20b9${totalCalculatedAmount.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.black),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Close', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildItemTypeDropdown(int index) {
    // Use options controller to get item type options
    final itemTypeOptions = optionsController.itemTypeOptions;

    if (itemTypeOptions.isEmpty) {
      return DropdownSearch<int>(
        items: const [],
        selectedItem: null,
        dropdownDecoratorProps: const DropDownDecoratorProps(
          dropdownSearchDecoration: InputDecoration(
            labelText: 'Item Type',
            fillColor: Colors.white,
            filled: true,
            border: OutlineInputBorder(),
          ),
        ),
        popupProps: PopupProps.menu(
          menuProps: const MenuProps(backgroundColor: Colors.white),
          itemBuilder: (context, item, isSelected) => Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'No item types available',
              style: const TextStyle(color: Colors.black),
            ),
          ),
          searchFieldProps: const TextFieldProps(
            decoration: InputDecoration(
              hintText: 'Search Item Type...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
            style: TextStyle(
              color: Colors.black,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        itemAsString: (item) => '',
        dropdownBuilder: (context, item) => const Text(
          'No item types available',
          style: TextStyle(color: Colors.black, backgroundColor: Colors.white),
        ),
        onChanged: null,
        dropdownButtonProps: const DropdownButtonProps(
          icon: Icon(Icons.arrow_drop_down, color: Colors.black),
        ),
      );
    }

    int? dropdownValue =
        itemEntries[index]['item_type_id'] ?? 54; // Default to RM

    return DropdownSearch<int>(
      selectedItem: dropdownValue,
      items: itemTypeOptions.map((type) => type.optionId).toList(),
      dropdownDecoratorProps: const DropDownDecoratorProps(
        dropdownSearchDecoration: InputDecoration(
          labelText: 'Item Type',
          fillColor: Colors.white,
          filled: true,
          border: OutlineInputBorder(),
        ),
      ),
      popupProps: PopupProps.menu(
        menuProps: const MenuProps(backgroundColor: Colors.white),
        itemBuilder: (context, item, isSelected) => Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            itemTypeOptions
                .firstWhere(
                  (t) => t.optionId == item,
                  orElse: () =>
                      Option(optionId: -1, optionName: 'Unknown Type'),
                )
                .optionName,
            style: const TextStyle(color: Colors.black),
          ),
        ),
        searchFieldProps: const TextFieldProps(
          decoration: InputDecoration(
            hintText: 'Search Item Type...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
          style: TextStyle(color: Colors.black, backgroundColor: Colors.white),
        ),
      ),
      itemAsString: (item) => itemTypeOptions
          .firstWhere(
            (t) => t.optionId == item,
            orElse: () => Option(optionId: -1, optionName: 'Unknown Type'),
          )
          .optionName,
      dropdownBuilder: (context, item) => Text(
        item == null
            ? ''
            : itemTypeOptions
                  .firstWhere(
                    (t) => t.optionId == item,
                    orElse: () =>
                        Option(optionId: -1, optionName: 'Unknown Type'),
                  )
                  .optionName,
        style: const TextStyle(
          color: Colors.black,
          backgroundColor: Colors.white,
        ),
      ),
      onChanged: (value) {
        setState(() {
          itemEntries[index]['item_type_id'] = value;
          // Reset item_id when item type changes
          itemEntries[index]['item_id'] = null;
          // Fetch items for the selected item type
          if (value != null) {
            _fetchItemsForType(value);
          }
        });
      },
      validator: (value) => value == null ? 'Please select Item Type' : null,
      dropdownButtonProps: const DropdownButtonProps(
        icon: Icon(Icons.arrow_drop_down, color: Colors.black),
      ),
    );
  }

  Future<void> _fetchItemsForType(int itemTypeId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) {
      SnackbarUtils.showError(
        'Authentication token not found. Please login again.',
      );
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
          'https://1.sunshineiot.in/api/v2/store/item/all/$itemTypeId?page=&limit=20&search=&item_id=',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null) {
          setState(() {
            availableItemList = List<Map<String, dynamic>>.from(data['data']);
          });
        }
      } else {
        SnackbarUtils.showError('Failed to fetch items for selected type');
      }
    } catch (e) {
      SnackbarUtils.showError('Error fetching items: $e');
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      isLoading = true;
      isSubmitting = true;
    });
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) {
      SnackbarUtils.showError(
        'Authentication token not found. Please login again.',
      );
      setState(() {
        isLoading = false;
        isSubmitting = false;
      });
      return;
    }

    DateTime? grnDateToSend;
    try {
      if (selectedGrnDate != null) {
        grnDateToSend = selectedGrnDate;
      } else if (grnDateController.text.isNotEmpty) {
        grnDateToSend = DateFormat('yyyy-MM-dd').parse(grnDateController.text);
      }
    } catch (_) {
      grnDateToSend = null;
    }

    DateTime? invoiceDateToSend;
    try {
      if (selectedInvoiceDate != null) {
        invoiceDateToSend = selectedInvoiceDate;
      } else if (invoiceDateController.text.isNotEmpty) {
        invoiceDateToSend = DateFormat(
          'yyyy-MM-dd',
        ).parse(invoiceDateController.text);
      }
    } catch (_) {
      invoiceDateToSend = null;
    }

    if (grnDateToSend == null) {
      SnackbarUtils.showError('Please select a valid GRN Date.');
      setState(() {
        isLoading = false;
        isSubmitting = false;
      });
      return;
    }

    // Validate GRN type before submission
    if (selectedGrnTypeId == null) {
      SnackbarUtils.showError('Please select a valid GRN Type.');
      setState(() {
        isLoading = false;
        isSubmitting = false;
      });
      return;
    }

    // Log the data being sent for debugging
    log('Submitting GRN with type ID: $selectedGrnTypeId');
    log(
      'Available GRN types: ${grnTypeList.map((t) => '${t['id']} - ${t['grn_type']}').join(', ')}',
    );

    // Build GRN payload
    final grnData = {
  "grn_no": grnNoController.text,
  "grn_date": grnDateToSend.toUtc().toIso8601String(),
  "grn_type": selectedGrnTypeId,
  "inward_bn": inwardBnController.text,
  "month_of_invoice": _getMonthNumber(monthOfInvoiceController.text),
  "supplier_id": selectedSupplierId,
  "invoice_no": invoiceNoController.text,
  "invoice_date": invoiceDateToSend?.toUtc().toIso8601String(),
  "po_no": poNoController.text,
  "vendor_challan_no": vendorChallanController.text,
  "return_date": returnDateController.text.isNotEmpty
      ? DateTime.parse(returnDateController.text).toUtc().toIso8601String()
      : null,
  "repair_status": repairStatusController.text,
  "warranty_period": warrantyPeriodController.text,
  "billing_amount": billingAmountController.text.isNotEmpty
      ? double.tryParse(billingAmountController.text) ?? 0.0
      : 0.0,
  "store_id": selectedStoreId,
  "remarks": remarksController.text,
};

    try {
      http.Response grnResponse;
      int? grnId;
      String grnMessage;

      if (isEditMode && editingGrnId != null) {
        // Update existing GRN
        log('Updating GRN ${editingGrnId} with data: ${json.encode(grnData)}');
        grnResponse = await http.put(
          Uri.parse('https://1.sunshineiot.in/api/v2/store/grn/${editingGrnId}'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode(grnData),
        );
      } else {
        // Create new GRN
        log('Creating GRN with data: ${json.encode(grnData)}');
        grnResponse = await http.post(
          Uri.parse('https://1.sunshineiot.in/api/v2/store/grn'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode(grnData),
        );
      }

      if (grnResponse.statusCode == 200 || grnResponse.statusCode == 201) {
        final grnResponseData = json.decode(grnResponse.body);
        grnId = isEditMode && editingGrnId != null ? editingGrnId : grnResponseData['grnId'];
        grnMessage = grnResponseData['message'] ?? (isEditMode ? 'GRN updated successfully' : 'GRN created successfully');

        log('GRN ${isEditMode ? 'updated' : 'created'} successfully with ID: $grnId');

        // Step 2: Add items to the created GRN
        if (grnId != null && itemEntries.isNotEmpty) {
          final itemsData = itemEntries
              .where((item) => item['item_id'] != null) // Only include items with valid item_id
              .map((item) => {
                    if (isEditMode && (item['id'] != null)) "id": item['id'],
                    "item_type_id": item['item_type_id'] ?? 54,
                    "item_id": item['item_id'],
                    "unit": (item['unit'] ?? '').toString(),
                    "po_qty": item['poQty'].isNotEmpty
                        ? double.tryParse(item['poQty']) ?? 0.0
                        : 0.0,
                    "actual_qty": item['actualQty'].isNotEmpty
                        ? double.tryParse(item['actualQty']) ?? 0.0
                        : 0.0,
                    "rate": item['rate'].isNotEmpty
                        ? double.tryParse(item['rate']) ?? 0.0
                        : 0.0,
                    "po_total": item['poTotal'].isNotEmpty
                        ? double.tryParse(item['poTotal']) ?? 0.0
                        : 0.0,
                    "invoice_total": item['invoiceTotal'] is double
                        ? item['invoiceTotal']
                        : 0.0,
                    "defect_type": (item['defect_type'] ?? '').toString(),
                    "repair_notes": (item['repair_notes'] ?? '').toString(),
                  })
              .toList();

          log('${isEditMode ? 'Updating' : 'Adding'} items for GRN $grnId: ${json.encode(itemsData)}');

          final itemsResponse = isEditMode
              ? await http.put(
                  Uri.parse('https://1.sunshineiot.in/api/v2/store/grn/items/$grnId'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                  body: json.encode(itemsData),
                )
              : await http.post(
                  Uri.parse('https://1.sunshineiot.in/api/v2/store/grn/items/$grnId'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                  body: json.encode(itemsData),
                );

          if (itemsResponse.statusCode == 200 ||
              itemsResponse.statusCode == 201) {
            final itemsResponseData = json.decode(itemsResponse.body);
            final addedItems = itemsResponseData['addedItems'] ?? [];
            final updatedItems = itemsResponseData['updatedItems'] ?? [];
            final itemsMessage = itemsResponseData['message'] ?? (isEditMode ? 'GRN Items updated successfully' : 'Items added successfully');

            setState(() {
              isLoading = false;
              isSubmitting = false;
            });

            SnackbarUtils.showSuccess(
              '$grnMessage. $itemsMessage. GRN ID: $grnId, Updated: ${updatedItems.length}, Added: ${addedItems.length}',
            );
            Get.offAllNamed('/dashboard/store/grn');
          } else {
            // GRN created but items failed
            setState(() {
              isLoading = false;
              isSubmitting = false;
            });
            try {
              final errorData = json.decode(itemsResponse.body);
              final errorMessage = errorData['message'] ?? itemsResponse.body;
              SnackbarUtils.showError(
                '${isEditMode ? 'GRN updated' : 'GRN created'} successfully (ID: $grnId), but failed to ${isEditMode ? 'update' : 'add'} items: $errorMessage',
              );
            } catch (parseError) {
              SnackbarUtils.showError(
                '${isEditMode ? 'GRN updated' : 'GRN created'} successfully (ID: $grnId), but failed to ${isEditMode ? 'update' : 'add'} items: ${itemsResponse.body}',
              );
            }
          }
        } else {
          // GRN created but no items to add
          setState(() {
            isLoading = false;
            isSubmitting = false;
          });
          SnackbarUtils.showSuccess('$grnMessage. GRN ID: $grnId');
        }
        Get.offAllNamed('/dashboard/store/grn');
      } else {
        // GRN create/update failed
        setState(() {
          isLoading = false;
          isSubmitting = false;
        });
        try {
          final errorData = json.decode(grnResponse.body);
          final errorMessage = errorData['message'] ?? grnResponse.body;
          SnackbarUtils.showError('Failed to ${isEditMode ? 'update' : 'create'} GRN: $errorMessage');
        } catch (parseError) {
          SnackbarUtils.showError('Failed to ${isEditMode ? 'update' : 'create'} GRN: ${grnResponse.body}');
        }
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        isSubmitting = false;
      });
      SnackbarUtils.showError('Error: $e');
    }
  }

  Future<void> _loadGrnForEdit(int grnId) async {
    try {
      setState(() {
        isLoading = true;
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) {
        SnackbarUtils.showError('Please login to continue.');
        setState(() {
          isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('https://1.sunshineiot.in/api/v2/store/grn/$grnId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        // Prefill header fields
        grnNoController.text = (data['grn_no'] ?? '').toString();
        final grnDateStr = (data['grn_date'] ?? '').toString();
        if (grnDateStr.isNotEmpty) {
          try {
            final parsed = DateTime.parse(grnDateStr);
            selectedGrnDate = parsed;
            grnDateController.text = DateFormat('yyyy-MM-dd').format(parsed);
          } catch (_) {}
        }
        inwardBnController.text = (data['inward_bn'] ?? '').toString();
        invoiceNoController.text = (data['invoice_no'] ?? '').toString();

        final invoiceDateStr = (data['invoice_date'] ?? '').toString();
        if (invoiceDateStr.isNotEmpty) {
          try {
            final parsed = DateTime.parse(invoiceDateStr);
            selectedInvoiceDate = parsed;
            invoiceDateController.text = DateFormat('yyyy-MM-dd').format(parsed);
          } catch (_) {}
        }
        poNoController.text = (data['po_no'] ?? '').toString();
        vendorChallanController.text = (data['vendor_challan_no'] ?? '').toString();

        final returnDateStr = (data['return_date'] ?? '').toString();
        if (returnDateStr.isNotEmpty) {
          try {
            final parsed = DateTime.parse(returnDateStr);
            returnDateController.text = DateFormat('yyyy-MM-dd').format(parsed);
          } catch (_) {}
        }
        repairStatusController.text = (data['repair_status'] ?? '').toString();
        warrantyPeriodController.text = (data['warranty_period'] ?? '').toString();
        billingAmountController.text = (data['billing_amount']?.toString() ?? '');
        remarksController.text = (data['remarks'] ?? '').toString();

        // Supplier and store
        selectedSupplierId = data['supplier_id'] is int ? data['supplier_id'] : int.tryParse('${data['supplier_id']}');
        selectedStoreId = data['store_id'] is int ? data['store_id'] : int.tryParse('${data['store_id']}');

        // GRN Type
        selectedGrnTypeId = data['grn_type'] is int ? data['grn_type'] : int.tryParse('${data['grn_type']}');

        // Items
        final items = (data['items'] as List<dynamic>? ?? [])
            .map<Map<String, dynamic>>((item) => {
                  'id': item['id'],
                  'item_id': item['item_id'],
                  'item_type_id': item['item_type_id'] ?? 54,
                  'unit': (item['unit']?.toString() ?? ''),
                  'poQty': (item['po_qty']?.toString() ?? ''),
                  'actualQty': (item['actual_qty']?.toString() ?? ''),
                  'rate': (item['rate']?.toString() ?? ''),
                  'invoiceTotal': (item['invoice_total'] is num) ? (item['invoice_total'] as num).toDouble() : 0.0,
                  'poTotal': (item['po_total']?.toString() ?? ''),
                  'defect_type': (item['defect_type']?.toString() ?? ''),
                  'repair_notes': (item['repair_notes']?.toString() ?? ''),
                })
            .toList();

        setState(() {
          itemEntries = items.isNotEmpty ? items : itemEntries;
        });

        // Load items for the first type to populate dropdown list
        if (itemEntries.isNotEmpty && itemEntries[0]['item_type_id'] != null) {
          await _fetchItemsForType(itemEntries[0]['item_type_id']);
        }

        _calculateTotalBilling();

        setState(() {
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        SnackbarUtils.showError('Failed to load GRN for edit (Status ${response.statusCode})');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      SnackbarUtils.showError('Error loading GRN: $e');
    }
  }

  @override
  void dispose() {
    grnNoController.dispose();
    grnDateController.dispose();
    inwardBnController.dispose();
    monthOfInvoiceController.dispose();
    invoiceNoController.dispose();
    invoiceDateController.dispose();
    poNoController.dispose();
    // In your dispose() method:
    vendorChallanController.dispose();
    returnDateController.dispose();
    repairStatusController.dispose();
    warrantyPeriodController.dispose();
    remarksController.dispose();
    billingAmountController.dispose();
    storeIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
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
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'This form is for FOC GRN entry.',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _buildTextField('GRN No', grnNoController),
                        _buildTextField('Inward B/N', inwardBnController),
                        _buildSupplierDropdown(),
                        // Hidden GRN type field - will be set from backend
                        Builder(
                          builder: (context) {
                            // Use options controller directly to get FOC type
                            final grnTypeOptions =
                                optionsController.grnTypeOptions;
                            Option? focOption;

                            try {
                              focOption = grnTypeOptions.firstWhere(
                                (option) => option.optionName
                                    .toLowerCase()
                                    .contains('foc'),
                              );
                            } catch (e) {
                              focOption = null;
                            }

                            // Update selectedGrnTypeId if foc option found, otherwise use default 67
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (selectedGrnTypeId !=
                                  (focOption?.optionId ?? 67)) {
                                setState(() {
                                  selectedGrnTypeId = focOption?.optionId ?? 67;
                                });
                              }
                            });

                            return const SizedBox.shrink(); // Hidden field
                          },
                        ),
                        _buildTextField('PO No', poNoController),
                        _buildTextField(
                          'Vendor Challan',
                          vendorChallanController,
                        ),
                        _buildStoreIdDropdown(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        _buildTextField(
                          'GRN Date',
                          grnDateController,
                          isDate: true,
                          selectedDate: selectedGrnDate,
                          onDatePicked: (picked) => selectedGrnDate = picked,
                        ),
                        _buildTextField(
                          'Month of Invoice',
                          monthOfInvoiceController,
                        ),
                        _buildTextField('Invoice No', invoiceNoController),
                        _buildTextField(
                          'Invoice Date',
                          invoiceDateController,
                          isDate: true,
                          selectedDate: selectedInvoiceDate,
                          onDatePicked: (picked) =>
                              selectedInvoiceDate = picked,
                        ),
                        _buildTextField('Remarks', remarksController),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Material Description (Items)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...itemEntries.asMap().entries.map((entry) {
                return _buildItemEntry(entry.key);
              }),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      itemEntries.add({
                        'item_id': null,
                        'item_type_id': 54, // Default to RM
                        'poQty': '',
                        'actualQty': '',
                        'rate': '',
                        'invoiceTotal': 0.0,
                        'poTotal': '',
                      });
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: billingAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Manual Billing Amount Entry (₹)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Calculated Billing Amount: ₹${totalCalculatedAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showPreview,
                      icon: const Icon(Icons.visibility),
                      label: const Text('View'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        textStyle: const TextStyle(fontSize: 16),
                        backgroundColor: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        textStyle: const TextStyle(fontSize: 16),
                        backgroundColor: isSubmitting
                            ? Colors.grey
                            : Colors.green,
                      ),
                      child: isSubmitting
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Submitting...'),
                              ],
                            )
                          : const Text('Submit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
