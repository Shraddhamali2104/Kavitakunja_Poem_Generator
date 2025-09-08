import 'package:flutter/material.dart';
import 'customer_controller.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// region: New Models for Detailed View
// These models are for parsing the detailed response from GET /sale/customer/{id}

class CustomerDetail {
  final int id;
  final String name;
  final String? domain;
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

  CustomerDetail({
    required this.id,
    required this.name,
    this.domain,
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

  factory CustomerDetail.fromJson(Map<String, dynamic> json) {
    var addressList = json['addresses'] as List;
    List<Address> addresses = addressList.map((i) => Address.fromJson(i)).toList();
    return CustomerDetail(
      id: json['id'],
      name: json['name'],
      domain: json['domain'],
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

class CustomerLayout extends StatefulWidget {
  const CustomerLayout({super.key});

  @override
  State<CustomerLayout> createState() => _CustomerLayoutState();
}

class _CustomerLayoutState extends State<CustomerLayout> {
  final CustomerController _controller = Get.put(CustomerController());
  final TextEditingController _searchController = TextEditingController();
  int limit = 10;

  @override
  void initState() {
    super.initState();
    _searchController.text = _controller.searchText.value;
    _searchController.addListener(() {
      if (_searchController.text != _controller.searchText.value) {
        _controller.searchText.value = _searchController.text;
      }
    });
    _controller.fetchCustomers(page: 1, query: _controller.searchText.value, limit: limit);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onPageChanged(int newPage) {
    _controller.fetchCustomers(page: newPage, query: _controller.searchText.value, limit: limit);
  }

  void _onLimitChanged(int newLimit) {
    setState(() {
      limit = newLimit;
    });
    _controller.fetchCustomers(page: 1, query: _controller.searchText.value, limit: limit);
  }

  // Helper function to fetch customer details
  Future<CustomerDetail> _fetchCustomerDetails(int customerId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    // Replace '{{prod}}' with your actual base URL
    final url = Uri.parse('https://1.sunshineiot.in/api/v2/sale/customer/$customerId');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return CustomerDetail.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load customer details (Status code: ${response.statusCode})');
    }
  }

  // MODIFIED: This function now fetches data from the API
  void _showCustomerViewDialog(int customerId) {
    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<CustomerDetail>(
          future: _fetchCustomerDetails(customerId),
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
              final customer = snapshot.data!;
              return AlertDialog(
                backgroundColor: Colors.white,
                title: const Text('Customer Details', style: TextStyle(color: Colors.black)),
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
                          _customerDetailRow('Name', customer.name),
                          _customerDetailRow('Domain', customer.domain),
                          _customerDetailRow('Primary Contact', customer.primaryContact),
                          _customerDetailRow('Primary Email', customer.primaryEmail),
                          _customerDetailRow('Key Contact', customer.keyContact),
                          _customerDetailRow('Key Email', customer.keyEmail),
                          _customerDetailRow('Credit Type', customer.creditType),
                          _customerDetailRow('Credit Limit', customer.creditLimit),
                          _customerDetailRow('Payment Term', customer.paymentTerm),
                          _customerDetailRow('Email Notification', customer.emailNotification == 1 ? 'Yes' : 'No'),
                          _customerDetailRow('Is Active', customer.isActive == 1 ? 'Yes' : 'No'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Addresses Section
                      const Text('Addresses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                      const SizedBox(height: 10),
                      if (customer.addresses.isEmpty)
                        const Text('No addresses found.', style: TextStyle(color: Colors.black))
                      else
                        Column(
                          children: customer.addresses.map((address) {
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
            // Fallback case
            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  DataRow _customerDetailRow(String label, dynamic value) {
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
                          'Customer List',
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
                                  hintText: 'Search Customers...',
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      _searchController.clear();
                                      _controller.searchText.value = '';
                                      _controller.fetchCustomers(page: 1);
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                Get.toNamed('/dashboard/sales/customer/add');
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
                              label: const Text('Add Customer'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Obx(() {
                    if (_controller.isLoading.value) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (_controller.errorMessage.value.isNotEmpty) {
                      return Center(child: Text(_controller.errorMessage.value));
                    } else if (_controller.customers.isEmpty) {
                      return const Center(child: Text('No customers found.'));
                    } else {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: DataTable(
                          border: TableBorder.all(color: Colors.grey, width: 1),
                          columns: const [
                            DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Domain', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Contact', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: _controller.customers.map((customer) => DataRow(
                            cells: [
                              DataCell(Text(customer.name ?? '')),
                              DataCell(Text(customer.domain ?? '')),
                              DataCell(Text(customer.primaryContact ?? '')),
                              DataCell(Text(customer.primaryEmail ?? '')),
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
                                        // UPDATED: Call the new function with customer ID
                                        _showCustomerViewDialog(customer.id!);
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
                                        Get.toNamed('/dashboard/sales/customer/edit/${customer.id}');
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )).toList(),
                        ),
                      );
                    }
                  }),
                  Obx(() => Padding(
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
                        Text('Total: ${_controller.totalCount.value}'),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}