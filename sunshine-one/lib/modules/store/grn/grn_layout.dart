import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:myoffice_sunshine/utils/widgets/action_icon.dart';
import 'package:myoffice_sunshine/utils/snackbar_message.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import '../../../layout/grn_pdf_layout.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

class GrnLayout extends StatefulWidget {
  const GrnLayout({super.key});

  @override
  State<GrnLayout> createState() => _GrnLayoutState();
}

class _GrnLayoutState extends State<GrnLayout> {
  final List<String> grnTabs = ['GST', 'EST', 'RETA', 'RETR', 'FOC'];
  int selectedTabIndex = 0;
  List<Map<String, dynamic>> grnList = [];
  Map<int, String> supplierMap = {}; // Map to store supplier ID to name mapping
  int page = 1;
  int limit = 20;
  int totalPages = 1;
  int total = 0;
  String search = '';
  bool isLoading = true;
  bool isSuppliersLoading = false;
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  // Initialize both suppliers and GRN data
  Future<void> _initializeData() async {
    setState(() {
      isLoading = true;
    });

    // Fetch suppliers first, then GRN data (default GST)
    await fetchSuppliers();
    await fetchGrnList(grnType: 68);
  }

  // Fetch suppliers from API
  Future<void> fetchSuppliers() async {
    setState(() {
      isSuppliersLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) {
        if (mounted) {
          SnackbarUtils.showError('Please login to continue.');
        }
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
          supplierMap = {
            for (var supplier in suppliers)
              supplier['id']: supplier['supplier_name'],
          };
          isSuppliersLoading = false;
        });
      } else {
        setState(() {
          isSuppliersLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isSuppliersLoading = false;
      });
      debugPrint('Error fetching suppliers: $e');
    }
  }

  Future<void> fetchGrnList({int? grnType}) async {
    setState(() {
      isLoading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) {
        if (mounted) {
          SnackbarUtils.showError('Please login to continue.');
        }
        return;
      }

      final uri = Uri.parse('https://1.sunshineiot.in/api/v2/store/grn/all')
          .replace(
            queryParameters: {
              'page': page.toString(),
              'limit': limit.toString(),
              'search': search,
              if (grnType != null) 'grnType': grnType.toString(),
            },
          );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          grnList = List<Map<String, dynamic>>.from(data['data'] ?? []);
          total = data['total'] ?? 0;
          page = data['page'] ?? 1;
          limit = data['limit'] ?? 20;
          totalPages = data['totalPages'] ?? 1;
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

  // Get supplier name by ID
  String getSupplierName(dynamic supplierId) {
    if (supplierId == null) return 'N/A';

    // Handle both int and string supplier IDs
    int? id;
    if (supplierId is int) {
      id = supplierId;
    } else if (supplierId is String) {
      id = int.tryParse(supplierId);
    }

    if (id != null && supplierMap.containsKey(id)) {
      return supplierMap[id] ?? 'N/A';
    }

    return 'N/A';
  }

  void _showReviewDialog(int grnId, bool isApprove) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isApprove ? 'Review GRN' : 'Reject Review'),
        content: Text(
          'Are you sure you want to ${isApprove ? 'review' : 'reject the review of'} this GRN?',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('No')),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await _reviewGrn(grnId, isApprove ? 1 : 0);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  void _showApproveDialog(int grnId, bool isApprove) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isApprove ? 'Approve GRN' : 'Reject Approve'),
        content: Text(
          'Are you sure you want to ${isApprove ? 'approve' : 'reject the approval of'} this GRN?',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('No')),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await _approveGrn(grnId, isApprove ? 1 : 0);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  Future<void> _reviewGrn(int grnId, int flag) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) {
        SnackbarUtils.showError('Please login to continue.');
        return;
      }
      final response = await http.patch(
        Uri.parse(
          'https://1.sunshineiot.in/api/v2/store/grn/$grnId/review/$flag',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        SnackbarUtils.showSuccess(
          data['message'] ?? 'GRN reviewed successfully.',
        );
        fetchGrnList();
      } else {
        SnackbarUtils.showError(data['message'] ?? 'Failed to review GRN.');
      }
    } catch (e) {
      SnackbarUtils.showError('Error reviewing GRN: $e');
    }
  }

  Future<void> _approveGrn(int grnId, int flag) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) {
        SnackbarUtils.showError('Please login to continue.');
        return;
      }
      final response = await http.patch(
        Uri.parse(
          'https://1.sunshineiot.in/api/v2/store/grn/$grnId/approve/$flag',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        SnackbarUtils.showSuccess(
          data['message'] ?? 'GRN approved successfully.',
        );
        fetchGrnList();
      } else {
        SnackbarUtils.showError(data['message'] ?? 'Failed to approve GRN.');
      }
    } catch (e) {
      SnackbarUtils.showError('Error approving GRN: $e');
    }
  }

  void onSearchChanged(String value) {
    setState(() {
      search = value;
      page = 1;
    });
    fetchGrnList(grnType: 68);
  }

  void goToPage(int newPage) {
    if (newPage < 1 || newPage > totalPages) return;
    setState(() {
      page = newPage;
    });
    fetchGrnList(grnType: 68);
  }

  String _getStatusTextInt(Map<String, dynamic> grn) {
    final status = grn['status'] ?? 0;
    switch (status) {
      case 3:
        return 'Approved';
      case 1:
        return 'Reviewed';
      case 0:
        return 'Created';
      case 2:
      case 4:
        return 'Rejected';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColorInt(int status) {
    switch (status) {
      case 3:
        return Colors.green;
      case 1:
        return Colors.blue;
      case 0:
        return Colors.orange;
      case 2:
      case 4:
        return Colors.red;
      default:
        return Colors.orange; // Default to 'Created' color
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      return dateString.split('T').first;
    } catch (e) {
      return 'N/A';
    }
  }

  Future<void> _showGrnDetailsDialog(BuildContext context, int grnId) async {
    bool isLoading = true;
    Map<String, dynamic>? grnDetails;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            if (isLoading) {
              _fetchGrnDetails(grnId).then((result) {
                if (mounted) {
                  setState(() {
                    grnDetails = result['data'];
                    errorMessage = result['error'];
                    isLoading = false;
                  });
                }
              });
            }

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      grnDetails?['grn_no'] ?? 'GRN Details',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!isLoading &&
                      errorMessage == null &&
                      grnDetails != null) ...[
                    // Download Button
                    IconButton(
                      tooltip: "Download PDF",
                      icon: const Icon(Icons.download),
                      onPressed: () async {
                        if (kIsWeb) {
                          final pdfBytes = await GrnPdfLayout.generatePdf(
                            grnDetails!,
                          );
                          final blob = html.Blob([pdfBytes], 'application/pdf');
                          final url = html.Url.createObjectUrlFromBlob(blob);
                          html.AnchorElement(href: url)
                            ..download = "${grnDetails!['grn_no']}.pdf"
                            ..click();
                          html.Url.revokeObjectUrl(url);
                        } else {
                          SnackbarUtils.showError(
                            'Download is only available on web.',
                          );
                        }
                      },
                    ),

                    // Print Button
                    IconButton(
                      tooltip: "Print PDF",
                      icon: const Icon(Icons.print),
                      onPressed: () async {
                        if (kIsWeb) {
                          await GrnPdfLayout.openPdfInNewTab(grnDetails!);
                        } else {
                          SnackbarUtils.showError(
                            'Print is only available on web.',
                          );
                        }
                      },
                    ),

                    // Share Button
                    IconButton(
                      tooltip: "Share PDF",
                      icon: const Icon(Icons.share),
                      onPressed: () async {
                        final subject = "GRN Report - ${grnDetails!['grn_no']}";
                        final body =
                            "Hello,\n\nPlease find the GRN Report (${grnDetails!['grn_no']}).\n\nThanks.";

                        // ✅ CORRECTED: Create a ShareParams object
                        final shareParams = ShareParams(
                          text: body,
                          subject: subject,
                        );

                        if (!kIsWeb) {
                          // ✅ CORRECTED: Use the instance method and pass the ShareParams object
                          await SharePlus.instance.share(shareParams);
                        } else {
                          try {
                            // ✅ CORRECTED: Use the instance method and pass the ShareParams object
                            await SharePlus.instance.share(shareParams);
                          } catch (e) {
                            // Fallback for web
                            final gmailUrl =
                                "https://mail.google.com/mail/?view=cm&fs=1&su=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}";
                            html.window.open(gmailUrl, "_blank");
                          }
                        }
                      },
                    ),
                  ],
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.height * 0.7,
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              errorMessage!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildGrnHeader(grnDetails!),
                            const SizedBox(height: 16),
                            _buildGrnDetails(grnDetails!),
                            const SizedBox(height: 16),
                            _buildGrnItems(grnDetails!),
                          ],
                        ),
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchGrnDetails(int grnId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        return {'error': 'Please login to continue.', 'data': null};
      }

      final response = await http.get(
        Uri.parse('https://1.sunshineiot.in/api/v2/store/grn/$grnId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'data': data, 'error': null};
      } else {
        return {
          'error': 'Failed to load GRN details. Status: ${response.statusCode}',
          'data': null,
        };
      }
    } catch (e) {
      return {'error': 'Error loading GRN details: $e', 'data': null};
    }
  }

  void _onAddGrnPressed(String value) {
    if (value == 'GRN') {
      Get.toNamed('/dashboard/store/grn/gst');
    } else if (value == 'EST') {
      Get.toNamed('/dashboard/store/grn/est');
    } else if (value == 'RETA') {
      Get.toNamed('/dashboard/store/grn/reta');
    } else if (value == 'RETR') {
      Get.toNamed('/dashboard/store/grn/retr');
    } else if (value == 'FOC') {
      Get.toNamed('/dashboard/store/grn/foc');
    }
  }

  String get _addGrnButtonTooltip {
    final type = grnTabs[selectedTabIndex];
    switch (type) {
      case 'GRN':
        return 'Add GRN';
      case 'EST':
        return 'Add EST';
      case 'RETA':
        return 'Add RETA';
      case 'RETR':
        return 'Add RETR';
      case 'FOC':
        return 'Add FOC';
      default:
        return 'Add GRN';
    }
  }

  Widget _buildGrnHeader(Map<String, dynamic> grnDetails) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  grnDetails['grn_no'] ?? 'N/A',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Date: ${_formatDate(grnDetails['grn_date'])}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusColorInt(
                grnDetails['status'] ?? 0,
              ).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _getStatusColorInt(grnDetails['status'] ?? 0),
              ),
            ),
            child: Text(
              _getStatusTextInt(grnDetails),
              style: TextStyle(
                color: _getStatusColorInt(grnDetails['status'] ?? 0),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrnDetails(Map<String, dynamic> grnDetails) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GRN Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            'GRN Type',
            grnDetails['grn_type']?.toString() ?? 'N/A',
          ),
          _buildDetailRow(
            'Supplier',
            getSupplierName(grnDetails['supplier_id']),
          ),
          _buildDetailRow('Store', grnDetails['store_name'] ?? 'N/A'),
          _buildDetailRow('Inward BN', grnDetails['inward_bn'] ?? 'N/A'),
          _buildDetailRow(
            'Vendor Challan No',
            grnDetails['vendor_challan_no'] ?? 'N/A',
          ),
          _buildDetailRow('Invoice No', grnDetails['invoice_no'] ?? 'N/A'),
          _buildDetailRow(
            'Invoice Date',
            _formatDate(grnDetails['invoice_date']),
          ),
          _buildDetailRow('PO No', grnDetails['po_no'] ?? 'N/A'),
          _buildDetailRow(
            'Return Date',
            _formatDate(grnDetails['return_date']),
          ),
          _buildDetailRow(
            'Repair Status',
            grnDetails['repair_status'] ?? 'N/A',
          ),
          _buildDetailRow(
            'Warranty Period',
            grnDetails['warranty_period'] ?? 'N/A',
          ),
          _buildDetailRow(
            'Billing Amount',
            '₹${grnDetails['billing_amount'] ?? '0.00'}',
          ),
          _buildDetailRow('Remarks', grnDetails['remarks'] ?? 'N/A'),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            'Approval Information',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildDetailRow('Created By', grnDetails['created_by_name'] ?? 'N/A'),
          _buildDetailRow('Created At', _formatDate(grnDetails['created_at'])),
          _buildDetailRow(
            'Reviewed By',
            grnDetails['reviewed_by_name'] ?? 'N/A',
          ),
          _buildDetailRow(
            'Reviewed At',
            _formatDate(grnDetails['reviewed_at']),
          ),
          _buildDetailRow(
            'Approved By',
            grnDetails['approved_by_name'] ?? 'N/A',
          ),
          _buildDetailRow(
            'Approved At',
            _formatDate(grnDetails['approved_at']),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildGrnItems(Map<String, dynamic> grnDetails) {
    final items = grnDetails['items'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'GRN Items',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  '${items.length} Items',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No items found',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 40,
                headingRowHeight: 40,
                columns: const [
                  DataColumn(
                    label: Text('Item ID', style: TextStyle(fontSize: 14)),
                  ),
                  DataColumn(
                    label: Text('Description', style: TextStyle(fontSize: 14)),
                  ),
                  DataColumn(
                    label: Text('PO Qty', style: TextStyle(fontSize: 14)),
                  ),
                  DataColumn(
                    label: Text('Actual Qty', style: TextStyle(fontSize: 14)),
                  ),
                  DataColumn(
                    label: Text('Rate', style: TextStyle(fontSize: 14)),
                  ),
                  DataColumn(
                    label: Text('PO Total', style: TextStyle(fontSize: 14)),
                  ),
                  DataColumn(
                    label: Text(
                      'Invoice Total',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  DataColumn(
                    label: Text('Defect Type', style: TextStyle(fontSize: 14)),
                  ),
                  DataColumn(
                    label: Text('Repair Notes', style: TextStyle(fontSize: 14)),
                  ),
                ],
                rows: items.map((item) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          item['item_id']?.toString() ?? 'N/A',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      DataCell(
                        Text(
                          item['item_description']?.toString() ?? 'N/A',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      DataCell(
                        Text(
                          item['po_qty']?.toString() ?? 'N/A',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      DataCell(
                        Text(
                          item['actual_qty']?.toString() ?? 'N/A',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      DataCell(
                        Text(
                          '₹${item['rate']?.toString() ?? '0.00'}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      DataCell(
                        Text(
                          '₹${item['po_total']?.toString() ?? '0.00'}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      DataCell(
                        Text(
                          '₹${item['invoice_total']?.toString() ?? '0.00'}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      DataCell(
                        Text(
                          item['defect_type']?.toString() ?? 'N/A',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      DataCell(
                        Text(
                          item['repair_notes']?.toString() ?? 'N/A',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Tab Bar directly under SafeArea
            // Tab Bar directly under SafeArea
            Material(
              elevation: 6,
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(grnTabs.length, (i) {
                    final isSelected = selectedTabIndex == i;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (selectedTabIndex != i) {
                            setState(() {
                              selectedTabIndex = i;
                            });
                            int? grnType;
                            switch (grnTabs[i]) {
                              case 'GST':
                                grnType = 68;
                                break;
                              case 'EST':
                                grnType = 66;
                                break;
                              case 'RETA':
                                grnType = 69;
                                break;
                              case 'RETR':
                                grnType = 70;
                                break;
                              case 'FOC':
                                grnType = 67;
                                break;
                            }
                            fetchGrnList(grnType: grnType);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.ease,
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ), // reduced
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.black
                                : Colors.transparent,
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
                              child: Text(grnTabs[i]),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

            // Content container with search + table
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Title
                  Text(
                    grnTabs[selectedTabIndex],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Row(
                    children: [
                      SizedBox(
                        width: 220,
                        height: 33,
                        child: TextField(
                          controller: searchController,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "Search by GRN",
                            prefixIcon: const Icon(Icons.search, size: 18),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: onSearchChanged,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Tooltip(
                        message: _addGrnButtonTooltip,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _onAddGrnPressed(grnTabs[selectedTabIndex]),
                          icon: const Icon(Icons.add),
                          label: const Text("Add"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          _buildGrnTable(),
                          const SizedBox(height: 16),
                          _buildPagination(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrnTable() {
    // Use uniform column width for all columns
    const columnWidths = {
      0: FlexColumnWidth(0.8),
      1: FlexColumnWidth(0.8),
      2: FlexColumnWidth(0.8),
      // 3: FlexColumnWidth(1.0),
      3: FlexColumnWidth(1.0),
      4: FlexColumnWidth(0.8),
      5: FlexColumnWidth(1.0),
      6: FlexColumnWidth(1.2),
    };
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: Table(
              columnWidths: columnWidths,
              children: [
                TableRow(
                  children: [
                    _buildHeaderCell('GRN No'),
                    _buildHeaderCell('Created By'),
                    _buildHeaderCell('Date'),
                    // _buildHeaderCell('Type'),
                    _buildHeaderCell('Supplier'),
                    _buildHeaderCell('Amount'),
                    _buildHeaderCell('Status'),
                    _buildHeaderCell('Actions'),
                  ],
                ),
              ],
            ),
          ),
          // Table Body
          ...grnList.asMap().entries.map((entry) {
            final index = entry.key;
            final grn = entry.value;
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: index == grnList.length - 1
                      ? BorderSide.none
                      : BorderSide(color: Colors.grey.shade200, width: 0.5),
                ),
              ),
              child: Table(
                columnWidths: columnWidths,
                children: [
                  TableRow(
                    children: [
                      // GRN No
                      TableCell(
                        verticalAlignment: TableCellVerticalAlignment.middle,
                        child: _buildTableCell(
                          Text(
                            grn['grn_no'] ?? '-',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,

                            maxLines: 1,
                          ),
                        ),
                      ), // Created By
                      _buildTableCell(
                        Text(
                          grn['created_by_name'],
                          style: const TextStyle(fontSize: 14),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      // Date
                      _buildTableCell(
                        Text(
                          grn['grn_date'] != null
                              ? grn['grn_date'].toString().split('T').first
                              : '-',
                          style: const TextStyle(fontSize: 14),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Type
                      // _buildTableCell(
                      //   Container(
                      //     padding: const EdgeInsets.symmetric(
                      //       horizontal: 6,
                      //       vertical: 2,
                      //     ),
                      //     decoration: BoxDecoration(
                      //       color: Colors.blue.shade50,
                      //       borderRadius: BorderRadius.circular(4),
                      //       border: Border.all(
                      //         color: Colors.blue.shade200,
                      //         width: 0.5,
                      //       ),
                      //     ),
                      //     child: Text(
                      //       grn['grn_type_name'] ?? '-',
                      //       style: TextStyle(
                      //         color: Colors.blue.shade700,
                      //         fontSize: 10,
                      //         fontWeight: FontWeight.w500,
                      //       ),
                      //       overflow: TextOverflow.ellipsis,
                      //       textAlign: TextAlign.center,
                      //     ),
                      //   ),
                      // ),
                      // Supplier
                      _buildTableCell(
                        Text(
                          getSupplierName(grn['supplier_id']),
                          style: const TextStyle(fontSize: 14),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      // Amount
                      _buildTableCell(
                        Text(
                          grn['billing_amount'] != null
                              ? '₹${grn['billing_amount'].toString()}'
                              : '-',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Status
                      _buildTableCell(
                        Align(
                          alignment: Alignment.center, // same alignment as text
                          child: Chip(
                            label: Text(
                              _getStatusTextInt(grn),
                              style: TextStyle(
                                color: _getStatusColorInt(grn['status'] ?? 0),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            backgroundColor: _getStatusColorInt(
                              grn['status'] ?? 0,
                            ).withValues(alpha: 0.1),
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 0,
                            ),
                            side: BorderSide.none,
                            materialTapTargetSize: MaterialTapTargetSize
                                .shrinkWrap, // makes chip height smaller
                          ),
                        ),
                      ),
                      // Actions
                      _buildTableCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 2,
                              runSpacing: 2,
                              children: [
                                // View Button
                                viewIcon(
                                  tooltip: 'View Details',
                                  onPressed: () {
                                    final grnId = grn['id'];
                                    if (grnId != null) {
                                      _showGrnDetailsDialog(context, grnId);
                                    } else {
                                      SnackbarUtils.showError(
                                        'Unable to view GRN details',
                                      );
                                    }
                                  },
                                ),
                                const SizedBox(width: 4),
                                // Edit Button
                                editIcon(
                                  tooltip: 'Edit GRN',
                                  onPressed: () {
                                    final grnId = grn['id'];
                                    final grnType = (grn['grn_type_name'] ?? '')
                                        .toString()
                                        .toUpperCase();
                                    if (grnId == null || grnType.isEmpty) {
                                      SnackbarUtils.showError(
                                        'Unable to edit: missing GRN id or type',
                                      );
                                      return;
                                    }

                                    String? route;
                                    switch (grnType) {
                                      case 'GST':
                                        route =
                                            '/dashboard/store/grn/gst/edit/$grnId';
                                        break;
                                      case 'EST':
                                        route =
                                            '/dashboard/store/grn/est/edit/$grnId';
                                        break;
                                      case 'FOC':
                                        route =
                                            '/dashboard/store/grn/foc/edit/$grnId';
                                        break;
                                      case 'RETA':
                                        route =
                                            '/dashboard/store/grn/reta/edit/$grnId';
                                        break;
                                      case 'RETR':
                                        route =
                                            '/dashboard/store/grn/retr/edit/$grnId';
                                        break;
                                      default:
                                        SnackbarUtils.showError(
                                          'Unknown GRN type: $grnType',
                                        );
                                        return;
                                    }
                                    Get.toNamed(
                                      route,
                                      arguments: {'id': grnId, 'isEdit': true},
                                    );
                                  },
                                ),
                                // Review/Reject Review Buttons
                                if ((grn['status'] ?? 0) == 0) ...[
                                  SizedBox(
                                    height: 28,
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          _showReviewDialog(grn['id'], true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue.shade50,
                                        foregroundColor: Colors.blue.shade700,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),

                                        textStyle: const TextStyle(fontSize: 9),

                                        minimumSize: const Size(40, 28),
                                      ),
                                      child: const Text('Review'),
                                    ),
                                  ),
                                ],
                                // Approve/Reject Approve Buttons
                                if ((grn['status'] ?? 0) == 1) ...[
                                  SizedBox(
                                    height: 28,
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          _showApproveDialog(grn['id'], true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade50,
                                        foregroundColor: Colors.green.shade700,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        textStyle: const TextStyle(fontSize: 9),
                                        minimumSize: const Size(40, 28),
                                      ),
                                      child: const Text('Approve'),
                                    ),
                                  ),
                                  SizedBox(
                                    height: 28,
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          _showApproveDialog(grn['id'], false),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade50,
                                        foregroundColor: Colors.red.shade700,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        textStyle: const TextStyle(fontSize: 9),
                                        minimumSize: const Size(40, 28),
                                      ),
                                      child: const Text('Reject'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            if (grn['reviewed_by_name'] != null)
                              Text(
                                'Reviewed by : ${grn['reviewed_by_name']}',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (grn['approved_by_name'] != null)
                              Text(
                                'Approved by : ${grn['approved_by_name']}',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Colors.black87,
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildTableCell(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: child,
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text('Items per page: '),
              DropdownButton<int>(
                value: limit,
                items: [10, 20, 50, 100]
                    .map(
                      (l) =>
                          DropdownMenuItem(value: l, child: Text(l.toString())),
                    )
                    .toList(),
                onChanged: (newLimit) {
                  if (newLimit != null) {
                    setState(() {
                      limit = newLimit;
                      page = 1;
                    });
                    fetchGrnList(grnType: 68);
                  }
                },
              ),
            ],
          ),
          Text(
            'Showing ${grnList.length} of $total items',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.first_page),
                onPressed: page > 1 ? () => goToPage(1) : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: page > 1 ? () => goToPage(page - 1) : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  page.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: page < totalPages ? () => goToPage(page + 1) : null,
              ),
              IconButton(
                icon: const Icon(Icons.last_page),
                onPressed: page < totalPages
                    ? () => goToPage(totalPages)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
