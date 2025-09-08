class Project {
  int? id;
  String? name;
  String? modelNo;
  int? annualQty;
  String? revenue;
  String? startDate;
  String? endDate;
  String? projectLead;
  String? status;
  String? createdAt;
  String? createdBy;

  Project({
    this.id,
    this.name,
    this.modelNo,
    this.annualQty,
    this.revenue,
    this.startDate,
    this.endDate,
    this.projectLead,
    this.status,
    this.createdAt,
    this.createdBy,
  });

  Project.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    modelNo = json['model_no'];
    annualQty = json['annual_qty'];
    revenue = json['revenue'];
    startDate = json['start_date'];
    endDate = json['end_date'];
    projectLead = json['project_lead'];
    status = json['status'];
    createdAt = json['created_at'];
    createdBy = json['created_by'];
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'model_no': modelNo,
      'annual_qty': annualQty,
      'revenue': revenue,
      'start_date': startDate,
      'end_date': endDate,
      'project_lead': projectLead,
      'status': status,
      'created_at': createdAt,
      'created_by': createdBy,
    };
  }
}
