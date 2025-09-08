import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../../utils/snackbar_message.dart';
import '../../utils/standard_table_style.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../controllers/options_controller.dart';

class MasterPage extends StatefulWidget {
  const MasterPage({super.key});

  @override
  State<MasterPage> createState() => _MasterPageState();
}

class _MasterPageState extends State<MasterPage> {
  List<Map<String, dynamic>> typesData = [];
  bool isLoading = true;
  String? selectedType;
  String? selectedOption;
  final TextEditingController _newOptionController = TextEditingController();
  final TextEditingController _editOptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchTypesAndOptions();
  }

  @override
  void dispose() {
    _newOptionController.dispose();
    _editOptionController.dispose();
    super.dispose();
  }

  Future<void> fetchTypesAndOptions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('https://1.sunshineiot.in/api/v2/admin/option/types-options'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          typesData = data.cast<Map<String, dynamic>>();
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        SnackbarUtils.showError('Failed to fetch data: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      SnackbarUtils.showError('Failed to fetch data: $e');
    }
  }

  Future<void> addOption(String typeId, String optionName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.post(
        Uri.parse('https://1.sunshineiot.in/api/v2/admin/option/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'type_id': int.parse(typeId),
          'option_name': optionName,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          SnackbarUtils.showSuccess(
            responseData['message'] ?? 'Option added successfully',
          );
          // Refresh the content after adding
          await fetchTypesAndOptions();
          // Refresh global options controller
          OptionsController.to.refreshOptions();
        } else {
          SnackbarUtils.showError(
            responseData['message'] ?? 'Failed to add option',
          );
        }
      } else {
        SnackbarUtils.showError('Failed to add option: ${response.statusCode}');
      }
    } catch (e) {
      SnackbarUtils.showError('Failed to add option: $e');
    }
  }

  Future<void> editOption(String optionId, String optionName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.put(
        Uri.parse('https://1.sunshineiot.in/api/v2/admin/option'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'option_id': int.parse(optionId),
          'option_name': optionName,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          SnackbarUtils.showSuccess(
            responseData['message'] ?? 'Option updated successfully',
          );
          // Refresh the content after updating
          await fetchTypesAndOptions();
          // Refresh global options controller
          OptionsController.to.refreshOptions();
        } else {
          SnackbarUtils.showError('The Option is referenced somewhere!!');
        }
      } else {
        SnackbarUtils.showError('The Option is referenced somewhere!!');
      }
    } catch (e) {
      SnackbarUtils.showError('The Option is referenced somewhere!!');
    }
  }

  Future<void> deleteOption(String optionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.delete(
        Uri.parse('https://1.sunshineiot.in/api/v2/admin/option/$optionId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          SnackbarUtils.showSuccess(
            responseData['message'] ?? 'Option deleted successfully',
          );
          // Refresh the content after deleting
          await fetchTypesAndOptions();
          // Refresh global options controller
          OptionsController.to.refreshOptions();
        } else {
          SnackbarUtils.showError('The Option is referenced somewhere!!');
        }
      } else if (response.statusCode == 500) {
        // Try multiple alternative approaches
        List<Map<String, dynamic>> alternativeApproaches = [
          {
            'url': 'https://1.sunshineiot.in/api/v2/admin/option/delete',
            'method': 'POST',
            'body': {'option_id': int.parse(optionId)},
          },
          {
            'url':
                'https://1.sunshineiot.in/api/v2/admin/option/delete/$optionId',
            'method': 'POST',
            'body': {},
          },
          {
            'url': 'https://1.sunshineiot.in/api/v2/admin/option',
            'method': 'DELETE',
            'body': {'option_id': int.parse(optionId)},
          },
        ];

        bool deleteSuccess = false;

        for (var approach in alternativeApproaches) {
          try {
            http.Response alternativeResponse;
            if (approach['method'] == 'POST') {
              alternativeResponse = await http.post(
                Uri.parse(approach['url']),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json',
                },
                body: json.encode(approach['body']),
              );
            } else {
              alternativeResponse = await http.delete(
                Uri.parse(approach['url']),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json',
                },
                body: json.encode(approach['body']),
              );
            }

            if (alternativeResponse.statusCode == 200) {
              final responseData = json.decode(alternativeResponse.body);
              if (responseData['success'] == true) {
                SnackbarUtils.showSuccess(
                  responseData['message'] ?? 'Option deleted successfully',
                );
                await fetchTypesAndOptions();
                // Refresh global options controller
                OptionsController.to.refreshOptions();
                deleteSuccess = true;
                break;
              }
            }
          } catch (e) {
            continue;
          }
        }

        if (!deleteSuccess) {
          SnackbarUtils.showError('The Option is referenced somewhere!!');
        }
      } else {
        SnackbarUtils.showError('The Option is referenced somewhere!!');
      }
    } catch (e) {
      SnackbarUtils.showError('The Option is referenced somewhere!!');
    }
  }

  void showAddOptionDialog(String typeId, String typeName) {
    _newOptionController.clear();
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 600, // Reduced width for Add Option dialog
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add, color: Colors.black, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Add Option to $typeName',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _newOptionController,
                decoration: InputDecoration(
                  labelText: 'Option Name',
                  hintText: 'Enter option name...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                style: const TextStyle(color: Colors.black, fontSize: 16),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (_newOptionController.text.isNotEmpty) {
                        addOption(typeId, _newOptionController.text);
                        Get.back();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Add Option',
                      style: TextStyle(fontSize: 16),
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

  void showEditOptionDialog(String optionId, String currentName) {
    _editOptionController.text = currentName;
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 600, // Reduced width for Edit Option dialog
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit, color: Colors.blue, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Edit Option',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _editOptionController,
                decoration: InputDecoration(
                  labelText: 'Option Name',
                  hintText: 'Enter new option name...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                style: const TextStyle(color: Colors.black, fontSize: 16),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (_editOptionController.text.isNotEmpty) {
                        editOption(optionId, _editOptionController.text);
                        Get.back();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Update Option',
                      style: TextStyle(fontSize: 16),
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

  void showDeleteConfirmation(String optionId, String optionName) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 600, // Reduced width for Delete Option dialog
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 42,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Delete Option',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to delete "$optionName"?\nThis action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.black, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        // Close the dialog first
                        Get.back();
                        // Then perform the delete operation
                        await deleteOption(optionId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(fontSize: 16),
                      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _buildOptionsTab(),
    );
  }

  Widget _buildOptionsTab() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.black),
            const SizedBox(height: 16),
            Text(
              'Loading options...',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Container(
        color: Colors.grey.shade50,
        child: Column(
          children: [
            // Header Section (unchanged)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.settings,
                          color: Colors.black,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Master',
                              style: TextStyle(
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Add, edit, or delete options for different types',
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${typesData.length} Types',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Content Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: typesData.map((type) {
                  final options = type['options'] as List;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${typesData.indexOf(type) + 1}',
                            style: const TextStyle(
                              color: Colors.black,
                            ),
                          ),
                        ),
                        title: Text(
                          type['type_name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          '${options.length} options',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'ID: ${type['type_id']}',
                            style: const TextStyle(
                              fontSize: 14,
                            ),
                          ),
                        ),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Options ',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black,
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => showAddOptionDialog(type['type_id'].toString(), type['type_name']),
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('Add Option'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.black,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    List optionsSorted = List.from(options);
                                    optionsSorted.sort((a, b) => (a['option_name'] ?? '').compareTo(b['option_name'] ?? ''));
                                    return SizedBox(
                                      width: constraints.maxWidth,
                                      child: CustomTable(
                                        headers: const [
                                          'ID',
                                          'Option Name',
                                          'Actions',
                                        ],
                                        columnWidths: const {
                                          0: FixedColumnWidth(60),
                                          1: FlexColumnWidth(2),
                                          2: FixedColumnWidth(120),
                                        },
                                        rows: optionsSorted.map<List<Widget>>((option) {
                                          return [
                                            GestureDetector(
                                              onTap: () {
                                                showEditOptionDialog(option['option_id'].toString(), option['option_name'] ?? '');
                                              },
                                              child: Text(
                                                option['option_id'].toString(),
                                                style: const TextStyle(fontSize: 16),
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () {
                                                showEditOptionDialog(option['option_id'].toString(), option['option_name'] ?? '');
                                              },
                                              child: Text(
                                                option['option_name'] ?? '',
                                                style: const TextStyle(fontSize: 16),
                                              ),
                                            ),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.edit, color: Colors.blue, size: 24),
                                                  tooltip: 'Edit',
                                                  onPressed: () => showEditOptionDialog(option['option_id'].toString(), option['option_name'] ?? ''),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete, color: Colors.red, size: 24),
                                                  tooltip: 'Delete',
                                                  onPressed: () => showDeleteConfirmation(option['option_id'].toString(), option['option_name'] ?? ''),
                                                ),
                                              ],
                                            ),
                                          ];
                                        }).toList(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  // End of _buildOptionsTab
  }
}

class TypePage extends StatelessWidget {
  const TypePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Type',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: const Center(
        child: Text(
          'Type Page - Coming Soon',
          style: TextStyle(fontSize: 24, color: Colors.black),
        ),
      ),
    );
  }
}