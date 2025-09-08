import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:myoffice_sunshine/utils/snackbar_message.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'customer_model.dart';
import '../../controllers/options_controller.dart';
import 'customer_controller.dart';
import 'package:logger/logger.dart';

class CustomerPage extends StatefulWidget {
  final VoidCallback? onBackPressed;
  final Data? customer;
  final int? customerId;

  const CustomerPage({
    super.key,
    this.onBackPressed,
    this.customer,
    this.customerId,
  });

  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController primaryContact = TextEditingController();
  final TextEditingController primaryEmail = TextEditingController();
  final TextEditingController keyContact = TextEditingController();
  final TextEditingController keyEmail = TextEditingController();
  final TextEditingController creditLimitController = TextEditingController();

  // Initialize options controller
  final OptionsController optionsController = Get.put(OptionsController());

  int? selectedDomainId;
  int? selectedCreditTypeId;
  int? selectedPaymentTermId;

  bool emailNotification = false;
  bool isActive = true;
  bool isLoading = false;

  // Each address now also stores selected GST Type and Country
  List<Map<String, dynamic>> extraAddresses = [];

  void addExtraAddress() {
    setState(() {
      extraAddresses.add({
        'label': TextEditingController(),
        'address': TextEditingController(),
        'city': TextEditingController(),
        'state': TextEditingController(),
        'gstin': TextEditingController(),
        'gst_type_id': null,
        'country_id': null,
      });
    });
  }

  void removeAddress(int index) {
    if (extraAddresses.length > 1) {
      setState(() {
        extraAddresses[index].forEach((key, value) {
          if (value is TextEditingController) value.dispose();
        });
        extraAddresses.removeAt(index);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.customer != null) {
      _initializeWithCustomer(widget.customer!);
    } else if (widget.customerId != null) {
      _fetchCustomerData(widget.customerId!);
    } else {
      addExtraAddress();
    }

    // Set selected values after options are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (optionsController.hasData) {
        _setSelectedValues();
      }
    });
  }

  void _setSelectedValues() {
    if (widget.customer != null) {
      final c = widget.customer!;
      // Use options controller methods to get option IDs with null checks
      selectedDomainId = c.domain != null
          ? optionsController.getOptionIdByName(c.domain!)
          : null;
      selectedCreditTypeId = c.creditType != null
          ? optionsController.getOptionIdByName(c.creditType!)
          : null;
      selectedPaymentTermId = c.paymentTerm != null
          ? optionsController.getOptionIdByName(c.paymentTerm!)
          : null;

      // Update address dropdowns
      if (c.addresses != null) {
        for (
          int i = 0;
          i < c.addresses!.length && i < extraAddresses.length;
          i++
        ) {
          final addr = c.addresses![i];
          final addressData = extraAddresses[i];

          // Update GST Type and Country IDs
          if (addr.gstType != null) {
            final gstTypeId = optionsController.getOptionIdByName(
              addr.gstType!,
            );
            if (gstTypeId != null) {
              setState(() {
                addressData['gst_type_id'] = gstTypeId;
              });
            }
          }

          if (addr.country != null) {
            final countryId = optionsController.getOptionIdByName(
              addr.country!,
            );
            if (countryId != null) {
              setState(() {
                addressData['country_id'] = countryId;
              });
            }
          }
        }
      }
    }
  }

  void _updateAddressDropdowns() {
    if (widget.customer != null && widget.customer!.addresses != null) {
      for (
        int i = 0;
        i < widget.customer!.addresses!.length && i < extraAddresses.length;
        i++
      ) {
        final addr = widget.customer!.addresses![i];
        final addressData = extraAddresses[i];

        // Update GST Type and Country IDs
        if (addr.gstType != null) {
          final gstTypeId = optionsController.getOptionIdByName(addr.gstType!);
          if (gstTypeId != null) {
            setState(() {
              addressData['gst_type_id'] = gstTypeId;
            });
          }
        }

        if (addr.country != null) {
          final countryId = optionsController.getOptionIdByName(addr.country!);
          if (countryId != null) {
            setState(() {
              addressData['country_id'] = countryId;
            });
          }
        }
      }
    }
  }

  void _initializeWithCustomer(Data customer) {
    final c = customer;
    nameController.text = c.name ?? '';
    primaryContact.text = c.primaryContact ?? '';
    primaryEmail.text = c.primaryEmail ?? '';
    keyContact.text = c.keyContact ?? '';
    keyEmail.text = c.keyEmail ?? '';
    creditLimitController.text = c.creditLimit ?? '';
    emailNotification = (c.emailNotification ?? 0) == 1;
    isActive = (c.isActive ?? 0) == 1;
    extraAddresses.clear();

    if (c.addresses != null && c.addresses!.isNotEmpty) {
      for (final addr in c.addresses!) {
        // Get option IDs for GST Type and Country
        int? gstTypeId = addr.gstType != null
            ? optionsController.getOptionIdByName(addr.gstType!)
            : null;
        int? countryId = addr.country != null
            ? optionsController.getOptionIdByName(addr.country!)
            : null;

        extraAddresses.add({
          'id': addr.id,
          'label': TextEditingController(text: addr.addressLine1 ?? ''),
          'address': TextEditingController(text: addr.addressLine2 ?? ''),
          'city': TextEditingController(text: addr.city ?? ''),
          'state': TextEditingController(text: addr.state ?? ''),
          'gstin': TextEditingController(text: addr.gstNo ?? ''),
          'gst_type_id': gstTypeId,
          'country_id': countryId,
        });
      }
    } else {
      addExtraAddress();
    }
  }

  Future<void> _fetchCustomerData(int customerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) {
        throw Exception('No token found');
      }

      // Try the primary endpoint first
      http.Response response = await http.get(
        Uri.parse('https://1.sunshineiot.in/api/v2/sale/customer/$customerId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      Logger().d('Response status: ${response.statusCode}');
      Logger().d('Response body: ${response.body}');

      // If the first endpoint fails, try an alternative endpoint
      if (response.statusCode != 200) {
        Logger().d('Trying alternative endpoint...');
        response = await http.get(
          Uri.parse(
            'https://1.sunshineiot.in/api/v2/sale/customers/$customerId',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );
        Logger().d('Alternative response status: ${response.statusCode}');
        Logger().d('Alternative response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Debug logging to understand response structure
        Logger().d('API Response: $responseData');
        Logger().d('Response type: ${responseData.runtimeType}');

        // Handle different possible response structures
        Map<String, dynamic>? customerData;
        if (responseData is Map<String, dynamic>) {
          Logger().d('Response keys: ${responseData.keys.toList()}');
          if (responseData.containsKey('data')) {
            customerData = responseData['data'];
            Logger().d('Using data field');
          } else if (responseData.containsKey('customer')) {
            customerData = responseData['customer'];
            Logger().d('Using customer field');
          } else {
            // Assume the response is the customer data directly
            customerData = responseData;
            Logger().d('Using response directly');
          }
        } else {
          throw Exception('Invalid response format');
        }

        if (customerData == null) {
          throw Exception('Customer data is null');
        }

        Logger().d('Customer data: $customerData');
        try {
          final customer = Data.fromJson(customerData);
          Logger().d('Customer addresses: ${customer.addresses?.length ?? 0}');
          if (customer.addresses != null) {
            for (int i = 0; i < customer.addresses!.length; i++) {
              final addr = customer.addresses![i];
              Logger().d(
                'Address $i: ${addr.addressLine1}, ${addr.addressLine2}, ${addr.city}, ${addr.state}',
              );
              Logger().d('GST Type: ${addr.gstType}, Country: ${addr.country}');
            }
          }

          _initializeWithCustomer(customer);

          // Set selected values after options are loaded
          WidgetsBinding.instance.addPostFrameCallback((_) {
            selectedDomainId = customer.domain != null
                ? optionsController.getOptionIdByName(customer.domain!)
                : null;
            selectedCreditTypeId = customer.creditType != null
                ? optionsController.getOptionIdByName(customer.creditType!)
                : null;
            selectedPaymentTermId = customer.paymentTerm != null
                ? optionsController.getOptionIdByName(customer.paymentTerm!)
                : null;

            // Update address dropdowns after options are loaded
            if (customer.addresses != null) {
              for (
                int i = 0;
                i < customer.addresses!.length && i < extraAddresses.length;
                i++
              ) {
                final addr = customer.addresses![i];
                final addressData = extraAddresses[i];

                // Update GST Type and Country IDs
                if (addr.gstType != null) {
                  final gstTypeId = optionsController.getOptionIdByName(
                    addr.gstType!,
                  );
                  if (gstTypeId != null) {
                    setState(() {
                      addressData['gst_type_id'] = gstTypeId;
                    });
                  }
                }

                if (addr.country != null) {
                  final countryId = optionsController.getOptionIdByName(
                    addr.country!,
                  );
                  if (countryId != null) {
                    setState(() {
                      addressData['country_id'] = countryId;
                    });
                  }
                }
              }
            }
          });
        } catch (parseError) {
          Logger().d('Error parsing customer data: $parseError');
          Logger().d('Customer data structure: $customerData');
          throw Exception('Failed to parse customer data: $parseError');
        }
      } else {
        throw Exception(
          'Failed to fetch customer data: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(
          'Error fetching customer data: ${e.toString()}',
        );
        Get.back();
      }
    }
  }

  @override
  void dispose() {
    // Refresh customer list when leaving the page
    final customerController = Get.find<CustomerController>();
    customerController.fetchCustomers(
      page: customerController.currentPage.value,
      query: customerController.searchText.value,
    );

    nameController.dispose();
    primaryContact.dispose();
    primaryEmail.dispose();
    keyContact.dispose();
    keyEmail.dispose();
    creditLimitController.dispose();
    for (var address in extraAddresses) {
      address.forEach((key, value) {
        if (value is TextEditingController) value.dispose();
      });
    }
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (selectedDomainId == null) {
      SnackbarUtils.showInfo('Please select a domain');
      return;
    }
    if (selectedCreditTypeId == null) {
      SnackbarUtils.showInfo('Please select a credit type');
      return;
    }
    if (selectedPaymentTermId == null) {
      SnackbarUtils.showInfo('Please select a payment term');
      return;
    }
    for (var address in extraAddresses) {
      if (address['gst_type_id'] == null) {
        SnackbarUtils.showInfo('Please select GST Type for all addresses');
        return;
      }
      if (address['country_id'] == null) {
        SnackbarUtils.showInfo('Please select Country for all addresses');
        return;
      }
    }
    setState(() {
      isLoading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) {
        throw Exception('No token found');
      }
      final addresses = extraAddresses.map((address) {
        final map = {
          "address_line1": address['label']!.text.isNotEmpty
              ? address['label']!.text
              : "Main Address",
          "address_line2": address['address']!.text,
          "area": address['city']!.text,
          "city": address['city']!.text,
          "state": address['state']!.text,
          "gst_type_id": address['gst_type_id'],
          "gst_no": address['gstin']!.text,
          "pincode": "411057",
          "country": address['country_id'],
          "latitude": 18.594,
          "longitude": 73.738,
        };
        if (address['id'] != null) {
          map['id'] = address['id'];
        }
        return map;
      }).toList();
      final requestBody = {
        "name": nameController.text,
        "domain_id": selectedDomainId,
        "primary_contact": primaryContact.text,
        "primary_email": primaryEmail.text,
        "key_contact": keyContact.text.isNotEmpty
            ? keyContact.text
            : primaryContact.text,
        "key_email": keyEmail.text.isNotEmpty
            ? keyEmail.text
            : primaryEmail.text,
        "credit_id": selectedCreditTypeId,
        "credit_limit": int.tryParse(creditLimitController.text) ?? 50000,
        "payment_term": selectedPaymentTermId,
        "email_notification": emailNotification,
        "is_active": isActive,
        "addresses": addresses,
      };
      http.Response response;
      if (widget.customer != null || widget.customerId != null) {
        final customerId = widget.customer?.id ?? widget.customerId;
        response = await http.put(
          Uri.parse(
            'https://1.sunshineiot.in/api/v2/sale/customer/$customerId',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode(requestBody),
        );
      } else {
        response = await http.post(
          Uri.parse('https://1.sunshineiot.in/api/v2/sale/customer'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode(requestBody),
        );
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = json.decode(response.body);
        final message =
            data['message'] ??
            ((widget.customer != null || widget.customerId != null)
                ? 'Customer updated successfully'
                : 'Customer added successfully');
        if (!mounted) return;

        if (widget.customer == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.green),
          );
          _formKey.currentState!.reset();
          nameController.clear();
          primaryContact.clear();
          primaryEmail.clear();
          keyContact.clear();
          keyEmail.clear();
          creditLimitController.clear();
          setState(() {
            selectedDomainId = null;
            selectedCreditTypeId = null;
            selectedPaymentTermId = null;
            emailNotification = false;
            isActive = true;
          });
          for (var address in extraAddresses) {
            address.forEach((key, value) {
              if (value is TextEditingController) value.clear();
              if (key == 'gst_type_id' || key == 'country_id') {
                address[key] = null;
              }
            });
          }
          while (extraAddresses.length > 1) {
            removeAddress(1);
          }
        } else {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );

          // Refresh customer list
          try {
            final customerController = Get.find<CustomerController>();
            customerController.refreshCustomers(limit: 10);
          } catch (e) {
            Logger().d('Failed to refresh customer list: $e');
          }

          // Navigate back to customer list with proper refresh
          Future.delayed(const Duration(milliseconds: 500), () {
            // Use offAndToNamed to replace current route and refresh the customer list
            // This will navigate to the customer list and update the URL
            Get.offAndToNamed('/dashboard/sales/customer');
          });
        }
      } else {
        String errorMsg = (widget.customer != null || widget.customerId != null)
            ? 'Failed to update customer'
            : 'Failed to add customer';
        try {
          final data = json.decode(response.body);
          if (data['message'] != null) errorMsg = data['message'];
        } catch (_) {}
        if (!mounted) return;
        SnackbarUtils.showError(errorMsg);
      }
    } catch (e) {
      if (!mounted) return;
      SnackbarUtils.showError('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Widget domainDropdown() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Obx(() {
          if (optionsController.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return DropdownButtonFormField<int>(
            value: selectedDomainId,
            onChanged: (val) => setState(() => selectedDomainId = val),
            hint: const Text(
              'Select Domain',
              style: TextStyle(color: Colors.black),
            ),
            items: optionsController.domainOptions
                .map(
                  (option) => DropdownMenuItem<int>(
                    value: option.optionId,
                    child: Text(
                      option.optionName,
                      style: const TextStyle(color: Colors.black),
                    ),
                  ),
                )
                .toList(),
            decoration: InputDecoration(
              labelText: 'Domain',
              labelStyle: const TextStyle(color: Colors.black54),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.black),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.black),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            dropdownColor: Colors.white,
            style: const TextStyle(color: Colors.black),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
            validator: (val) => val == null ? 'Please select a domain' : null,
          );
        }),
      ),
    );
  }

  Widget creditTypeDropdown() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Obx(() {
        if (optionsController.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        return DropdownButtonFormField<int>(
          value: selectedCreditTypeId,
          onChanged: (val) => setState(() => selectedCreditTypeId = val),
          hint: const Text(
            'Select Credit Type',
            style: TextStyle(color: Colors.black),
          ),
          items: optionsController.creditTypeOptions
              .map(
                (option) => DropdownMenuItem<int>(
                  value: option.optionId,
                  child: Text(
                    option.optionName,
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
              )
              .toList(),
          decoration: InputDecoration(
            labelText: 'Credit Type',
            labelStyle: const TextStyle(color: Colors.black54),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.black),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.black),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          dropdownColor: Colors.white,
          style: const TextStyle(color: Colors.black),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
          validator: (val) =>
              val == null ? 'Please select a credit type' : null,
        );
      }),
    );
  }

  Widget paymentTermDropdown() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Obx(() {
        if (optionsController.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        return DropdownButtonFormField<int>(
          value: selectedPaymentTermId,
          onChanged: (val) => setState(() => selectedPaymentTermId = val),
          hint: const Text(
            'Select Payment Term',
            style: TextStyle(color: Colors.black),
          ),
          items: optionsController.paymentTermOptions
              .map(
                (option) => DropdownMenuItem<int>(
                  value: option.optionId,
                  child: Text(
                    '${option.optionName} Days',
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
              )
              .toList(),
          decoration: InputDecoration(
            labelText: 'Payment Term',
            labelStyle: const TextStyle(color: Colors.black54),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.black),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.black),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          dropdownColor: Colors.white,
          style: const TextStyle(color: Colors.black),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
          validator: (val) =>
              val == null ? 'Please select a payment term' : null,
        );
      }),
    );
  }

  Widget addressGstTypeDropdown(int addressIndex) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Obx(() {
          if (optionsController.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final currentValue = extraAddresses[addressIndex]['gst_type_id'];
          Logger().d(
            'GST Type Dropdown $addressIndex - Current value: $currentValue',
          );
          Logger().d(
            'Available options: ${optionsController.gstTypeOptions.map((o) => '${o.optionId}:${o.optionName}').toList()}',
          );

          return DropdownButtonFormField<int>(
            value: currentValue,
            onChanged: (val) => setState(
              () => extraAddresses[addressIndex]['gst_type_id'] = val,
            ),
            hint: const Text('GST Type', style: TextStyle(color: Colors.black)),
            items: optionsController.gstTypeOptions
                .map(
                  (option) => DropdownMenuItem<int>(
                    value: option.optionId,
                    child: Text(
                      option.optionName,
                      style: const TextStyle(color: Colors.black),
                    ),
                  ),
                )
                .toList(),
            decoration: InputDecoration(
              labelText: 'GST Type',
              labelStyle: const TextStyle(color: Colors.black54),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.black),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.black),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            dropdownColor: Colors.white,
            style: const TextStyle(color: Colors.black),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
            validator: (val) => val == null ? 'Select GST Type' : null,
          );
        }),
      ),
    );
  }

  Widget addressCountryDropdown(int addressIndex) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Obx(() {
          if (optionsController.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final currentValue = extraAddresses[addressIndex]['country_id'];
          Logger().d(
            'Country Dropdown $addressIndex - Current value: $currentValue',
          );
          Logger().d(
            'Available options: ${optionsController.countryOptions.map((o) => '${o.optionId}:${o.optionName}').toList()}',
          );

          return DropdownButtonFormField<int>(
            value: currentValue,
            onChanged: (val) => setState(
              () => extraAddresses[addressIndex]['country_id'] = val,
            ),
            hint: const Text('Country', style: TextStyle(color: Colors.black)),
            items: optionsController.countryOptions
                .map(
                  (option) => DropdownMenuItem<int>(
                    value: option.optionId,
                    child: Text(
                      option.optionName,
                      style: const TextStyle(color: Colors.black),
                    ),
                  ),
                )
                .toList(),
            decoration: InputDecoration(
              labelText: 'Country',
              labelStyle: const TextStyle(color: Colors.black54),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.black),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.black),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            dropdownColor: Colors.white,
            style: const TextStyle(color: Colors.black),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
            validator: (val) => val == null ? 'Select Country' : null,
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Set selected values when options are loaded and we have customer data
      if (optionsController.hasData && !optionsController.isLoading) {
        if (widget.customer != null && selectedDomainId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _setSelectedValues();
            _updateAddressDropdowns();
          });
        }
      }

      if (optionsController.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      return PopScope(
        canPop: widget.customer != null || widget.customerId != null,
        onPopInvokedWithResult: (didPop, result) async {
          if (widget.customer != null || widget.customerId != null) {
            // In edit mode, navigate back to customer list
            Get.offAndToNamed('/dashboard/sales/customer');
            // Do not return anything (Future<void>), just exit
          }
          // In add mode, do nothing (default pop will occur)
        },
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
                  // Title only, no back button
                  Row(
                    children: [
                      const SizedBox(width: 8),
                      Text(
                        widget.customer != null || widget.customerId != null
                            ? 'Update Customer'
                            : 'Add Customer',
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  sectionTitle("General Info"),
                  rowInputs([
                    inputField(
                      "Customer Name",
                      nameController,
                      isRequired: true,
                    ),
                    domainDropdown(),
                  ]),
                  const SizedBox(height: 16),
                  sectionTitle("Addresses"),
                  ...extraAddresses.asMap().entries.map((entry) {
                    final index = entry.key;
                    final address = entry.value;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Address ${index + 1}",
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                            if (extraAddresses.length > 1)
                              IconButton(
                                onPressed: () => removeAddress(index),
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                tooltip: 'Remove Address',
                              ),
                          ],
                        ),
                        rowInputs([
                          inputField(
                            "Label (e.g., Home, Corporate)",
                            address['label']!,
                          ),
                        ]),
                        rowInputs([
                          inputField(
                            "Address",
                            address['address']!,
                            isRequired: true,
                          ),
                          inputField(
                            "City",
                            address['city']!,
                            isRequired: true,
                          ),
                        ]),
                        rowInputs([
                          inputField(
                            "State/Pin",
                            address['state']!,
                            isRequired: true,
                          ),
                          inputField("GSTIN", address['gstin']!),
                        ]),
                        rowInputs([
                          addressGstTypeDropdown(index),
                          addressCountryDropdown(index),
                        ]),
                        const SizedBox(height: 10),
                      ],
                    );
                  }),
                  TextButton.icon(
                    onPressed: addExtraAddress,
                    icon: const Icon(Icons.add, color: Colors.black87),
                    label: const Text(
                      "Add Address",
                      style: TextStyle(color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 16),
                  sectionTitle("Contact Info"),
                  rowInputs([
                    inputField(
                      "Primary Contact",
                      primaryContact,
                      isRequired: true,
                    ),
                    inputField(
                      "Primary Email",
                      primaryEmail,
                      isRequired: true,
                      isEmail: true,
                    ),
                  ]),
                  rowInputs([
                    inputField("Key Contact", keyContact),
                    inputField("Key Email ID", keyEmail, isEmail: true),
                  ]),
                  const SizedBox(height: 16),
                  sectionTitle("Payment Info"),
                  creditTypeDropdown(),
                  paymentTermDropdown(),
                  rowInputs([
                    inputField("Credit Limit", creditLimitController),
                  ]),
                  const SizedBox(height: 16),
                  sectionTitle("Preferences"),
                  preferenceToggles(),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _submitForm,
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
                              widget.customer != null ||
                                      widget.customerId != null
                                  ? 'Update Customer'
                                  : 'Save Customer',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget inputField(
    String label,
    TextEditingController controller, {
    bool isRequired = false,
    bool isEmail = false,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: TextFormField(
          controller: controller,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.black54),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.black),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.black),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          validator: (value) {
            if (isRequired && (value == null || value.isEmpty)) {
              return 'This field is required';
            }
            if (isEmail && !value!.contains('@')) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget rowInputs(List<Widget> children) {
    return Row(children: children);
  }

  Widget preferenceToggles() {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: preferenceTile(
              "Email Notifications",
              emailNotification,
              (val) => setState(() => emailNotification = val),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: preferenceTile(
              "Account Status - Active/Disabled",
              isActive,
              (val) => setState(() => isActive = val),
            ),
          ),
        ),
      ],
    );
  }

  Widget preferenceTile(String label, bool value, Function(bool) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              color: Colors.black,
            ),
          ),
          const Spacer(),
          Switch(value: value, onChanged: onChanged, activeColor: Colors.black),
        ],
      ),
    );
  }
}
