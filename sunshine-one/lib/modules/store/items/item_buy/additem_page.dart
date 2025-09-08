import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../utils/snackbar_message.dart';

class AddItemPage extends StatefulWidget {
  final Map<String, dynamic>? item;
  const AddItemPage({super.key, this.item});

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController modelNoController = TextEditingController();
  final TextEditingController hsnController = TextEditingController();
  final TextEditingController spqController = TextEditingController();
  final TextEditingController moqController = TextEditingController();
  final TextEditingController rateController = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item ?? Get.arguments;
    if (item != null) {
      descriptionController.text = item['description']?.toString() ?? '';
      modelNoController.text = item['model_no']?.toString() ?? '';
      hsnController.text = item['hsn_code']?.toString() ?? '';
      spqController.text = item['spq']?.toString() ?? '';
      moqController.text = item['moq']?.toString() ?? '';
      // Convert rate to integer if it's a decimal number
      final rateValue = item['rate'];
      if (rateValue != null) {
        if (rateValue is double) {
          rateController.text = rateValue.toInt().toString();
        } else if (rateValue is int) {
          rateController.text = rateValue.toString();
        } else {
          // Try to parse as double first, then convert to int
          final doubleValue = double.tryParse(rateValue.toString());
          if (doubleValue != null) {
            rateController.text = doubleValue.toInt().toString();
          } else {
            rateController.text = rateValue.toString();
          }
        }
      } else {
        rateController.text = '';
      }
    }
  }

  @override
  void dispose() {
    descriptionController.dispose();
    modelNoController.dispose();
    hsnController.dispose();
    spqController.dispose();
    moqController.dispose();
    rateController.dispose();
    super.dispose();
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      isLoading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) {
        SnackbarUtils.showError('Authentication token not found');
        setState(() {
          isLoading = false;
        });
        return;
      }
      final body = <String, dynamic>{
        "description": descriptionController.text.trim(),
        "model_no": modelNoController.text.trim(),
        "hsn_code": hsnController.text.trim(),
        "spq": int.tryParse(spqController.text.trim()) ?? 0,
        "moq": int.tryParse(moqController.text.trim()) ?? 0,
        "rate": int.tryParse(rateController.text.trim()) ?? 0,
      };
      body.removeWhere((k, v) => v == null || (v is String && v.isEmpty));
      http.Response response;
      if (widget.item != null && widget.item!['item_id'] != null) {
        final itemId = widget.item!['item_id'].toString();
        response = await http.put(
          Uri.parse('https://1.sunshineiot.in/api/v2/store/item/$itemId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        );
      } else {
        response = await http.post(
          Uri.parse('https://1.sunshineiot.in/api/v2/store/item/fg'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        );
      }
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        SnackbarUtils.showSuccess(
          responseData['message'] ?? 'Item saved successfully',
        );
        // Wait a bit for the snackbar to show, then navigate
        await Future.delayed(const Duration(milliseconds: 1500));
        Get.offAllNamed(
          '/dashboard/store/items',
        ); // Navigate to items screen and clear navigation stack
      } else {
        try {
          final errorData = jsonDecode(response.body);
          SnackbarUtils.showError(
            errorData['message'] ?? 'Failed to save item',
          );
        } catch (e) {
          SnackbarUtils.showError(
            'Failed to save item. Status: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      SnackbarUtils.showError('An error occurred: $e');
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
    return Scaffold(
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
                      widget.item != null
                          ? 'Edit Finished Goods'
                          : 'Add Finished Goods',
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _inputField("Description", descriptionController),
                    _inputField("Model No", modelNoController),
                    _inputField(
                      "HSN",
                      hsnController,
                      isNumber: true,
                      maxLength: 8,
                    ),
                    _inputField("SPQ", spqController, isNumber: true),
                    _inputField("MOQ", moqController, isNumber: true),
                    _inputField("Rate", rateController, isNumber: true),
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
                          onPressed: isLoading ? null : _saveItem,
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
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  widget.item != null
                                      ? 'Update Item'
                                      : 'Save Item',
                                ),
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
          title: Text(
            widget.item != null ? 'Edit Form Overview' : 'Form Overview',
          ),
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
                    'Description',
                    descriptionController.text.isNotEmpty
                        ? descriptionController.text
                        : 'Not filled',
                  ),
                  _buildTableRow(
                    'Model No',
                    modelNoController.text.isNotEmpty
                        ? modelNoController.text
                        : 'Not filled',
                  ),
                  _buildTableRow(
                    'HSN Code',
                    hsnController.text.isNotEmpty
                        ? hsnController.text
                        : 'Not filled',
                  ),
                  _buildTableRow(
                    'SPQ',
                    spqController.text.isNotEmpty
                        ? spqController.text
                        : 'Not filled',
                  ),
                  _buildTableRow(
                    'MOQ',
                    moqController.text.isNotEmpty
                        ? moqController.text
                        : 'Not filled',
                  ),
                  _buildTableRow(
                    'Rate',
                    rateController.text.isNotEmpty
                        ? rateController.text
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
                  color: value == 'Not filled'
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

  Widget _inputField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    bool isDecimal = false,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: isDecimal
            ? TextInputType.numberWithOptions(decimal: true)
            : (isNumber ? TextInputType.number : TextInputType.text),
        maxLength: maxLength,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black87),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.black26),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.black),
            borderRadius: BorderRadius.circular(8),
          ),
          counterText: '',
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Required';
          }
          if (isDecimal && double.tryParse(value) == null) {
            return 'Please enter a valid number';
          }
          if (isNumber && int.tryParse(value) == null) {
            return 'Please enter a valid number';
          }
          return null;
        },
      ),
    );
  }
}
