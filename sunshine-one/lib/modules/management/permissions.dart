import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../utils/snackbar_message.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PermissionPage extends StatefulWidget {
  const PermissionPage({super.key});

  @override
  State<PermissionPage> createState() => _PermissionPageState();
}

class _PermissionPageState extends State<PermissionPage> {
  String? selectedEmployee;
  List<Map<String, dynamic>> employees = [];
  List<Map<String, dynamic>> filteredEmployees = [];
  bool isLoading = true;
  String? error;
  TextEditingController searchController = TextEditingController();
  FocusNode searchFocusNode = FocusNode();
  bool showEmployeeList = false;

  // Permission matrix data
  final List<String> permissions = ['Read', 'Create', 'Review', 'Approve'];
  List<String> departments = [];

  // Store permission states: Map<employeeId, Map<department, Map<permission, bool>>>
  Map<String, Map<String, Map<String, bool>>> permissionMatrix = {};
  bool isLoadingPermissions = false;

  // Role and Permission Bit Constants
  static const Map<int, String> roles = {
    0: 'ADMIN',
    1: 'HR',
    2: 'STORE',
    3: 'SALES',
    4: 'PURCHASE',
    5: 'DESIGN',
    6: 'MANAGEMENT',
    7: 'QUALITY',
    8: 'SERVICE',
    9: 'ACCOUNT',
    10: 'PRODUCTION',
    11: 'NEW_ROLE_11',
    12: 'NEW_ROLE_12',
    13: 'NEW_ROLE_13',
    14: 'NEW_ROLE_14',
    15: 'NEW_ROLE_15',
  };

  @override
  void initState() {
    super.initState();
    fetchEmployees();
    searchController.addListener(_onSearchChanged);
    searchFocusNode.addListener(() {
      if (searchFocusNode.hasFocus) {
        setState(() {
          showEmployeeList = true;
        });
      }
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    String query = searchController.text.toLowerCase();
    setState(() {
      filteredEmployees = employees
          .where((e) =>
              (e['id']?.toLowerCase().contains(query) ?? false) ||
              (e['name']?.toLowerCase().contains(query) ?? false))
          .toList();
      showEmployeeList = true;
    });
  }

  Future<void> fetchEmployees() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        setState(() {
          error = 'Authentication token not found';
          isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('https://1.sunshineiot.in/api/v2/hr/employee/id-name'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final empList = data
            .map(
              (e) => {
                'id': e['emp_id']?.toString() ?? '',
                'name': e['emp_name'] ?? '',
              },
            )
            .toList();
        setState(() {
          employees = empList;
          filteredEmployees = empList;
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Failed to load employees';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error: $e';
        isLoading = false;
      });
    }
  }

  Future<void> fetchPermissionMatrix(String employeeId) async {
    setState(() {
      isLoadingPermissions = true;
      error = null; // Clear any previous errors
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        setState(() {
          error = 'Authentication token not found';
          isLoadingPermissions = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse(
          'https://1.sunshineiot.in/api/v2/admin/role/permission-matrix/$employeeId',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Initialize departments list based on API response
        departments = data.keys.map((key) {
          int idx = int.tryParse(key) ?? -1;
          return roles[idx] ?? 'Dept${idx + 1}';
        }).toList();

        // Initialize permission matrix with consistent naming
        permissionMatrix[employeeId] = {};
        data.forEach((deptKey, permissionArray) {
          int idx = int.tryParse(deptKey) ?? -1;
          final deptName = roles[idx] ?? 'Dept${idx + 1}';
          permissionMatrix[employeeId]![deptName] = {};

          if (permissionArray is List) {
            for (
              int i = 0;
              i < permissions.length && i < permissionArray.length;
              i++
            ) {
              permissionMatrix[employeeId]![deptName]![permissions[i]] =
                  permissionArray[i] == 1;
            }
          }
        });

        setState(() {
          isLoadingPermissions = false;
        });
      } else {
        setState(() {
          error = 'Failed to load permissions (Status: ${response.statusCode})';
          isLoadingPermissions = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error loading permissions: $e';
        isLoadingPermissions = false;
      });
    }
  }

  void initializePermissionMatrix(String employeeId) {
    if (!permissionMatrix.containsKey(employeeId)) {
      fetchPermissionMatrix(employeeId);
    }
  }

  void togglePermission(
    String employeeId,
    String department,
    String permission,
  ) {
    setState(() {
      permissionMatrix[employeeId]![department]![permission] =
          !(permissionMatrix[employeeId]![department]![permission] ?? false);
    });
  }

  void toggleAllPermissions(String employeeId, String department, bool value) {
    setState(() {
      for (String permission in permissions) {
        permissionMatrix[employeeId]![department]![permission] = value;
      }
    });
  }

  void toggleAllDepartments(String employeeId, String permission, bool value) {
    setState(() {
      for (String dept in departments) {
        permissionMatrix[employeeId]![dept]![permission] = value;
      }
    });
  }

  Future<void> updatePermissions(String employeeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        setState(() {
          error = 'Authentication token not found';
        });
        return;
      }

      // Convert permission matrix to API format
      Map<String, List<int>> matrix = {};

      if (permissionMatrix.containsKey(employeeId)) {
        permissionMatrix[employeeId]!.forEach((deptName, permissions) {
          // Find the role ID from the department name
          int? roleId;
          roles.forEach((id, name) {
            if (name == deptName) {
              roleId = id;
            }
          });

          if (roleId != null) {
            List<int> permissionArray = [];
            for (String permission in this.permissions) {
              permissionArray.add(permissions[permission] == true ? 1 : 0);
            }

            // Only include roles where at least one permission is true
            if (permissionArray.any((p) => p == 1)) {
              matrix[roleId.toString()] = permissionArray;
            }
          }
        });
      }

      final requestBody = {
        'emp_id': int.tryParse(employeeId) ?? 0,
        'matrix': matrix,
      };

      debugPrint('API Request Body: ${json.encode(requestBody)}');

      final response = await http.put(
        Uri.parse(
          'https://1.sunshineiot.in/api/v2/admin/role/permission-matrix',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        debugPrint('API Response: $responseData');
        if (responseData['success'] == true) {
          if (responseData['rpm'] != null) {
            debugPrint('RPM value from API: ${responseData['rpm']}');
          }
          if (mounted) {
            SnackbarUtils.showSuccess(
              responseData['message'] ?? 'Permissions updated successfully!',
            );
          }
        } else {
          setState(() {
            error = responseData['message'] ?? 'Failed to update permissions';
          });
        }
      } else {
        setState(() {
          error =
              'Failed to update permissions (Status: ${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error updating permissions: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: screenSize.height),
          padding: EdgeInsets.symmetric(
            horizontal: isWeb ? screenSize.width * 0.05 : 16,
            vertical: isWeb ? 32 : 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                margin: const EdgeInsets.only(bottom: 32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.grey[50]!, Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.security,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Permission Management',
                            style: TextStyle(
                              fontSize: isWeb ? 34 : 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'Manage employee permissions across departments',
                            style: TextStyle(
                              fontSize: isWeb ? 18 : 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Loading and Error States
              if (isLoading)
                SizedBox(
                  width: double.infinity,
                  height: 200,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading employees...'),
                      ],
                    ),
                  ),
                )
              else if (error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.only(bottom: 32),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red[600],
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Employee Selection Section with User-Friendly Search and List
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      margin: const EdgeInsets.only(bottom: 32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.person_search,
                                color: Colors.black,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Select Employee',
                                style: TextStyle(
                                  fontSize: isWeb ? 24 : 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                showEmployeeList = true;
                              });
                              FocusScope.of(context).requestFocus(searchFocusNode);
                            },
                            child: AbsorbPointer(
                              child: DropdownButtonFormField<String>(
                                value: selectedEmployee,
                                decoration: InputDecoration(
                                  hintText: 'Choose an employee...',
                                  hintStyle: const TextStyle(color: Colors.grey),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Colors.black,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 16,
                                  ),
                                ),
                                dropdownColor: Colors.white,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                ),
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.black,
                                ),
                                items: employees.map((employee) {
                                  return DropdownMenuItem<String>(
                                    value: employee['id'],
                                    child: Text(
                                      '${employee['id']} - ${employee['name']}',
                                      style: const TextStyle(color: Colors.black),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (_) {}, // Disabled, handled by list below
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Search Field
                          if (showEmployeeList)
                            Column(
                              children: [
                                TextField(
                                  controller: searchController,
                                  focusNode: searchFocusNode,
                                  decoration: InputDecoration(
                                    hintText: 'Search employee...',
                                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Colors.black, width: 2),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  onTap: () {
                                    setState(() {
                                      showEmployeeList = true;
                                    });
                                  },
                                ),
                                const SizedBox(height: 8),
                                // Filtered Employee List
                                Container(
                                  constraints: const BoxConstraints(maxHeight: 200),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: filteredEmployees.length,
                                    itemBuilder: (context, index) {
                                      final emp = filteredEmployees[index];
                                      return ListTile(
                                        title: Text('${emp['id']} - ${emp['name']}', style: const TextStyle(color: Colors.black)),
                                        onTap: () {
                                          setState(() {
                                            selectedEmployee = emp['id'];
                                            searchController.clear();
                                            showEmployeeList = false;
                                          });
                                          fetchPermissionMatrix(emp['id']);
                                          FocusScope.of(context).unfocus();
                                        },
                                        selected: selectedEmployee == emp['id'],
                                        selectedTileColor: Colors.grey[200],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    // Permission Matrix Section
                    if (selectedEmployee != null) ...[
                      LayoutBuilder(
                        builder: (context, constraints) {
                          // Set a fixed width for each column for uniformity
                          const double colWidth = 188;
                          final double tableWidth = (permissions.length + 2) * colWidth; // +2 for Department and All
                          return Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey[300]!, width:1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Matrix Header
                                Container(
                                  padding: const EdgeInsets.all(28),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(20),
                                      topRight: Radius.circular(20),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.table_chart,
                                        color: Colors.black,
                                        size: 28,
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        'Permission Matrix',
                                        style: TextStyle(
                                          fontSize: isWeb ? 26 : 22,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Matrix Table
                                Scrollbar(
                                  thumbVisibility: true,
                                  thickness: 8,
                                  radius: const Radius.circular(8),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(minWidth: tableWidth),
                                      child: DataTable(
                                        columnSpacing: 0,
                                        horizontalMargin: 0,
                                        headingRowColor: WidgetStateProperty.all(
                                          Colors.grey[100],
                                        ),
                                        dataRowMinHeight: 56,
                                        dataRowMaxHeight: 64,
                                        border: TableBorder.symmetric(
                                          inside: BorderSide(color: Colors.grey[200]!, width: 1),
                                        ),
                                        columns: [
                                          DataColumn(
                                            label: Container(
                                              width: colWidth,
                                              alignment: Alignment.center,
                                              child: Text(
                                                'Department',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                  fontSize: isWeb ? 18 : 16,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                          ...permissions.map(
                                            (permission) => DataColumn(
                                              label: Container(
                                                width: colWidth,
                                                alignment: Alignment.center,
                                                child: Text(
                                                  permission,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black,
                                                    fontSize: isWeb ? 18 : 16,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Container(
                                              width: colWidth,
                                              alignment: Alignment.center,
                                              child: Text(
                                                'All',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                  fontSize: isWeb ? 18 : 16,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                        ],
                                        rows: departments.map((dept) {
                                          return DataRow(
                                            color: WidgetStateProperty.resolveWith<Color?>((states) {
                                              if (states.contains(WidgetState.hovered)) {
                                                return Colors.grey[100];
                                              }
                                              if (selectedEmployee != null && permissionMatrix[selectedEmployee] != null && permissionMatrix[selectedEmployee]![dept] != null && permissionMatrix[selectedEmployee]![dept]!.values.any((v) => v)) {
                                                return Colors.yellow[50];
                                              }
                                              return null;
                                            }),
                                            cells: [
                                              DataCell(
                                                Container(
                                                  width: colWidth,
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    dept,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.black,
                                                      fontSize: isWeb ? 17 : 15,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ),
                                              ...permissions.map(
                                                (permission) => DataCell(
                                                  Container(
                                                    width: colWidth,
                                                    alignment: Alignment.center,
                                                    child: Transform.scale(
                                                      scale: 1.3,
                                                      child: Checkbox(
                                                        value: permissionMatrix[selectedEmployee]![dept]![permission] ?? false,
                                                        onChanged: (value) {
                                                          togglePermission(
                                                            selectedEmployee!,
                                                            dept,
                                                            permission,
                                                          );
                                                        },
                                                        activeColor: Colors.black,
                                                        checkColor: Colors.white,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Container(
                                                  width: colWidth,
                                                  alignment: Alignment.center,
                                                  child: Transform.scale(
                                                    scale: 1.3,
                                                    child: Checkbox(
                                                      value: permissions.every(
                                                        (permission) => permissionMatrix[selectedEmployee]![dept]![permission] ?? false,
                                                      ),
                                                      onChanged: (value) {
                                                        toggleAllPermissions(
                                                          selectedEmployee!,
                                                          dept,
                                                          value ?? false,
                                                        );
                                                      },
                                                      activeColor: Colors.black,
                                                      checkColor: Colors.white,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      // Action Buttons Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  debugPrint(
                                    'Save Permissions button clicked!',
                                  );
                                  if (selectedEmployee != null) {
                                    debugPrint(
                                      'Selected Employee ID: $selectedEmployee',
                                    );
                                    updatePermissions(selectedEmployee!);
                                  } else {
                                    debugPrint('No employee selected!');
                                  }
                                },
                                icon: const Icon(
                                  Icons.save,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                label: Text(
                                  'Save Permissions',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isWeb ? 16 : 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                    horizontal: 20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                // Reset all permissions
                                setState(() {
                                  if (selectedEmployee != null) {
                                    initializePermissionMatrix(
                                      selectedEmployee!,
                                    );
                                  }
                                });
                              },
                              icon: Icon(
                                Icons.refresh,
                                color: Colors.black,
                                size: 20,
                              ),
                              label: Text(
                                'Reset',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: isWeb ? 16 : 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[200],
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 22,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Empty State Section
                      Container(
                        width: double.infinity,
                        height: 300,
                        padding: const EdgeInsets.all(48),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_search,
                              size: 78,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Select an Employee',
                              style: TextStyle(
                                fontSize: isWeb ? 24 : 20,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Choose an employee from the dropdown above\nto manage their permissions.',
                              style: TextStyle(
                                fontSize: isWeb ? 16 : 14,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
