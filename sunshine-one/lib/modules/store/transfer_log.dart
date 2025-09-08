import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import '../../controllers/options_controller.dart';
import '../../utils/snackbar_message.dart';

class TransferLog extends StatefulWidget {
  const TransferLog({super.key});

  @override
  State<TransferLog> createState() => _TransferLogState();
}

class _TransferLogState extends State<TransferLog> {
  final OptionsController optionsController = Get.find();
  bool isLoading = true;
  String? jwtToken;
  List<dynamic> transferList = [];

  // Pagination variables
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

  Future<void> loadTokenAndFetch() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("jwt_token");

    if (token == null || token.isEmpty) {
      setState(() => isLoading = false);
      SnackbarUtils.showError("JWT token not found");
      return;
    }

    jwtToken = token;
    await fetchTransferData();
  }

  Future<void> fetchTransferData() async {
    const String baseUrl =
        "https://1.sunshineiot.in/api/v2/store/stock/transfer/all";
    final String url =
        "$baseUrl?page=$page&limit=$limit&search=$search&status=&from_store_id=&to_store_id";

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
        setState(() {
          transferList = jsonResponse['data'] ?? [];
          total = jsonResponse['total'] ?? 0;
          page = jsonResponse['page'] ?? 1;
          limit = jsonResponse['limit'] ?? 20;
          totalPages = jsonResponse['totalPages'] ?? 1;
          isLoading = false;
        });
        SnackbarUtils.showSuccess("Data loaded successfully");
      } else {
        setState(() => isLoading = false);
        SnackbarUtils.showError('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => isLoading = false);
      SnackbarUtils.showError("Error fetching data: $e");
    }
  }

  Future<void> fetchTransferDetails(int transferId) async {
    final url =
        "https://1.sunshineiot.in/api/v2/store/stock/transfer/$transferId";

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
        _showTransferDetailsDialog(jsonResponse);
      } else {
        SnackbarUtils.showError(
          'Failed to load transfer details: ${response.statusCode}',
        );
      }
    } catch (e) {
      SnackbarUtils.showError("Error fetching transfer details: $e");
    }
  }

  void _showTransferDetailsDialog(Map<String, dynamic> transferData) {
    final data = transferData['data'];
    final items = transferData['items'] as List<dynamic>;

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
                      'Transfer Details',
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
                        // Transfer Information Table
                        Text(
                          'Transfer Information',
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
                                  'Challan No',
                                  data['challan_no'] ?? 'N/A',
                                ),
                                _buildTableRow(
                                  'From Store',
                                  data['from_store_name'] ?? 'N/A',
                                ),
                                _buildTableRow(
                                  'To Store',
                                  data['to_store_name'] ?? 'N/A',
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
                          'Transfer Items',
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
                                  DataColumn(label: Text('Transfer Qty')),
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
                                        Container(
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

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final DateTime date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

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

  void onSearchChanged(String value) {
    setState(() {
      search = value;
      page = 1; // Reset to first page when searching
    });
    fetchTransferData();
  }

  void goToPage(int newPage) {
    if (newPage < 1 || newPage > totalPages) return;
    setState(() {
      page = newPage;
    });
    fetchTransferData();
  }

  void _showReviewDialog(int transferId, bool isApprove) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isApprove ? 'Review Transfer' : 'Reject Review'),
        content: Text(
          'Are you sure you want to ${isApprove ? 'review' : 'reject the review of'} this transfer?',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('No')),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await _reviewTransfer(transferId, isApprove ? 1 : 0);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  void _showApproveDialog(int transferId, bool isApprove) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isApprove ? 'Approve Transfer' : 'Reject Approval'),
        content: Text(
          'Are you sure you want to ${isApprove ? 'approve' : 'reject the approval of'} this transfer?',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('No')),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await _approveTransfer(transferId, isApprove ? 1 : 0);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  Future<void> _reviewTransfer(int transferId, int flag) async {
    try {
      final response = await http.patch(
        Uri.parse(
          'https://1.sunshineiot.in/api/v2/store/stock/transfer/$transferId/review/$flag',
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
            jsonResponse['message'] ?? 'Transfer status updated',
          );
          await fetchTransferData(); // Refresh the list
        } else {
          SnackbarUtils.showError(
            jsonResponse['message'] ?? 'Failed to review transfer',
          );
        }
      } else {
        SnackbarUtils.showError(
          'Failed to review transfer: ${response.statusCode}',
        );
      }
    } catch (e) {
      SnackbarUtils.showError("Error reviewing transfer: $e");
    }
  }

  Future<void> _approveTransfer(int transferId, int flag) async {
    try {
      final response = await http.patch(
        Uri.parse(
          'https://1.sunshineiot.in/api/v2/store/stock/transfer/$transferId/approve/$flag',
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
            jsonResponse['message'] ?? 'Transfer status updated',
          );
          await fetchTransferData(); // Refresh the list
        } else {
          SnackbarUtils.showError(
            jsonResponse['message'] ?? 'Failed to approve transfer',
          );
        }
      } else {
        SnackbarUtils.showError(
          'Failed to approve transfer: ${response.statusCode}',
        );
      }
    } catch (e) {
      SnackbarUtils.showError("Error approving transfer: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataSource = TransferDataSource(
      transferList,
      optionsController,
      _mapStatus,
      _getStatusColor,
      fetchTransferDetails,
      _showReviewDialog,
      _showApproveDialog,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Transfer Log')),
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
                      hintText: 'Search transfers...',
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
                  : transferList.isEmpty
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
                          header: Text('Transfer Records (Total: $total)'),
                          columns: const [
                            DataColumn(label: Text("ID")),
                            DataColumn(label: Text("Challan No")),
                            DataColumn(label: Text("Total Item")),
                            DataColumn(label: Text("Store From")),
                            DataColumn(label: Text("Store To")),
                            DataColumn(label: Text("Status")),
                            DataColumn(label: Text("Action")),
                          ],
                          source: dataSource,
                          rowsPerPage: math.min(10, transferList.length),
                          columnSpacing: 15, // Reduced from 20 to save space
                          dataRowMinHeight: 80, // Add minimum height for rows
                          dataRowMaxHeight: 120, // Add maximum height for rows
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

class TransferDataSource extends DataTableSource {
  final List<dynamic> transferList;
  final OptionsController optionsController;
  final String Function(dynamic) mapStatus;
  final Color Function(int) getStatusColor;
  final Function(int) onViewPressed;
  final Function(int, bool) onReviewPressed;
  final Function(int, bool) onApprovePressed;

  TransferDataSource(
    this.transferList,
    this.optionsController,
    this.mapStatus,
    this.getStatusColor,
    this.onViewPressed,
    this.onReviewPressed,
    this.onApprovePressed,
  );

  // Helper method to build compact buttons
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
    if (index >= transferList.length) return null;
    final transfer = transferList[index];

    // Try to get store names from options controller first
    String storeFromName;
    String storeToName;

    try {
      final fromStoreId = transfer["from_store_id"] is int
          ? transfer["from_store_id"]
          : int.tryParse(transfer["from_store_id"].toString()) ?? -1;

      final toStoreId = transfer["to_store_id"] is int
          ? transfer["to_store_id"]
          : int.tryParse(transfer["to_store_id"].toString()) ?? -1;

      // Get store names from options controller
      storeFromName =
          optionsController.getOptionNameById(fromStoreId) ??
          "Store ID: ${transfer["from_store_id"]}";

      storeToName =
          optionsController.getOptionNameById(toStoreId) ??
          "Store ID: ${transfer["to_store_id"]}";

      // If the API response already contains store names, use those instead
      if (transfer.containsKey("from_store_name") &&
          transfer["from_store_name"] != null &&
          transfer["from_store_name"].toString().isNotEmpty) {
        storeFromName = transfer["from_store_name"].toString();
      }

      if (transfer.containsKey("to_store_name") &&
          transfer["to_store_name"] != null &&
          transfer["to_store_name"].toString().isNotEmpty) {
        storeToName = transfer["to_store_name"].toString();
      }
    } catch (e) {
      // Fallback to showing IDs if there's any error
      storeFromName = "Store ID: ${transfer["from_store_id"]}";
      storeToName = "Store ID: ${transfer["to_store_id"]}";
    }

    return DataRow(
      cells: [
        DataCell(Text(transfer["id"].toString())),
        DataCell(Text(transfer["challan_no"] ?? "")),
        DataCell(Text(transfer["total_items"].toString())),
        DataCell(Text(storeFromName)),
        DataCell(Text(storeToName)),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: getStatusColor(
                transfer["status"] ?? 0,
              ).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: getStatusColor(transfer["status"] ?? 0),
                width: 1,
              ),
            ),
            child: Text(
              mapStatus(transfer["status"]),
              style: TextStyle(
                color: getStatusColor(transfer["status"] ?? 0),
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        DataCell(
          Container(
            width: 200, // Set a fixed width to prevent overflow
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Created/Reviewed/Approved by info - Make more compact
                if (transfer['created_by_name'] != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 1),
                    child: Text(
                      'Created: ${transfer['created_by_name']}',
                      style: const TextStyle(fontSize: 8, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                if (transfer['reviewed_by_name'] != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 1),
                    child: Text(
                      'Reviewed: ${transfer['reviewed_by_name']}',
                      style: const TextStyle(fontSize: 8, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                if (transfer['approved_by_name'] != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 1),
                    child: Text(
                      'Approved: ${transfer['approved_by_name']}',
                      style: const TextStyle(fontSize: 8, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                const SizedBox(height: 2),
                // Buttons in a more compact layout
                Flexible(
                  child: Wrap(
                    spacing: 2,
                    runSpacing: 2,
                    children: [
                      _buildCompactButton(
                        "View",
                        Colors.blue,
                        () => onViewPressed(transfer['id']),
                      ),
                      _buildCompactButton(
                        "Edit",
                        Colors.orange,
                        () => SnackbarUtils.showInfo(
                          "Edit ID: ${transfer['id']}",
                        ),
                      ),
                      // Review/Reject Review Buttons (for status 0 - Created)
                      if ((transfer["status"] ?? 0) == 0) ...[
                        _buildCompactButton(
                          'Review',
                          Colors.blue.shade600,
                          () => onReviewPressed(transfer['id'], true),
                        ),
                        _buildCompactButton(
                          'Reject',
                          Colors.red.shade600,
                          () => onReviewPressed(transfer['id'], false),
                        ),
                      ],
                      // Approve/Reject Approve Buttons (for status 1 - Reviewed)
                      if ((transfer["status"] ?? 0) == 1) ...[
                        _buildCompactButton(
                          'Approve',
                          Colors.green.shade600,
                          () => onApprovePressed(transfer['id'], true),
                        ),
                        _buildCompactButton(
                          'Reject',
                          Colors.red.shade600,
                          () => onApprovePressed(transfer['id'], false),
                        ),
                      ],
                    ],
                  ),
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
  int get rowCount => transferList.length;

  @override
  int get selectedRowCount => 0;
}
