class EmployeeProfile {
  final int empId;
  final String empName;
  final int empDesignation;
  final String empProfilePic;

  EmployeeProfile({
    required this.empId,
    required this.empName,
    required this.empDesignation,
    required this.empProfilePic,
  });

  factory EmployeeProfile.fromJson(Map<String, dynamic> json) {
    return EmployeeProfile(
      empId: json['emp_id'] ?? 0,
      empName: json['emp_name'] ?? '',
      empDesignation: json['emp_designation'] ?? 0,
      empProfilePic: json['emp_profile_pic'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'emp_id': empId,
      'emp_name': empName,
      'emp_designation': empDesignation,
      'emp_profile_pic': empProfilePic,
    };
  }
}