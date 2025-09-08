class Employee {
  final int empId;
  final int rolesPermissions;
  final String empName;
  final String empEmailId;
  final String empTelegramId;
  final String empPhoneNo;
  final String empEmergencyNo01;
  final String empEmergencyNo02;
  final String empAadhar;
  final String empPan;
  final String empDrivingLicense;
  final String empCurrentAddress;
  final String empPermanentAddress;
  final DateTime empDob;
  final DateTime empDocel;
  final int empBloodGroup;
  final int empQualification;
  final String empPassportNo;
  final String empPassportValidTill;
  final String empBankName;
  final String empBankAccount;
  final String empBankBranch;
  final String empBankIfsc;
  final String empDateOfJoining;
  final String empMedicalHistory;
  final String empPassportSizePhoto;
  final String empFullViewPhoto;
  final int empDesignation;
  final int empReportingTo;
  final int empPosition;
  final int empIsPunchAllowed;
  final int empAttendanceType;
  final int empSalary;
  final int empIsOtApplicable;
  final int empNoLeaves;
  final int empWorkFromHome;
  final String empLeftDate;
  final String empPfNo;
  final String empEsicNo;
  final int? empPetrolAllowance;
  final int? empMobileAllowance;
  final int? empKidEducation;
  final int? empVariable;
  final int empActiveStatus;
  final String empLocation;
  final String empNote;
  final String? empContractor;

  Employee({
    required this.empId,
    required this.rolesPermissions,
    required this.empName,
    required this.empEmailId,
    required this.empTelegramId,
    required this.empPhoneNo,
    required this.empEmergencyNo01,
    required this.empEmergencyNo02,
    required this.empAadhar,
    required this.empPan,
    required this.empDrivingLicense,
    required this.empCurrentAddress,
    required this.empPermanentAddress,
    required this.empDob,
    required this.empDocel,
    required this.empBloodGroup,
    required this.empQualification,
    required this.empPassportNo,
    required this.empPassportValidTill,
    required this.empBankName,
    required this.empBankAccount,
    required this.empBankBranch,
    required this.empBankIfsc,
    required this.empDateOfJoining,
    required this.empMedicalHistory,
    required this.empPassportSizePhoto,
    required this.empFullViewPhoto,
    required this.empDesignation,
    required this.empReportingTo,
    required this.empPosition,
    required this.empIsPunchAllowed,
    required this.empAttendanceType,
    required this.empSalary,
    required this.empIsOtApplicable,
    required this.empNoLeaves,
    required this.empWorkFromHome,
    required this.empLeftDate,
    required this.empPfNo,
    required this.empEsicNo,
    this.empPetrolAllowance,
    this.empMobileAllowance,
    this.empKidEducation,
    this.empVariable,
    required this.empActiveStatus,
    required this.empLocation,
    required this.empNote,
    this.empContractor,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      empId: int.tryParse(json['emp_id'].toString()) ?? 0,
      rolesPermissions: int.tryParse(json['roles_permissions'].toString()) ?? 0,
      empName: json['emp_name']?.toString() ?? '',
      empEmailId: json['emp_email_id']?.toString() ?? '',
      empTelegramId: json['emp_telegram_id']?.toString() ?? '',
      empPhoneNo: json['emp_phone_no']?.toString() ?? '',
      empEmergencyNo01: json['emp_emergency_no_01']?.toString() ?? '',
      empEmergencyNo02: json['emp_emergency_no_02']?.toString() ?? '',
      empAadhar: json['emp_aadhar']?.toString() ?? '',
      empPan: json['emp_pan']?.toString() ?? '',
      empDrivingLicense: json['emp_driving_license']?.toString() ?? '',
      empCurrentAddress: json['emp_current_address']?.toString() ?? '',
      empPermanentAddress: json['emp_permanent_address']?.toString() ?? '',
      empDob:
          DateTime.tryParse(json['emp_dob']?.toString() ?? '') ??
          DateTime(1970),
      empDocel:
          DateTime.tryParse(json['emp_docel']?.toString() ?? '') ??
          DateTime(1970),
      empBloodGroup: int.tryParse(json['emp_blood_group'].toString()) ?? 0,
      empQualification: int.tryParse(json['emp_qualification'].toString()) ?? 0,
      empPassportNo: json['emp_passport_no']?.toString() ?? '',
      empPassportValidTill: json['emp_passport_valid_till']?.toString() ?? '',
      empBankName: json['emp_bank_name']?.toString() ?? '',
      empBankAccount: json['emp_bank_account']?.toString() ?? '',
      empBankBranch: json['emp_bank_branch']?.toString() ?? '',
      empBankIfsc: json['emp_bank_ifsc']?.toString() ?? '',
      empDateOfJoining: json['emp_date_of_joining']?.toString() ?? '',
      empMedicalHistory: json['emp_medical_history']?.toString() ?? '',
      empPassportSizePhoto: json['emp_passport_size_photo']?.toString() ?? '',
      empFullViewPhoto: json['emp_full_view_photo']?.toString() ?? '',
      empDesignation: int.tryParse(json['emp_designation'].toString()) ?? 0,
      empReportingTo: int.tryParse(json['emp_reporting_to'].toString()) ?? 0,
      empPosition: int.tryParse(json['emp_position'].toString()) ?? 0,
      empIsPunchAllowed:
          int.tryParse(json['emp_is_punch_allowed'].toString()) ?? 0,
      empAttendanceType:
          int.tryParse(json['emp_attendance_type'].toString()) ?? 0,
      empSalary: int.tryParse(json['emp_salary'].toString()) ?? 0,
      empIsOtApplicable:
          int.tryParse(json['emp_is_ot_applicable'].toString()) ?? 0,
      empNoLeaves: int.tryParse(json['emp_no_leaves'].toString()) ?? 0,
      empWorkFromHome: int.tryParse(json['emp_work_from_home'].toString()) ?? 0,
      empLeftDate: json['emp_left_date']?.toString() ?? '',
      empPfNo: json['emp_pf_no']?.toString() ?? '',
      empEsicNo: json['emp_esic_no']?.toString() ?? '',
      empPetrolAllowance: json['emp_petrol_allowance'] != null
          ? int.tryParse(json['emp_petrol_allowance'].toString())
          : null,
      empMobileAllowance: json['emp_mobile_allowance'] != null
          ? int.tryParse(json['emp_mobile_allowance'].toString())
          : null,
      empKidEducation: json['emp_kid_education'] != null
          ? int.tryParse(json['emp_kid_education'].toString())
          : null,
      empVariable: json['emp_variable'] != null
          ? int.tryParse(json['emp_variable'].toString())
          : null,
      empActiveStatus: int.tryParse(json['emp_active_status'].toString()) ?? 0,
      empLocation: json['emp_location']?.toString() ?? '',
      empNote: json['emp_note']?.toString() ?? '',
      empContractor: json['emp_contractor']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'emp_id': empId,
      'roles_permissions': rolesPermissions,
      'emp_name': empName,
      'emp_email_id': empEmailId,
      'emp_telegram_id': empTelegramId,
      'emp_phone_no': empPhoneNo,
      'emp_emergency_no_01': empEmergencyNo01,
      'emp_emergency_no_02': empEmergencyNo02,
      'emp_aadhar': empAadhar,
      'emp_pan': empPan,
      'emp_driving_license': empDrivingLicense,
      'emp_current_address': empCurrentAddress,
      'emp_permanent_address': empPermanentAddress,
      'emp_dob': empDob.toIso8601String(),
      'emp_docel': empDocel.toIso8601String(),
      'emp_blood_group': empBloodGroup,
      'emp_qualification': empQualification,
      'emp_passport_no': empPassportNo,
      'emp_passport_valid_till': empPassportValidTill,
      'emp_bank_name': empBankName,
      'emp_bank_account': empBankAccount,
      'emp_bank_branch': empBankBranch,
      'emp_bank_ifsc': empBankIfsc,
      'emp_date_of_joining': empDateOfJoining,
      'emp_medical_history': empMedicalHistory,
      'emp_passport_size_photo': empPassportSizePhoto,
      'emp_full_view_photo': empFullViewPhoto,
      'emp_designation': empDesignation,
      'emp_reporting_to': empReportingTo,
      'emp_position': empPosition,
      'emp_is_punch_allowed': empIsPunchAllowed,
      'emp_attendance_type': empAttendanceType,
      'emp_salary': empSalary,
      'emp_is_ot_applicable': empIsOtApplicable,
      'emp_no_leaves': empNoLeaves,
      'emp_work_from_home': empWorkFromHome,
      'emp_left_date': empLeftDate,
      'emp_pf_no': empPfNo,
      'emp_esic_no': empEsicNo,
      'emp_petrol_allowance': empPetrolAllowance,
      'emp_mobile_allowance': empMobileAllowance,
      'emp_kid_education': empKidEducation,
      'emp_variable': empVariable,
      'emp_active_status': empActiveStatus,
      'emp_location': empLocation,
      'emp_note': empNote,
      'emp_contractor': empContractor,
    };
  }
}
