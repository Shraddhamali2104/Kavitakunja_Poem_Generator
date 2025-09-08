class Customer {
  List<Data>? data;
  int? total;
  int? page;
  int? limit;
  int? totalPages;

  Customer({this.data, this.total, this.page, this.limit, this.totalPages});

  Customer.fromJson(Map<String, dynamic> json) {
    if (json['data'] != null) {
      data = [];
      json['data'].forEach((v) {
        data!.add(Data.fromJson(v));
      });
    }
    total = json['total'];
    page = json['page'];
    limit = json['limit'];
    totalPages = json['totalPages'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    data['total'] = total;
    data['page'] = page;
    data['limit'] = limit;
    data['totalPages'] = totalPages;
    return data;
  }
}

class Data {
  int? id;
  String? name;
  String? domain;
  String? primaryContact;
  String? primaryEmail;
  String? keyContact;
  String? keyEmail;
  String? creditType;
  String? creditLimit;
  String? paymentTerm;
  int? emailNotification;
  int? isActive;
  int? createdBy;
  String? createdAt;
  List<Addresses>? addresses;

  Data({
    this.id,
    this.name,
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
    this.createdBy,
    this.createdAt,
    this.addresses,
  });

  Data.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    domain = json['domain'];
    primaryContact = json['primary_contact'];
    primaryEmail = json['primary_email'];
    keyContact = json['key_contact'];
    keyEmail = json['key_email'];
    creditType = json['credit_type'];
    creditLimit = json['credit_limit'];
    paymentTerm = json['payment_term'];
    emailNotification = json['email_notification'];
    isActive = json['is_active'];
    createdBy = json['created_by'];
    createdAt = json['created_at'];
    if (json['addresses'] != null) {
      addresses = [];
      json['addresses'].forEach((v) {
        addresses!.add(Addresses.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['domain'] = domain;
    data['primary_contact'] = primaryContact;
    data['primary_email'] = primaryEmail;
    data['key_contact'] = keyContact;
    data['key_email'] = keyEmail;
    data['credit_type'] = creditType;
    data['credit_limit'] = creditLimit;
    data['payment_term'] = paymentTerm;
    data['email_notification'] = emailNotification;
    data['is_active'] = isActive;
    data['created_by'] = createdBy;
    data['created_at'] = createdAt;
    if (addresses != null) {
      data['addresses'] = addresses!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Addresses {
  int? id;
  String? addressLine1;
  String? addressLine2;
  String? area;
  String? city;
  String? state;
  String? gstType;
  String? gstNo;
  String? pincode;
  String? country;
  double? latitude;
  double? longitude;

  Addresses({
    this.id,
    this.addressLine1,
    this.addressLine2,
    this.area,
    this.city,
    this.state,
    this.gstType,
    this.gstNo,
    this.pincode,
    this.country,
    this.latitude,
    this.longitude,
  });

  Addresses.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    addressLine1 = json['address_line1'];
    addressLine2 = json['address_line2'];
    area = json['area'];
    city = json['city'];
    state = json['state'];
    gstType = json['gst_type'];
    gstNo = json['gst_no'];
    pincode = json['pincode'];
    country = json['country'];
    latitude = json['latitude'];
    longitude = json['longitude'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['id'] = id;
    data['address_line1'] = addressLine1;
    data['address_line2'] = addressLine2;
    data['area'] = area;
    data['city'] = city;
    data['state'] = state;
    data['gst_type'] = gstType;
    data['gst_no'] = gstNo;
    data['pincode'] = pincode;
    data['country'] = country;
    data['latitude'] = latitude;
    data['longitude'] = longitude;
    return data;
  }
}
