import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'supplier_controller.dart';
import 'supplier_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// region: New Models for Detailed View
// You can move these models to a separate file like `supplier_detail_model.dart` for better organization.

class SupplierDetail {
  final int id;
  final String companyName;
  final String? supplierType;
  final String? origin;
  final String? category;
  final String? note;
  final int? auditApplicable;
  final int? msme;
  final String? primaryContact;
  final String? primaryEmail;
  final String? keyContact;
  final String? keyEmail;
  final String? creditType;
  final String? creditLimit;
  final String? paymentTerm;
  final int? emailNotification;
  final int? isActive;
  final List<Address> addresses;

  SupplierDetail({
    required this.id,
    required this.companyName,
    this.supplierType,
    this.origin,
    this.category,
    this.note,
    this.auditApplicable,
    this.msme,
    this.primaryContact,
    this.primaryEmail,
    this.keyContact,
    this.keyEmail,
    this.creditType,
    this.creditLimit,
    this.paymentTerm,
    this.emailNotification,
    this.isActive,
    required this.addresses,
  });

  factory SupplierDetail.fromJson(Map<String, dynamic> json) {
    var addressList = json['addresses'] as List;
    List<Address> addresses = addressList.map((i) => Address.fromJson(i)).toList();
    return SupplierDetail(
      id: json['id'],
      companyName: json['company_name'],
      supplierType: json['supplier_type'],
      origin: json['origin'],
      category: json['category'],
      note: json['note'],
      auditApplicable: json['audit_applicable'],
      msme: json['msme'],
      primaryContact: json['primary_contact'],
      primaryEmail: json['primary_email'],
      keyContact: json['key_contact'],
      keyEmail: json['key_email'],
      creditType: json['credit_type'],
      creditLimit: json['credit_limit'],
      paymentTerm: json['payment_term'],
      emailNotification: json['email_notification'],
      isActive: json['is_active'],
      addresses: addresses,
    );
  }
}

class Address {
  final int id;
  final String addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? gstNo;
  final String? pincode;
  final String? country;

  Address({
    required this.id,
    required this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.gstNo,
    this.pincode,
    this.country,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'],
      addressLine1: json['address_line1'],
      addressLine2: json['address_line2'],
      city: json['city'],
      state: json['state'],
      gstNo: json['gst_no'],
      pincode: json['pincode'],
      country: json['country'],
    );
  }
}
// endregion

class SupplierLayout extends StatefulWidget {
  const SupplierLayout({super.key});

  @override
  State<SupplierLayout> createState() => _SupplierLayoutState();
}

class _SupplierLayoutState extends State<SupplierLayout> {
  final SupplierController _controller = Get.put(SupplierController());
  final TextEditingController _searchController = TextEditingController();
  bool showSupplierForm = false;
  int limit = 10;
  int? editingSupplier;

  @override
  void initState() {
    super.initState();
    _searchController.text = _controller.searchText.value;
    _searchController.addListener(() {
      if (_searchController.text != _controller.searchText.value) {
        _controller.searchText.value = _searchController.text;
      }
    });
    _controller.fetchSuppliers(page: 1, query: _controller.searchText.value, limit: limit);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onPageChanged(int newPage) {
    _controller.fetchSuppliers(page: newPage, query: _controller.searchText.value, limit: limit);
  }

  void _onLimitChanged(int newLimit) {
    setState(() {
      limit = newLimit;
    });
    _controller.fetchSuppliers(page: 1, query: _controller.searchText.value, limit: limit);
  }

  // Helper function to fetch supplier details
  Future<SupplierDetail> _fetchSupplierDetails(int supplierId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    // Replace '{{prod}}' with your actual base URL
    final url = Uri.parse('https://1.sunshineiot.in/api/v2/purchase/supplier/$supplierId');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return SupplierDetail.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load supplier details (Status code: ${response.statusCode})');
    }
  }

  // MODIFIED: This function now fetches data from the API
  void _showSupplierViewDialog(int supplierId) {
    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<SupplierDetail>(
          future: _fetchSupplierDetails(supplierId),
          builder: (context, snapshot) {
            // Loading State
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                backgroundColor: Colors.white,
                content: SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            // Error State
            if (snapshot.hasError) {
              return AlertDialog(
                backgroundColor: Colors.white,
                title: const Text('Error', style: TextStyle(color: Colors.black)),
                content: Text('Failed to fetch details: ${snapshot.error}', style: const TextStyle(color: Colors.black)),
                actions: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('Close', style: TextStyle(color: Colors.black)),
                  ),
                ],
              );
            }

            // Success State
            if (snapshot.hasData) {
              final supplier = snapshot.data!;
              return AlertDialog(
                backgroundColor: Colors.white,
                title: const Text('Supplier Details', style: TextStyle(color: Colors.black)),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Main Details Table
                      DataTable(
                        border: TableBorder.all(color: Colors.grey, width: 1),
                        columns: const [
                          DataColumn(label: Text('Field', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
                          DataColumn(label: Text('Value', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
                        ],
                        rows: [
                          _supplierDetailRow('Company Name', supplier.companyName),
                          _supplierDetailRow('Type', supplier.supplierType),
                          _supplierDetailRow('Origin', supplier.origin),
                          _supplierDetailRow('Category', supplier.category),
                          _supplierDetailRow('Note', supplier.note),
                          _supplierDetailRow('Audit Applicable', supplier.auditApplicable == 1 ? 'Yes' : 'No'),
                          _supplierDetailRow('MSME', supplier.msme == 1 ? 'Yes' : 'No'),
                          _supplierDetailRow('Primary Contact', supplier.primaryContact),
                          _supplierDetailRow('Primary Email', supplier.primaryEmail),
                          _supplierDetailRow('Key Contact', supplier.keyContact),
                          _supplierDetailRow('Key Email', supplier.keyEmail),
                          _supplierDetailRow('Credit Type', supplier.creditType),
                          _supplierDetailRow('Credit Limit', supplier.creditLimit),
                          _supplierDetailRow('Payment Term', supplier.paymentTerm),
                          _supplierDetailRow('Email Notification', supplier.emailNotification == 1 ? 'Yes' : 'No'),
                          _supplierDetailRow('Is Active', supplier.isActive == 1 ? 'Yes' : 'No'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Addresses Section
                      const Text('Addresses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                      const SizedBox(height: 10),
                      if (supplier.addresses.isEmpty)
                        const Text('No addresses found.', style: TextStyle(color: Colors.black))
                      else
                        Column(
                          children: supplier.addresses.map((address) {
                            return Card(
                              color: Colors.grey[100],
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _addressDetailRow('Address', '${address.addressLine1}, ${address.addressLine2 ?? ''}'),
                                    _addressDetailRow('City/State', '${address.city ?? ''}, ${address.state ?? ''} - ${address.pincode ?? ''}'),
                                    _addressDetailRow('Country', address.country),
                                    _addressDetailRow('GST No', address.gstNo),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('Close', style: TextStyle(color: Colors.black)),
                  ),
                ],
              );
            }

            // Should not happen, but as a fallback
            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  DataRow _supplierDetailRow(String label, dynamic value) {
    return DataRow(
      cells: [
        DataCell(Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
        DataCell(Text(value?.toString() ?? '', style: const TextStyle(color: Colors.black))),
      ],
    );
  }

  Widget _addressDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
          Expanded(child: Text(value?.toString() ?? 'N/A', style: const TextStyle(color: Colors.black))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (showSupplierForm) {
        return SupplierPage(
          supplierId: editingSupplier,
          onBackPressed: () {
            setState(() {
              showSupplierForm = false;
              editingSupplier = null;
            });
            _controller.fetchSuppliers(page: _controller.currentPage.value, query: _controller.searchText.value);
          },
        );
      }
      return Material(
        color: Colors.grey[100],
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withAlpha((255 * 0.2).toInt()),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Supplier List',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Row(
                            children: [
                              SizedBox(
                                width: 220,
                                child: TextField(
                                  controller: _searchController,
                                  style: const TextStyle(fontSize: 16),
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                    hintText: 'Search suppliers...',
                                    prefixIcon: const Icon(Icons.search),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        _searchController.clear();
                                        _controller.searchText.value = '';
                                        _controller.fetchSuppliers(page: 1);
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () {
                                  // Use GetX routing for add supplier
                                  Get.toNamed('/dashboard/purchase/suppliers/add');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  textStyle: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.bold, fontSize: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 3,
                                ),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Supplier'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _controller.isLoading.value
                        ? const Center(child: CircularProgressIndicator())
                        : _controller.errorMessage.value.isNotEmpty
                            ? Center(child: Text(_controller.errorMessage.value))
                            : _controller.suppliers.isEmpty
                                ? const Center(child: Text('No suppliers found.'))
                                : Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: DataTable(
                                      border: TableBorder.all(color: Colors.grey, width: 1),
                                      columns: const [
                                        DataColumn(label: Text('Company Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Contact', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                      ],
                                      rows: _controller.suppliers.map((supplier) => DataRow(
                                        cells: [
                                          DataCell(Text(supplier.companyName ?? '')),
                                          DataCell(Text(supplier.supplierType ?? '')),
                                          DataCell(Text(supplier.primaryContact ?? '')),
                                          DataCell(Text(supplier.primaryEmail ?? '')),
                                          DataCell(
                                            Row(
                                              children: [
                                                TextButton.icon(
                                                  icon: const Icon(Icons.visibility, color: Colors.black),
                                                  label: const Text('View', style: TextStyle(color: Colors.black)),
                                                  style: TextButton.styleFrom(
                                                    backgroundColor: Colors.grey[200],
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                  ),
                                                  onPressed: () {
                                                    // UPDATED: Call the new function with the supplier ID
                                                    _showSupplierViewDialog(supplier.id!);
                                                  },
                                                ),
                                                const SizedBox(width: 8),
                                                TextButton.icon(
                                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                                  label: const Text('Edit', style: TextStyle(color: Colors.blue)),
                                                  style: TextButton.styleFrom(
                                                    backgroundColor: Colors.blue[50],
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                  ),
                                                  onPressed: () {
                                                    Get.toNamed('/dashboard/purchase/suppliers/edit/${supplier.id}');
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      )).toList(),
                                    ),
                                  ),
                    if (_controller.totalPages.value > 1 || _controller.suppliers.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: _controller.currentPage.value > 1
                                  ? () => _onPageChanged(_controller.currentPage.value - 1)
                                  : null,
                            ),
                            Text('Page ${_controller.currentPage.value} of ${_controller.totalPages.value}'),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: _controller.currentPage.value < _controller.totalPages.value
                                  ? () => _onPageChanged(_controller.currentPage.value + 1)
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            DropdownButton<int>(
                              value: limit,
                              items: const [10, 20, 50]
                                  .map((v) => DropdownMenuItem(value: v, child: Text('Show $v')))
                                  .toList(),
                              onChanged: (v) => v != null ? _onLimitChanged(v) : null,
                            ),
                            const SizedBox(width: 8),
                            Obx(() => Text('Total: ${_controller.totalCount.value}')),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

// NOTE: The EditSupplierDialog class remains unchanged from your original code.
// I am keeping it here for completeness.
class EditSupplierDialog extends StatefulWidget {
  final dynamic supplier;
  final VoidCallback onSuccess;
  const EditSupplierDialog({super.key, required this.supplier, required this.onSuccess});

  @override
  State<EditSupplierDialog> createState() => _EditSupplierDialogState();
}

class _EditSupplierDialogState extends State<EditSupplierDialog> {
  late TextEditingController _companyNameController;
  late TextEditingController _typeIdController;
  late TextEditingController _originIdController;
  late TextEditingController _categoryIdController;
  late TextEditingController _noteController;
  late TextEditingController _primaryContactController;
  late TextEditingController _primaryEmailController;
  late TextEditingController _keyContactController;
  late TextEditingController _keyEmailController;
  late TextEditingController _creditIdController;
  late TextEditingController _creditLimitController;
  late TextEditingController _paymentTermController;
  bool _auditApplicable = false;
  bool _msme = false;
  bool _emailNotification = false;
  bool _isActive = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    _companyNameController = TextEditingController(text: s.companyName ?? '');
    _typeIdController = TextEditingController(text: s.supplierType ?? '');
    _originIdController = TextEditingController(text: s.origin ?? '');
    _categoryIdController = TextEditingController(text: s.category ?? '');
    _noteController = TextEditingController(text: s.note ?? '');
    _primaryContactController = TextEditingController(text: s.primaryContact ?? '');
    _primaryEmailController = TextEditingController(text: s.primaryEmail ?? '');
    _keyContactController = TextEditingController(text: s.keyContact ?? '');
    _keyEmailController = TextEditingController(text: s.keyEmail ?? '');
    _creditIdController = TextEditingController(text: s.creditType ?? '');
    _creditLimitController = TextEditingController(text: s.creditLimit ?? '');
    _paymentTermController = TextEditingController(text: s.paymentTerm ?? '');
    _auditApplicable = (s.auditApplicable ?? 0) == 1;
    _msme = (s.msme ?? 0) == 1;
    _emailNotification = (s.emailNotification ?? 0) == 1;
    _isActive = (s.isActive ?? 0) == 1;
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _typeIdController.dispose();
    _originIdController.dispose();
    _categoryIdController.dispose();
    _noteController.dispose();
    _primaryContactController.dispose();
    _primaryEmailController.dispose();
    _keyContactController.dispose();
    _keyEmailController.dispose();
    _creditIdController.dispose();
    _creditLimitController.dispose();
    _paymentTermController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final supplierId = widget.supplier.id;
    final url = Uri.parse('https://1.sunshineiot.in/api/v2/purchase/supplier/$supplierId');
    final body = {
      "company_name": _companyNameController.text,
      "type_id": _typeIdController.text,
      "origin_id": _originIdController.text,
      "category_id": _categoryIdController.text,
      "note": _noteController.text,
      "audit_applicable": _auditApplicable,
      "msme": _msme,
      "primary_contact": _primaryContactController.text,
      "primary_email": _primaryEmailController.text,
      "key_contact": _keyContactController.text,
      "key_email": _keyEmailController.text,
      "credit_id": _creditIdController.text,
      "credit_limit": _creditLimitController.text,
      "payment_term": _paymentTermController.text,
      "email_notification": _emailNotification,
      "is_active": _isActive,
      // "addresses": [], // For now, not editing addresses
    };
    try {
      // Get token from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        widget.onSuccess();
      } else {
        setState(() {
          _error = 'Failed to update supplier (${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Text('Edit Supplier', style: TextStyle(color: Colors.black)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextField(_companyNameController, 'Company Name'),
            const SizedBox(height: 16),
            _buildTextField(_typeIdController, 'Type'),
            const SizedBox(height: 16),
            _buildTextField(_originIdController, 'Origin'),
            const SizedBox(height: 16),
            _buildTextField(_categoryIdController, 'Category'),
            const SizedBox(height: 16),
            _buildTextField(_noteController, 'Note'),
            const SizedBox(height: 16),
            _buildSwitchTile(_auditApplicable, 'Audit Applicable', (v) => setState(() => _auditApplicable = v)),
            const SizedBox(height: 8),
            _buildSwitchTile(_msme, 'MSME', (v) => setState(() => _msme = v)),
            const SizedBox(height: 16),
            _buildTextField(_primaryContactController, 'Primary Contact'),
            const SizedBox(height: 16),
            _buildTextField(_primaryEmailController, 'Primary Email'),
            const SizedBox(height: 16),
            _buildTextField(_keyContactController, 'Key Contact'),
            const SizedBox(height: 16),
            _buildTextField(_keyEmailController, 'Key Email'),
            const SizedBox(height: 16),
            _buildTextField(_creditIdController, 'Credit Type'),
            const SizedBox(height: 16),
            _buildTextField(_creditLimitController, 'Credit Limit'),
            const SizedBox(height: 16),
            _buildTextField(_paymentTermController, 'Payment Term'),
            const SizedBox(height: 8),
            _buildSwitchTile(_emailNotification, 'Email Notification', (v) => setState(() => _emailNotification = v)),
            const SizedBox(height: 8),
            _buildSwitchTile(_isActive, 'Is Active', (v) => setState(() => _isActive = v)),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Get.back(),
          child: const Text('Cancel', style: TextStyle(color: Colors.black)),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildSwitchTile(bool value, String title, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(title, style: const TextStyle(color: Colors.black)),
      activeColor: Colors.black,
      contentPadding: EdgeInsets.zero,
    );
  }
}