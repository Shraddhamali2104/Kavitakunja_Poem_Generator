class Project {
  bool? success;
  List<Projects>? projects;

  Project({this.success, this.projects});

  Project.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    if (json['projects'] != null) {
      projects = <Projects>[];
      json['projects'].forEach((v) {
        projects!.add(Projects.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    data['success'] = success;
    if (projects != null) {
      data['projects'] = projects!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Projects {
  int? id;
  String? name;
  String? description;
  int? createdBy;
  String? startDate;
  String? endDate;
  int? status;
  int? priority;
  String? createdByName;
  int? totalTasks;
  String? completedTasks;

  Projects({
    this.id,
    this.name,
    this.description,
    this.createdBy,
    this.startDate,
    this.endDate,
    this.status,
    this.priority,
    this.createdByName,
    this.totalTasks,
    this.completedTasks,
  });

  Projects.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    description = json['description'];
    createdBy = json['created_by'];
    startDate = json['start_date'];
    endDate = json['end_date'];
    status = json['status'];
    priority = json['priority'];
    createdByName = json['created_by_name'];
    totalTasks = json['total_tasks'];
    completedTasks = json['completed_tasks'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    data['id'] = id;
    data['name'] = name;
    data['description'] = description;
    data['created_by'] = createdBy;
    data['start_date'] = startDate;
    data['end_date'] = endDate;
    data['status'] = status;
    data['priority'] = priority;
    data['created_by_name'] = createdByName;
    data['total_tasks'] = totalTasks;
    data['completed_tasks'] = completedTasks;
    return data;
  }
}
