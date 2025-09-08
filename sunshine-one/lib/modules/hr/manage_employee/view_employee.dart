import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:myoffice_sunshine/utils/standard_table_style.dart';
import 'package:myoffice_sunshine/utils/widgets/action_icon.dart';
import 'package:myoffice_sunshine/utils/snackbar_message.dart';
import '../../../models/employee_model.dart';
import '../../../services/employee_service.dart';
import '../../../controllers/options_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:http/http.dart' as http;
import 'package:excel/excel.dart' as excel;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:universal_html/html.dart' as html;
// ignore: unused_import
// import 'package:collection/collection.dart';

class ViewEmployee extends StatefulWidget {
  final void Function(int empId)? onEdit;
  final bool showEditButtons;

  const ViewEmployee({super.key, this.onEdit, this.showEditButtons = false});

  @override
  State<ViewEmployee> createState() => _ViewEmployeeState();
}

class _ViewEmployeeState extends State<ViewEmployee> {
  List<Employee> employees = [];
  bool isLoading = true;
  bool _isDataReady = false;
  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();
  final EmployeeService employeeService = EmployeeService();
  final OptionsController optionsController = Get.find<OptionsController>();

  // Add toggle state
  bool showActive = true; // true = Active, false = Inactive

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() {
      isLoading = true;
      _isDataReady = false;
    });
    // Wait for options to be loaded
    if (!optionsController.hasData) {
      await optionsController.fetchOptions();
    }
    // Now fetch employees
    await fetchEmployeeDetails();
  }

  Future<void> fetchEmployeeDetails() async {
    setState(() {
      isLoading = true;
      _isDataReady = false;
    });
    try {
      final data = await employeeService.fetchEmployees();
      setState(() {
        employees = data ?? [];
        isLoading = false;
        _isDataReady = true;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        _isDataReady = false;
      });
      if (!mounted) return;
      SnackbarUtils.showError('Error: ${e.toString()}');
    }
  }

  // Filtered employees by search and active/inactive toggle
  List<Employee> get filteredEmployees {
    List<Employee> filtered = employees;
    // Filter by active/inactive
    filtered = filtered.where((employee) {
      final status = _getStatus(employee.empActiveStatus);
      if (showActive) {
        return status == 'Yes';
      } else {
        return status == 'No';
      }
    }).toList();
    // Filter by search
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((employee) {
        final name = employee.empName.toLowerCase();
        final id = employee.empId.toString().toLowerCase();
        return name.contains(searchQuery.toLowerCase()) ||
            id.contains(searchQuery.toLowerCase());
      }).toList();
    }
    return filtered;
  }

  void showEmployeeDetailsModal(Employee employee) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 350),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Employee Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black,
                      ),
                    ),
                    Row(
                      children: [
                        Tooltip(
                          message: 'Download PDF',
                          child: IconButton(
                            icon: Icon(
                              Icons.download,
                              size: 20,
                              color: Colors.black87,
                            ),
                            onPressed: () async {
                              await _downloadEmployeePdf(employee);
                            },
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.black),
                          onPressed: () => Get.back(),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: employee.empPassportSizePhoto.isNotEmpty
                        ? NetworkImage(employee.empPassportSizePhoto)
                        : null,
                    child: employee.empPassportSizePhoto.isEmpty
                        ? Icon(Icons.person, size: 40, color: Colors.grey[700])
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                _detailRow('ID', employee.empId.toString()),
                _detailRow('Name', employee.empName),
                _detailRow(
                  'Designation',
                  _getDesignation(employee.empDesignation),
                ),
                _detailRow('Phone', employee.empPhoneNo),
                _detailRow('Email', employee.empEmailId),
                _detailRow('Address', employee.empCurrentAddress),
                _detailRow('Date of Birth', _formatDate(employee.empDob)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _downloadEmployeePdf(Employee employee) async {
    final pdf = pw.Document();
    Uint8List? employeeImageBytes;
    if (employee.empPassportSizePhoto.isNotEmpty) {
      try {
        final response = await http.get(
          Uri.parse(employee.empPassportSizePhoto),
        );
        if (response.statusCode == 200) {
          employeeImageBytes = response.bodyBytes;
        } else {
          employeeImageBytes = null;
        }
      } catch (e) {
        employeeImageBytes = null;
      }
    }
    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Employee Details',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 16),
                    if (employeeImageBytes != null)
                      pw.Container(
                        width: 100,
                        height: 100,
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          border: pw.Border.all(
                            color: PdfColors.grey,
                            width: 2,
                          ),
                        ),
                        child: pw.ClipOval(
                          child: pw.Image(
                            pw.MemoryImage(employeeImageBytes),
                            fit: pw.BoxFit.cover,
                          ),
                        ),
                      )
                    else
                      pw.Container(
                        width: 100,
                        height: 100,
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          color: PdfColors.grey300,
                        ),
                        child: pw.Center(
                          child: pw.Icon(
                            pw.IconData(0xe491),
                            size: 48,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ),
                    pw.SizedBox(height: 20),
                  ],
                ),
              ),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Table(
                columnWidths: {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(4),
                },
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                children: [
                  _pdfRow('ID', employee.empId.toString()),
                  _pdfRow('Name', employee.empName),
                  _pdfRow(
                    'Designation',
                    _getDesignation(employee.empDesignation),
                  ),
                  _pdfRow('Position', _getPosition(employee.empPosition)),
                  _pdfRow(
                    'Attendance Type',
                    _getAttendanceType(employee.empAttendanceType),
                  ),
                  _pdfRow(
                    'Active Status',
                    _getStatusText(_getStatus(employee.empActiveStatus)),
                  ),
                  _pdfRow('Phone', employee.empPhoneNo),
                  _pdfRow('Email', employee.empEmailId),
                  _pdfRow('Address', employee.empCurrentAddress),
                  _pdfRow('Date of Birth', _formatDate(employee.empDob)),
                  _pdfRow(
                    'Date of Celebration',
                    _formatDate(employee.empDocel),
                  ),
                  _pdfRow(
                    'Blood Group',
                    optionsController
                            .getOptionByTypeAndId(
                              OptionsController.typeBloodGroup,
                              employee.empBloodGroup,
                            )
                            ?.optionName ??
                        '',
                  ),
                  _pdfRow(
                    'Qualification',
                    optionsController
                            .getOptionByTypeAndId(
                              OptionsController.typeQualification,
                              employee.empQualification,
                            )
                            ?.optionName ??
                        '',
                  ),
                  _pdfRow('Date of Joining', employee.empDateOfJoining),
                  _pdfRow('Aadhar', employee.empAadhar),
                  _pdfRow('PAN', employee.empPan),
                  _pdfRow('Bank Name', employee.empBankName),
                  _pdfRow('Bank Account', employee.empBankAccount),
                  _pdfRow('Bank Branch', employee.empBankBranch),
                  _pdfRow('IFSC', employee.empBankIfsc),
                  _pdfRow('Medical History', employee.empMedicalHistory),
                  _pdfRow('Note', employee.empNote),
                ],
              ),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Employee_${employee.empId}_${employee.empName}.pdf',
    );
  }

  pw.TableRow _pdfRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: pw.Text(value, style: pw.TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  String _getDesignation(int designationId) {
    final option = optionsController.getOptionByTypeAndId(
      OptionsController.typeDesignation,
      designationId,
    );
    if (option == null) return 'Unknown';
    // Remove 'Level xx' from designation name if present
    final regex = RegExp(r'Level\s*\d+\s*-?\s*', caseSensitive: false);
    final cleaned = option.optionName.replaceAll(regex, '').trim();
    return cleaned.isEmpty ? option.optionName : cleaned;
  }

  String _getPosition(int positionId) {
    final option = optionsController.getOptionByTypeAndId(
      OptionsController.typePosition,
      positionId,
    );
    return option?.optionName ?? 'Unknown';
  }

  String _getAttendanceType(int attendanceTypeId) {
    final option = optionsController.getOptionByTypeAndId(
      OptionsController.typeAttendanceType,
      attendanceTypeId,
    );
    return option?.optionName ?? 'Unknown';
  }

  String _getStatus(int statusId) {
    final option = optionsController.getOptionByTypeAndId(
      OptionsController.typeUniversalYesNo,
      statusId,
    );
    return option?.optionName ?? 'Unknown';
  }

  String _getStatusValue(String? value) {
    if (value == null) return 'Unknown';
    final val = value.toLowerCase();
    if (val == 'yes' || val == '1') return 'Yes';
    if (val == 'no' || val == '0') return 'No';
    return 'Unknown';
  }

  String _getStatusText(String? value) {
    final status = _getStatusValue(value);
    if (status == 'Yes') return 'Active';
    if (status == 'No') return 'Inactive';
    return 'Unknown';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildMobileEmployeeCard(Employee employee) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: employee.empPassportSizePhoto.isNotEmpty
                      ? NetworkImage(employee.empPassportSizePhoto)
                      : null,
                  child: employee.empPassportSizePhoto.isEmpty
                      ? const Icon(Icons.person, size: 24, color: Colors.grey)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.empName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18, // increased by 2
                          color: Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'ID: ${employee.empId}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Position: ${_getPosition(employee.empPosition)}',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _getDesignation(employee.empDesignation),
              style: const TextStyle(color: Colors.black87, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.visibility, size: 14),
                    label: const Text('View', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    onPressed: () => showEmployeeDetailsModal(employee),
                  ),
                ),
                if (widget.showEditButtons) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit, size: 14),
                      label: const Text('Edit', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Colors.black),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                      onPressed: widget.onEdit != null
                          ? () => widget.onEdit!(employee.empId)
                          : null,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    if (!_isDataReady) {
      return const Center(child: CircularProgressIndicator());
    }

    return Material(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(isWeb ? 24 : 16),
        child: Obx(
          () => isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.black),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Employee Details',
                            style: TextStyle(
                              fontSize: 20, // smaller font
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          PopupMenuButton<String>(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            offset: const Offset(0, 40),
                            elevation: 8,
                            color: Colors.white,
                            onSelected: (value) async {
                              if (value == 'add') {
                                Get.toNamed(
                                  '/dashboard/hr/manage_employee/add',
                                );
                              } else if (value == 'export') {
                                await _exportAllEmployeesToExcel();
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'add',
                                textStyle: const TextStyle(color: Colors.black),
                                child: Row(
                                  children: const [
                                    Icon(Icons.add, color: Colors.black),
                                    SizedBox(width: 8),
                                    Text(
                                      'Add Employee',
                                      style: TextStyle(color: Colors.black),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'export',
                                textStyle: const TextStyle(color: Colors.black),
                                child: Row(
                                  children: const [
                                    Icon(Icons.download, color: Colors.black),
                                    SizedBox(width: 8),
                                    Text(
                                      'Export All Employees',
                                      style: TextStyle(color: Colors.black),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.menu,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Actions',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Search Bar and Active/Inactive Toggle in one row
                      Row(
                        children: [
                          // Expanded search bar
                          Expanded(
                            child: TextField(
                              controller: searchController,
                              decoration: InputDecoration(
                                hintText: 'Search by name or ID',
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Colors.black,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 0,
                                  horizontal: 16,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.black),
                                ),
                                hintStyle: TextStyle(color: Colors.grey[600]),
                              ),
                              style: TextStyle(color: Colors.black),
                              onChanged: (value) {
                                setState(() {
                                  searchQuery = value;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Toggle switch for Active/Inactive
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: showActive
                                  ? Colors.green.shade50
                                  : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: showActive
                                    ? Colors.green.shade200
                                    : Colors.red.shade200,
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  showActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    color: showActive
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Transform.scale(
                                  scale: 0.8,
                                  child: CupertinoSwitch(
                                    value: showActive,
                                    activeTrackColor: Colors.green,
                                    inactiveTrackColor: Colors.red.shade300,
                                    onChanged: (val) {
                                      setState(() {
                                        showActive = val;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (isMobile)
                        ...filteredEmployees.map(_buildMobileEmployeeCard)
                      else
                        SizedBox(
                          width: double.infinity,
                          child: // Use your CustomTable here instead of DataTable
                          CustomTable(
                            headers: [
                              "ID",
                              "Name",
                              "Designation",
                              "Position",
                              "Attendance Type",
                              "Active Status",
                              widget.showEditButtons ? "Actions" : "Action",
                            ],
                            rows: filteredEmployees.map((employee) {
                              return [
                                // ID
                                Text(employee.empId.toString()),

                                // Name + Avatar
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Colors.grey[200],
                                      backgroundImage:
                                          employee
                                              .empPassportSizePhoto
                                              .isNotEmpty
                                          ? NetworkImage(
                                              employee.empPassportSizePhoto,
                                            )
                                          : null,
                                      child:
                                          employee.empPassportSizePhoto.isEmpty
                                          ? const Icon(
                                              Icons.person,
                                              size: 12,
                                              color: Colors.grey,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Tooltip(
                                        message: employee.empName,
                                        child: Text(
                                          employee.empName,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // Designation
                                Text(_getDesignation(employee.empDesignation)),

                                // Position
                                Text(_getPosition(employee.empPosition)),

                                // Attendance Type
                                Text(
                                  _getAttendanceType(
                                    employee.empAttendanceType,
                                  ),
                                ),

                                // Active Status
                                if (_getStatus(employee.empActiveStatus) ==
                                    'Yes')
                                  statusChip(
                                    value: 'Active',
                                    color: Colors.green,
                                  )
                                else
                                  statusChip(
                                    value: 'Inactive',
                                    color: Colors.red,
                                  ),
                                // Actions
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    viewIcon(
                                      tooltip: 'View details',
                                      onPressed: () =>
                                          showEmployeeDetailsModal(employee),
                                    ),
                                    const SizedBox(width: 4),
                                    if (widget.showEditButtons)
                                      editIcon(
                                        tooltip: 'Edit details',
                                        onPressed: () => Get.toNamed(
                                          '/dashboard/hr/manage_employee/edit/${employee.empId}',
                                        ),
                                      ),
                                  ],
                                ),
                              ];
                            }).toList(),
                            columnWidths: const {
                              0: FixedColumnWidth(90), // ID fixed
                              6: FixedColumnWidth(90), // Actions fixed
                              // All others auto-share remaining space
                              1: FlexColumnWidth(1.3),
                              2: FlexColumnWidth(1),
                              3: FlexColumnWidth(1),
                              4: FlexColumnWidth(1),
                              5: FlexColumnWidth(1),
                            },
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _exportAllEmployeesToExcel() async {
    try {
      // Fetch all employees (force refresh)
      final allEmployees = await employeeService.refreshEmployees();
      if (allEmployees == null || allEmployees.isEmpty) {
        if (mounted) {
          SnackbarUtils.showError('No employees found to export.');
          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(content: Text('No employees found to export.')),
          // );
        }
        return;
      }
      final excelFile = excel.Excel.createExcel();
      final defaultSheetName = excelFile.getDefaultSheet();
      final sheet = excelFile[defaultSheetName ?? 'Sheet1'];
      excelFile.setDefaultSheet(defaultSheetName ?? 'Sheet1');

      // Header row with all attributes
      sheet.appendRow([
        'ID',
        'Name',
        'Email',
        'Telegram ID',
        'Phone',
        'Emergency No 1',
        'Emergency No 2',
        'Aadhar',
        'PAN',
        'Driving License',
        'Current Address',
        'Permanent Address',
        'Date of Birth',
        'Date of Celebration',
        'Blood Group',
        'Qualification',
        'Passport No',
        'Passport Valid Till',
        'Bank Name',
        'Bank Account',
        'Bank Branch',
        'Bank IFSC',
        'Date of Joining',
        'Medical History',
        'Passport Size Photo',
        'Full View Photo',
        'Designation',
        'Reporting To',
        'Position',
        'Is Punch Allowed',
        'Attendance Type',
        'Salary',
        'Is OT Applicable',
        'No. of Leaves',
        'Work From Home',
        'Left Date',
        'PF No',
        'ESIC No',
        'Petrol Allowance',
        'Mobile Allowance',
        'Kid Education',
        'Variable',
        'Active Status',
        'Location',
        'Note',
        'Contractor',
        'Roles/Permissions',
      ]);

      // Data rows - one row per employee with all attributes
      for (final emp in allEmployees) {
        sheet.appendRow([
          emp.empId,
          emp.empName,
          emp.empEmailId,
          emp.empTelegramId,
          emp.empPhoneNo,
          emp.empEmergencyNo01,
          emp.empEmergencyNo02,
          emp.empAadhar,
          emp.empPan,
          emp.empDrivingLicense,
          emp.empCurrentAddress,
          emp.empPermanentAddress,
          _formatDate(emp.empDob),
          _formatDate(emp.empDocel),
          optionsController
                  .getOptionByTypeAndId(
                    OptionsController.typeBloodGroup,
                    emp.empBloodGroup,
                  )
                  ?.optionName ??
              '',
          optionsController
                  .getOptionByTypeAndId(
                    OptionsController.typeQualification,
                    emp.empQualification,
                  )
                  ?.optionName ??
              '',
          emp.empPassportNo,
          emp.empPassportValidTill,
          emp.empBankName,
          emp.empBankAccount,
          emp.empBankBranch,
          emp.empBankIfsc,
          emp.empDateOfJoining,
          emp.empMedicalHistory,
          emp.empPassportSizePhoto,
          emp.empFullViewPhoto,
          _getDesignation(emp.empDesignation),
          getEmployeeNameById(emp.empReportingTo),
          _getPosition(emp.empPosition),
          optionsController
                  .getOptionByTypeAndId(
                    OptionsController.typeUniversalYesNo,
                    emp.empIsPunchAllowed,
                  )
                  ?.optionName ??
              '',
          _getAttendanceType(emp.empAttendanceType),
          emp.empSalary,
          emp.empIsOtApplicable == 1 ? 'Yes' : 'No',
          emp.empNoLeaves,
          emp.empWorkFromHome == 1 ? 'Yes' : 'No',
          emp.empLeftDate,
          emp.empPfNo,
          emp.empEsicNo,
          emp.empPetrolAllowance ?? '',
          emp.empMobileAllowance ?? '',
          emp.empKidEducation ?? '',
          emp.empVariable ?? '',
          _getStatusText(_getStatus(emp.empActiveStatus)),
          emp.empLocation,
          emp.empNote,
          getEmployeeNameById(emp.empContractor),
          emp.rolesPermissions,
        ]);
      }

      final fileBytes = excelFile.encode();
      if (fileBytes == null) {
        if (mounted) {
          SnackbarUtils.showError('Failed to generate Excel file.');
          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(content: Text('Failed to generate Excel file.')),
          // );
        }
        return;
      }
      // Download logic for web and mobile/desktop
      if (kIsWeb) {
        // For web, use universal_html
        final blob = html.Blob([
          fileBytes,
        ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', 'Employees.xlsx')
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // For mobile/desktop, use path_provider and file_saver
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/Employees.xlsx');
        await file.writeAsBytes(fileBytes, flush: true);
        if (mounted) {
          SnackbarUtils.showInfo('Excel file saved to ${file.path}');
          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(content: Text('Excel file saved: ${file.path}')),
          // );
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError('Error exporting to Excel: $e');
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Error exporting to Excel: $e')),
        // );
      }
    }
  }

  String? getEmployeeNameById(dynamic id) {
    if (id == null) return '';
    final emp = employees.firstWhereOrNull(
      (e) => e.empId.toString() == id.toString(),
    );
    return emp?.empName ?? '';
  }
}
