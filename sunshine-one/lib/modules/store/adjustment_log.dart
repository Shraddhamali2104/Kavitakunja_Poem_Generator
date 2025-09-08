import 'dart:convert';
import 'dart:math' as math;
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../controllers/options_controller.dart';
import '../../utils/snackbar_message.dart';

class AdjustmentLog extends StatefulWidget {
  const AdjustmentLog({super.key});

  @override
  State<AdjustmentLog> createState() => _AdjustmentLogState();
}

class _AdjustmentLogState extends State<AdjustmentLog> {
  final OptionsController optionsController = Get.find();
  bool isLoading = true;
  String? jwtToken;
  List<dynamic> adjustmentList = [];

  // State variables for manual pagination and search
  int page = 1;
  int limit = 20;
  int totalPages = 1;
  int total = 0;
  String search = '';
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadTokenAndFetch();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  /// Loads the JWT token from shared preferences and then fetches the data.
  Future<void> loadTokenAndFetch() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("jwt_token");

    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() => isLoading = false);
      }
      SnackbarUtils.showError("JWT token not found");
      return;
    }

    jwtToken = token;
    await fetchAdjustmentData();
  }

  /// Fetches adjustment data from the API with support for pagination and search.
  Future<void> fetchAdjustmentData() async {
    if (jwtToken == null) {
      SnackbarUtils.showError("JWT token not found");
      return;
    }

    if (mounted) {
      setState(() => isLoading = true);
    }

    // Construct the API URL with dynamic parameters for page, limit, and search query.
    final url = Uri.parse(
      "https://1.sunshineiot.in/api/v2/store/stock/adjust/all?page=$page&limit=$limit&search=$search&status=&store_id=",
    );

    try {
      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $jwtToken",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            adjustmentList = jsonResponse['data'] ?? [];
            total = jsonResponse['total'] ?? 0;
            page = jsonResponse['page'] ?? 1;
            limit = jsonResponse['limit'] ?? 20;
            totalPages = jsonResponse['totalPages'] ?? 1;
            isLoading = false;
          });
        }
        SnackbarUtils.showSuccess("Data loaded successfully");
      } else {
        if (mounted) {
          setState(() => isLoading = false);
        }
        SnackbarUtils.showError('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
      SnackbarUtils.showError("Error fetching data: $e");
    }
  }

  /// Handles search query submission.
  void onSearchChanged(String value) {
    setState(() {
      search = value;
      page = 1; // Reset to the first page when a new search is performed.
    });
    fetchAdjustmentData();
  }

  /// Navigates to a specific page.
  void goToPage(int newPage) {
    if (newPage < 1 || newPage > totalPages) return;
    setState(() {
      page = newPage;
    });
    fetchAdjustmentData();
  }

  /// Fetches detailed information for a single adjustment and shows it in a dialog.
  Future<void> fetchAdjustmentDetails(int adjustmentId) async {
    final url =
        "https://1.sunshineiot.in/api/v2/store/stock/adjust/$adjustmentId";

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $jwtToken",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        _showAdjustmentDetailsDialog(jsonResponse);
      } else {
        SnackbarUtils.showError(
          'Failed to load adjustment details: ${response.statusCode}',
        );
      }
    } catch (e) {
      SnackbarUtils.showError("Error fetching adjustment details: $e");
    }
  }

  /// Displays a dialog with a detailed table of adjustment information and items.
  void _showAdjustmentDetailsDialog(Map<String, dynamic> adjustmentData) {
    final data = adjustmentData['data'];
    final items = adjustmentData['items'] as List<dynamic>;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Adjustment Details',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Adjustment Information Table
                        Text(
                          'Adjustment Information',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Table(
                              columnWidths: const {
                                0: FlexColumnWidth(1),
                                1: FlexColumnWidth(2),
                              },
                              children: [
                                _buildTableRow('ID', data['id'].toString()),
                                _buildTableRow(
                                  'Adjustment No',
                                  data['adjustment_no'] ?? 'N/A',
                                ),
                                _buildTableRow(
                                  'Store',
                                  data['store_name'] ?? 'N/A',
                                ),
                                _buildTableRow(
                                  'Status',
                                  _mapStatus(data['status']),
                                ),
                                _buildTableRow(
                                  'Total Items',
                                  data['total_items'].toString(),
                                ),
                                _buildTableRow(
                                  'Created By',
                                  data['created_by_name'] ?? 'N/A',
                                ),
                                _buildTableRow(
                                  'Created At',
                                  _formatDate(data['created_at']),
                                ),
                                _buildTableRow(
                                  'Reviewed By',
                                  data['reviewed_by_name'] ?? 'N/A',
                                ),
                                _buildTableRow(
                                  'Reviewed At',
                                  _formatDate(data['reviewed_at']),
                                ),
                                _buildTableRow(
                                  'Approved By',
                                  data['approved_by_name'] ?? 'N/A',
                                ),
                                _buildTableRow(
                                  'Approved At',
                                  _formatDate(data['approved_at']),
                                ),
                                _buildTableRow(
                                  'Remarks',
                                  data['remarks'] ?? 'N/A',
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Items Table
                        Text(
                          'Adjustment Items',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('ID')),
                                  DataColumn(label: Text('Item Type ID')),
                                  DataColumn(label: Text('Item ID')),
                                  DataColumn(label: Text('Initial Qty')),
                                  DataColumn(label: Text('Adjustment Qty')),
                                  DataColumn(label: Text('Description')),
                                ],
                                rows: items.map((item) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(item['id'].toString())),
                                      DataCell(
                                        Text(item['item_type_id'].toString()),
                                      ),
                                      DataCell(
                                        Text(item['item_id'].toString()),
                                      ),
                                      DataCell(
                                        Text(item['init_qty'].toString()),
                                      ),
                                      DataCell(Text(item['qty'].toString())),
                                      DataCell(
                                        SizedBox(
                                          width: 150,
                                          child: Text(
                                            item['description'] ?? 'N/A',
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2,
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
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () => Get.back(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Helper function to build a table row for the details dialog.
  TableRow _buildTableRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(value),
        ),
      ],
    );
  }

  /// Formats an ISO 8601 date string to a more readable format.
  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final DateTime date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  /// Maps a numeric status code to a human-readable string.
  String _mapStatus(dynamic status) {
    switch (status) {
      case 0:
        return "Created";
      case 1:
        return "Reviewed";
      case 2:
        return "Rejected by Reviewer";
      case 3:
        return "Approved";
      case 4:
        return "Rejected by Approver";
      default:
        return status.toString();
    }
  }

  /// Provides a color for each status code.
  Color _getStatusColor(int status) {
    switch (status) {
      case 0:
        return Colors.orange; // Created
      case 1:
        return Colors.blue; // Reviewed
      case 2:
        return Colors.red; // Rejected by Reviewer
      case 3:
        return Colors.green; // Approved
      case 4:
        return Colors.red; // Rejected by Approver
      default:
        return Colors.orange; // Default
    }
  }

  /// Shows a confirmation dialog for reviewing an adjustment.
  void _showReviewDialog(int adjustmentId, bool isApprove) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isApprove ? 'Review Adjustment' : 'Reject Review'),
        content: Text(
          'Are you sure you want to ${isApprove ? 'review' : 'reject the review of'} this adjustment?',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('No')),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await _reviewAdjustment(adjustmentId, isApprove ? 1 : 0);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  /// Shows a confirmation dialog for approving an adjustment.
  void _showApproveDialog(int adjustmentId, bool isApprove) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isApprove ? 'Approve Adjustment' : 'Reject Approval'),
        content: Text(
          'Are you sure you want to ${isApprove ? 'approve' : 'reject the approval of'} this adjustment?',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('No')),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await _approveAdjustment(adjustmentId, isApprove ? 1 : 0);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  /// Calls the API to review an adjustment.
  Future<void> _reviewAdjustment(int adjustmentId, int flag) async {
    try {
      final response = await http.patch(
        Uri.parse(
          'https://1.sunshineiot.in/api/v2/store/stock/adjust/$adjustmentId/review/$flag',
        ),
        headers: {
          "Authorization": "Bearer $jwtToken",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          SnackbarUtils.showSuccess(
            jsonResponse['message'] ?? 'Adjustment status updated',
          );
          await fetchAdjustmentData(); // Refresh the list
        } else {
          SnackbarUtils.showError(
            jsonResponse['message'] ?? 'Failed to review adjustment',
          );
        }
      } else {
        SnackbarUtils.showError(
          'Failed to review adjustment: ${response.statusCode}',
        );
      }
    } catch (e) {
      SnackbarUtils.showError("Error reviewing adjustment: $e");
    }
  }

  /// Calls the API to approve an adjustment.
  Future<void> _approveAdjustment(int adjustmentId, int flag) async {
    try {
      final response = await http.patch(
        Uri.parse(
          'https://1.sunshineiot.in/api/v2/store/stock/adjust/$adjustmentId/approve/$flag',
        ),
        headers: {
          "Authorization": "Bearer $jwtToken",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          SnackbarUtils.showSuccess(
            jsonResponse['message'] ?? 'Adjustment status updated',
          );
          await fetchAdjustmentData(); // Refresh the list
        } else {
          SnackbarUtils.showError(
            jsonResponse['message'] ?? 'Failed to approve adjustment',
          );
        }
      } else {
        SnackbarUtils.showError(
          'Failed to approve adjustment: ${response.statusCode}',
        );
      }
    } catch (e) {
      SnackbarUtils.showError("Error approving adjustment: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataSource = AdjustmentDataSource(
      adjustmentList,
      optionsController,
      _mapStatus,
      _getStatusColor,
      fetchAdjustmentDetails,
      _showReviewDialog,
      _showApproveDialog,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Adjustment Log')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search adjustments...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 0,
                      ),
                    ),
                    onSubmitted: onSearchChanged,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => onSearchChanged(searchController.text),
                  child: const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Loading or Content
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : adjustmentList.isEmpty
                  ? const Center(child: Text("No data available"))
                  : Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: PaginatedDataTable(
                          header: Text('Adjustment Records (Total: $total)'),
                          columns: const [
                            DataColumn(label: Text("ID")),
                            DataColumn(label: Text("Adjustment No")),
                            DataColumn(label: Text("Total Items")),
                            DataColumn(label: Text("Store")),
                            DataColumn(label: Text("Status")),
                            DataColumn(label: Text("Action")),
                          ],
                          source: dataSource,
                          rowsPerPage: math.min(10, adjustmentList.length),
                          columnSpacing: 15,
                          dataRowMinHeight: 80,
                          dataRowMaxHeight: 120,
                          showFirstLastButtons: true,
                        ),
                      ),
                    ),
            ),

            // Pagination
            if (totalPages > 1)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: page > 1 ? () => goToPage(page - 1) : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('Page $page of $totalPages'),
                    ),
                    IconButton(
                      onPressed: page < totalPages
                          ? () => goToPage(page + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),

            // Total records info
            if (total > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Total records: $total',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A custom DataTableSource that provides data to the PaginatedDataTable.
class AdjustmentDataSource extends DataTableSource {
  final List<dynamic> adjustmentList;
  final OptionsController optionsController;
  final String Function(dynamic) mapStatus;
  final Color Function(int) getStatusColor;
  final Function(int) onViewPressed;
  final Function(int, bool) onReviewPressed;
  final Function(int, bool) onApprovePressed;

  AdjustmentDataSource(
    this.adjustmentList,
    this.optionsController,
    this.mapStatus,
    this.getStatusColor,
    this.onViewPressed,
    this.onReviewPressed,
    this.onApprovePressed,
  );

  /// Helper method to build compact buttons
  Widget _buildCompactButton(String text, Color color, VoidCallback onPressed) {
    return SizedBox(
      height: 24,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(text, style: const TextStyle(fontSize: 9)),
      ),
    );
  }

  @override
  DataRow? getRow(int index) {
    if (index >= adjustmentList.length) {
      return null;
    }
    final adjustment = adjustmentList[index];

    String storeName;
    try {
      final storeId = adjustment["store_id"] is int
          ? adjustment["store_id"]
          : int.tryParse(adjustment["store_id"].toString()) ?? -1;

      storeName =
          optionsController.getOptionNameById(storeId) ??
          "Store ID: ${adjustment["store_id"]}";

      if (adjustment.containsKey("store_name") &&
          adjustment["store_name"] != null &&
          adjustment["store_name"].toString().isNotEmpty) {
        storeName = adjustment["store_name"].toString();
      }
    } catch (e) {
      storeName = "Store ID: ${adjustment["store_id"]}";
    }

    return DataRow(
      cells: [
        DataCell(Text(adjustment["id"].toString())),
        DataCell(Text(adjustment["adjustment_no"] ?? "")),
        DataCell(Text(adjustment["total_items"].toString())),
        DataCell(Text(storeName)),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: getStatusColor(
                adjustment["status"] ?? 0,
              ).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: getStatusColor(adjustment["status"] ?? 0),
                width: 1,
              ),
            ),
            child: Text(
              mapStatus(adjustment["status"]),
              style: TextStyle(
                color: getStatusColor(adjustment["status"] ?? 0),
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (adjustment['created_by_name'] != null)
                  Text(
                    'Created: ${adjustment['created_by_name']}',
                    style: const TextStyle(fontSize: 8, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                if (adjustment['reviewed_by_name'] != null)
                  Text(
                    'Reviewed: ${adjustment['reviewed_by_name']}',
                    style: const TextStyle(fontSize: 8, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                if (adjustment['approved_by_name'] != null)
                  Text(
                    'Approved: ${adjustment['approved_by_name']}',
                    style: const TextStyle(fontSize: 8, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _buildCompactButton(
                      "View",
                      Colors.blue,
                      () => onViewPressed(adjustment['id']),
                    ),
                    _buildCompactButton(
                      "Edit",
                      Colors.orange,
                      () => SnackbarUtils.showInfo(
                        "Edit ID: ${adjustment['id']}",
                      ),
                    ),
                    if ((adjustment["status"] ?? 0) == 0) ...[
                      _buildCompactButton(
                        'Review',
                        Colors.blue.shade600,
                        () => onReviewPressed(adjustment['id'], true),
                      ),
                      _buildCompactButton(
                        'Reject',
                        Colors.red.shade600,
                        () => onReviewPressed(adjustment['id'], false),
                      ),
                    ],
                    if ((adjustment["status"] ?? 0) == 1) ...[
                      _buildCompactButton(
                        'Approve',
                        Colors.green.shade600,
                        () => onApprovePressed(adjustment['id'], true),
                      ),
                      _buildCompactButton(
                        'Reject',
                        Colors.red.shade600,
                        () => onApprovePressed(adjustment['id'], false),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => adjustmentList.length;

  @override
  int get selectedRowCount => 0;
}
