import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:myoffice_sunshine/utils/snackbar_message.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../controllers/options_controller.dart';
import '../../models/option_model.dart';

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
  final List<AddressDetail> addresses;

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
    var addressList = json['addresses'] as List? ?? [];
    List<AddressDetail> addresses = addressList
        .map((i) => AddressDetail.fromJson(i))
        .toList();
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
      creditLimit: json['credit_limit']?.toString(),
      paymentTerm: json['payment_term'],
      emailNotification: json['email_notification'],
      isActive: json['is_active'],
      addresses: addresses,
    );
  }
}

class AddressDetail {
  final int id;
  final String addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? gstType;
  final String? gstNo;
  final String? pincode;
  final String? country;

  AddressDetail({
    required this.id,
    required this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.gstType,
    this.gstNo,
    this.pincode,
    this.country,
  });

  factory AddressDetail.fromJson(Map<String, dynamic> json) {
    return AddressDetail(
      id: json['id'],
      addressLine1: json['address_line1'],
      addressLine2: json['address_line2'],
      city: json['city'],
      state: json['state'],
      gstType: json['gst_type'],
      gstNo: json['gst_no'],
      pincode: json['pincode']?.toString(),
      country: json['country'],
    );
  }
}
// endregion

class SupplierPage extends StatefulWidget {
  final VoidCallback? onBackPressed;
  final int? supplierId; // Changed to accept ID for routing

  const SupplierPage({super.key, this.onBackPressed, this.supplierId});

  @override
  State<SupplierPage> createState() => _SupplierPageState();
}

class _SupplierPageState extends State<SupplierPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController companyNameController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  final TextEditingController creditLimitController = TextEditingController();

  final TextEditingController primaryContact = TextEditingController();
  final TextEditingController primaryEmail = TextEditingController();
  final TextEditingController keyContact = TextEditingController();
  final TextEditingController keyEmail = TextEditingController();

  final OptionsController optionsController = Get.put(OptionsController());

  int? selectedTypeId;
  int? selectedOriginId;
  int? selectedCategoryId;
  int? selectedCreditId;
  int? selectedPaymentTermId;

  bool auditApplicable = false;
  bool isMSME = false;
  bool emailNotification = false;
  bool isActive = true;
  bool _isSubmitting = false;
  bool _isPageLoading = true; // For fetching data in edit mode
  String? _pageError;

  List<Map<String, dynamic>> extraAddresses = [];

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    // First, fetch all dropdown options
    await _initializeOptions();

    // Then, check if we are in edit mode and fetch supplier details
    if (widget.supplierId != null) {
      await _fetchAndPopulateSupplierDetails();
    } else {
      // Add mode: just add one empty address
      addExtraAddress();
      setState(() {
        _isPageLoading = false;
      });
    }
  }

  Future<void> _fetchAndPopulateSupplierDetails() async {
    setState(() {
      _isPageLoading = true;
      _pageError = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final response = await http.get(
        Uri.parse(
          'https://1.sunshineiot.in/api/v2/purchase/supplier/${widget.supplierId}',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final supplierDetail = SupplierDetail.fromJson(
          json.decode(response.body),
        );
        _populateForm(supplierDetail);
      } else {
        throw Exception(
          'Failed to load supplier details: ${response.statusCode}',
        );
      }
    } catch (e) {
      setState(() {
        _pageError = "Error fetching supplier data: ${e.toString()}";
      });
    } finally {
      setState(() {
        _isPageLoading = false;
      });
    }
  }

  void _populateForm(SupplierDetail s) {
    companyNameController.text = s.companyName;
    noteController.text = s.note ?? '';
    creditLimitController.text = s.creditLimit ?? '';
    primaryContact.text = s.primaryContact ?? '';
    primaryEmail.text = s.primaryEmail ?? '';
    keyContact.text = s.keyContact ?? '';
    keyEmail.text = s.keyEmail ?? '';
    auditApplicable = (s.auditApplicable ?? 0) == 1;
    isMSME = (s.msme ?? 0) == 1;
    emailNotification = (s.emailNotification ?? 0) == 1;
    isActive = (s.isActive ?? 1) == 1;

    // Set dropdown values
    selectedTypeId = findOptionIdByName(
      optionsController.supplierTypeOptions,
      s.supplierType,
    );
    selectedOriginId = findOptionIdByName(
      optionsController.originOptions,
      s.origin,
    );
    selectedCategoryId = findOptionIdByName(
      optionsController.categoryOptions,
      s.category,
    );
    selectedCreditId = findOptionIdByName(
      optionsController.creditTypeOptions,
      s.creditType,
    );
    selectedPaymentTermId = findOptionIdByName(
      optionsController.paymentTermOptions,
      s.paymentTerm,
    );

    // Populate addresses
    extraAddresses.clear();
    if (s.addresses.isNotEmpty) {
      for (final addr in s.addresses) {
        extraAddresses.add({
          'id': addr.id,
          'label': TextEditingController(text: addr.addressLine1),
          'address': TextEditingController(text: addr.addressLine2 ?? ''),
          'city': TextEditingController(text: addr.city ?? ''),
          'state': TextEditingController(text: addr.state ?? ''),
          'gstin': TextEditingController(text: addr.gstNo ?? ''),
          'pincode': TextEditingController(text: addr.pincode ?? ''),
          'selectedGstTypeId': findOptionIdByName(
            optionsController.gstTypeOptions,
            addr.gstType,
          ),
          'selectedCountryId': findOptionIdByName(
            optionsController.countryOptions,
            addr.country,
          ),
        });
      }
    } else {
      addExtraAddress(); // Add an empty one if none exist
    }
  }

  Future<void> _initializeOptions() async {
    try {
      await optionsController.fetchOptions();
    } catch (e) {
      if (mounted) {
        setState(() {
          _pageError = 'Error loading options: ${e.toString()}';
        });
        SnackbarUtils.showError('Error loading options: ${e.toString()}');
      }
    }
  }

  @override
  void dispose() {
    companyNameController.dispose();
    noteController.dispose();
    creditLimitController.dispose();
    primaryContact.dispose();
    primaryEmail.dispose();
    keyContact.dispose();
    keyEmail.dispose();

    for (var address in extraAddresses) {
      (address['label'] as TextEditingController).dispose();
      (address['address'] as TextEditingController).dispose();
      (address['city'] as TextEditingController).dispose();
      (address['state'] as TextEditingController).dispose();
      (address['gstin'] as TextEditingController).dispose();
      (address['pincode'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  int? findOptionIdByName(List<Option> options, String? name) {
    if (name == null) return null;
    try {
      final match = options.firstWhere(
        (opt) =>
            opt.optionName.toLowerCase().trim() == name.toLowerCase().trim(),
      );
      return match.optionId;
    } catch (e) {
      return null; // Return null if no match is found
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedTypeId == null ||
        selectedOriginId == null ||
        selectedCategoryId == null ||
        selectedCreditId == null ||
        selectedPaymentTermId == null) {
      SnackbarUtils.showInfo("Please select all required dropdown options");
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) throw Exception('No token found');

      final addresses = extraAddresses.map((address) {
        final map = {
          "address_line1": (address['label'] as TextEditingController).text,
          "address_line2": (address['address'] as TextEditingController).text,
          "area": (address['city'] as TextEditingController).text,
          "city": (address['city'] as TextEditingController).text,
          "state": (address['state'] as TextEditingController).text,
          "gst_type_id": address['selectedGstTypeId'] ?? 13, // Default
          "gst_no": (address['gstin'] as TextEditingController).text,
          "pincode": (address['pincode'] as TextEditingController).text,
          "country": address['selectedCountryId'] ?? 61, // Default
          "latitude": 18.594,
          "longitude": 73.738,
        };
        if (address['id'] != null) {
          map['id'] = address['id'];
        }
        return map;
      }).toList();

      final requestBody = {
        "company_name": companyNameController.text,
        "type_id": selectedTypeId,
        "origin_id": selectedOriginId,
        "category_id": selectedCategoryId,
        "note": noteController.text,
        "audit_applicable": auditApplicable,
        "msme": isMSME,
        "primary_contact": primaryContact.text,
        "primary_email": primaryEmail.text,
        "key_contact": keyContact.text.isNotEmpty
            ? keyContact.text
            : primaryContact.text,
        "key_email": keyEmail.text.isNotEmpty
            ? keyEmail.text
            : primaryEmail.text,
        "credit_id": selectedCreditId,
        "credit_limit": int.tryParse(creditLimitController.text) ?? 50000,
        "payment_term": selectedPaymentTermId,
        "email_notification": emailNotification,
        "is_active": isActive,
        "addresses": addresses,
      };

      http.Response response;
      final isEditMode = widget.supplierId != null;

      if (isEditMode) {
        response = await http.put(
          Uri.parse(
            'https://1.sunshineiot.in/api/v2/purchase/supplier/${widget.supplierId}',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode(requestBody),
        );
      } else {
        response = await http.post(
          Uri.parse('https://1.sunshineiot.in/api/v2/purchase/supplier'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode(requestBody),
        );
      }

      final responseData = json.decode(response.body);
      final message =
          responseData['message'] ??
          (isEditMode ? 'Supplier updated' : 'Supplier added');

      if (response.statusCode == 200 || response.statusCode == 201) {
        SnackbarUtils.showSuccess("$message successfully");
        // Navigate back to the supplier list after successful submission
        Get.offNamed('/dashboard/purchase/suppliers');
      } else {
        throw Exception(message);
      }
    } catch (e) {
      SnackbarUtils.showError('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isPageLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pageError != null) {
      return Center(
        child: Text(_pageError!, style: const TextStyle(color: Colors.red)),
      );
    }

    return Obx(() {
      if (optionsController.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return SingleChildScrollView(
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
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      tooltip: 'Go back',
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.supplierId != null
                          ? 'Edit Supplier'
                          : 'Add Supplier',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                sectionTitle("Basic Info"),
                rowInputs([
                  inputField(
                    "Company Name",
                    companyNameController,
                    isRequired: true,
                  ),
                  supplierTypeDropdown(),
                ]),
                rowInputs([originDropdown(), categoryDropdown()]),
                rowInputs([inputField("Note", noteController)]),
                const SizedBox(height: 16),
                sectionTitle("Addresses"),
                ...extraAddresses.asMap().entries.map((entry) {
                  final index = entry.key;
                  final address = entry.value;
                  return addressCard(index, address);
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
                sectionTitle("Audit / MSME Info"),
                Row(
                  children: [
                    Expanded(
                      child: preferenceTile(
                        "Audit Applicable",
                        auditApplicable,
                        (val) => setState(() => auditApplicable = val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: preferenceTile(
                        "MSME",
                        isMSME,
                        (val) => setState(() => isMSME = val),
                      ),
                    ),
                  ],
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
                rowInputs([creditTypeDropdown(), paymentTermDropdown()]),
                rowInputs([inputField("Credit Limit", creditLimitController)]),
                const SizedBox(height: 16),
                sectionTitle("Preferences"),
                Row(
                  children: [
                    Expanded(
                      child: preferenceTile(
                        "Email Notifications",
                        emailNotification,
                        (val) => setState(() => emailNotification = val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: preferenceTile(
                        "Account Status - Active/Disabled",
                        isActive,
                        (val) => setState(() => isActive = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    child: _isSubmitting
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
                            widget.supplierId != null
                                ? 'Update Supplier'
                                : 'Save Supplier',
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget addressCard(int index, Map<String, dynamic> address) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Address ${index + 1}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                if (extraAddresses.length > 1)
                  IconButton(
                    onPressed: () => removeAddress(index),
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Remove Address',
                  ),
              ],
            ),
            rowInputs([
              inputField("Label (e.g., Home, Corporate)", address['label']!),
            ]),
            rowInputs([
              inputField("Address", address['address']!, isRequired: true),
              inputField("City", address['city']!, isRequired: true),
            ]),
            rowInputs([
              inputField("State", address['state']!, isRequired: true),
              inputField("Pincode", address['pincode']!),
            ]),
            rowInputs([
              inputField("GSTIN", address['gstin']!),
              gstTypeDropdown(index),
            ]),
            rowInputs([countryDropdown(index)]),
          ],
        ),
      ),
    );
  }

  Widget sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: const TextStyle(
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          validator: (value) {
            if (isRequired && (value == null || value.isEmpty))
              return 'This field is required';
            if (isEmail && value!.isNotEmpty && !GetUtils.isEmail(value))
              return 'Please enter a valid email';
            return null;
          },
        ),
      ),
    );
  }

  Widget dropdownSearchWidget<T>({
    required String label,
    required T? selectedItem,
    required List<T> items,
    required String Function(T) itemAsString,
    required void Function(T?) onChanged,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: DropdownSearch<T>(
          selectedItem: selectedItem,
          items: items,
          itemAsString: itemAsString,
          onChanged: onChanged,
          popupProps: PopupProps.menu(
            showSearchBox: true,
            menuProps: const MenuProps(backgroundColor: Colors.white),
            searchFieldProps: TextFieldProps(
              decoration: InputDecoration(
                hintText: 'Search...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          dropdownDecoratorProps: DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(color: Colors.black),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget supplierTypeDropdown() => dropdownSearchWidget<int>(
    label: 'Supplier Type',
    selectedItem: selectedTypeId,
    items: optionsController.supplierTypeOptions
        .map((e) => e.optionId)
        .toList(),
    itemAsString: (id) => optionsController.supplierTypeOptions
        .firstWhere((opt) => opt.optionId == id)
        .optionName,
    onChanged: (val) => setState(() => selectedTypeId = val),
  );

  Widget originDropdown() => dropdownSearchWidget<int>(
    label: 'Origin',
    selectedItem: selectedOriginId,
    items: optionsController.originOptions.map((e) => e.optionId).toList(),
    itemAsString: (id) => optionsController.originOptions
        .firstWhere((opt) => opt.optionId == id)
        .optionName,
    onChanged: (val) => setState(() => selectedOriginId = val),
  );

  Widget categoryDropdown() => dropdownSearchWidget<int>(
    label: 'Category',
    selectedItem: selectedCategoryId,
    items: optionsController.categoryOptions.map((e) => e.optionId).toList(),
    itemAsString: (id) => optionsController.categoryOptions
        .firstWhere((opt) => opt.optionId == id)
        .optionName,
    onChanged: (val) => setState(() => selectedCategoryId = val),
  );

  Widget gstTypeDropdown(int addressIndex) => dropdownSearchWidget<int>(
    label: 'GST Type',
    selectedItem: extraAddresses[addressIndex]['selectedGstTypeId'],
    items: optionsController.gstTypeOptions.map((e) => e.optionId).toList(),
    itemAsString: (id) => optionsController.gstTypeOptions
        .firstWhere((opt) => opt.optionId == id)
        .optionName,
    onChanged: (val) =>
        setState(() => extraAddresses[addressIndex]['selectedGstTypeId'] = val),
  );

  Widget countryDropdown(int addressIndex) => dropdownSearchWidget<int>(
    label: 'Country',
    selectedItem: extraAddresses[addressIndex]['selectedCountryId'],
    items: optionsController.countryOptions.map((e) => e.optionId).toList(),
    itemAsString: (id) => optionsController.countryOptions
        .firstWhere((opt) => opt.optionId == id)
        .optionName,
    onChanged: (val) =>
        setState(() => extraAddresses[addressIndex]['selectedCountryId'] = val),
  );

  Widget creditTypeDropdown() => dropdownSearchWidget<int>(
    label: 'Credit Type',
    selectedItem: selectedCreditId,
    items: optionsController.creditTypeOptions.map((e) => e.optionId).toList(),
    itemAsString: (id) => optionsController.creditTypeOptions
        .firstWhere((opt) => opt.optionId == id)
        .optionName,
    onChanged: (val) => setState(() => selectedCreditId = val),
  );

  Widget paymentTermDropdown() => dropdownSearchWidget<int>(
    label: 'Payment Term',
    selectedItem: selectedPaymentTermId,
    items: optionsController.paymentTermOptions.map((e) => e.optionId).toList(),
    itemAsString: (id) =>
        '${optionsController.paymentTermOptions.firstWhere((opt) => opt.optionId == id).optionName} Days',
    onChanged: (val) => setState(() => selectedPaymentTermId = val),
  );

  Widget rowInputs(List<Widget> children) => Row(children: children);

  Widget preferenceTile(String label, bool value, Function(bool) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
          Switch(value: value, onChanged: onChanged, activeColor: Colors.black),
        ],
      ),
    );
  }

  void addExtraAddress() {
    setState(() {
      extraAddresses.add({
        'label': TextEditingController(),
        'address': TextEditingController(),
        'city': TextEditingController(),
        'state': TextEditingController(),
        'gstin': TextEditingController(),
        'pincode': TextEditingController(),
        'selectedGstTypeId': null,
        'selectedCountryId': null,
      });
    });
  }

  void removeAddress(int index) {
    if (extraAddresses.length > 1) {
      setState(() {
        (extraAddresses[index]['label'] as TextEditingController).dispose();
        (extraAddresses[index]['address'] as TextEditingController).dispose();
        (extraAddresses[index]['city'] as TextEditingController).dispose();
        (extraAddresses[index]['state'] as TextEditingController).dispose();
        (extraAddresses[index]['gstin'] as TextEditingController).dispose();
        (extraAddresses[index]['pincode'] as TextEditingController).dispose();
        extraAddresses.removeAt(index);
      });
    }
  }
}
