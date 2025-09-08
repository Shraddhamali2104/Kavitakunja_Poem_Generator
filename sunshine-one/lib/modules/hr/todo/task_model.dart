class Task {
  bool? success;
  List<Tasks>? tasks;

  Task({this.success, this.tasks});

  Task.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    if (json['tasks'] != null) {
      tasks = <Tasks>[];
      json['tasks'].forEach((v) {
        tasks!.add(Tasks.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    data['success'] = success;
    if (tasks != null) {
      data['tasks'] = tasks!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Tasks {
  int? id;
  int? createdById;
  int? assignedById;
  int? assignedToId;
  String? task;
  String? note;
  int? status;
  int? priority;
  String? startDate;
  String? targetDate;
  int? projectId;
  String? projectName;
  String? assignedToName;
  String? assignedByName;
  String? createdByName;

  Tasks({
    this.id,
    this.createdById,
    this.assignedById,
    this.assignedToId,
    this.task,
    this.note,
    this.status,
    this.priority,
    this.startDate,
    this.targetDate,
    this.projectId,
    this.projectName,
    this.assignedToName,
    this.assignedByName,
    this.createdByName,
  });

  Tasks.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    createdById = json['created_by_id'];
    assignedById = json['assigned_by_id'];
    assignedToId = json['assigned_to_id'];
    task = json['task'];
    note = json['note'];
    status = json['status'];
    priority = json['priority'];
    startDate = json['start_date'];
    targetDate = json['target_date'];
    projectId = json['project_id'];
    projectName = json['project_name'];
    assignedToName = json['assigned_to_name'];
    assignedByName = json['assigned_by_name'];
    createdByName = json['created_by_name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    data['id'] = id;
    data['created_by_id'] = createdById;
    data['assigned_by_id'] = assignedById;
    data['assigned_to_id'] = assignedToId;
    data['task'] = task;
    data['note'] = note;
    data['status'] = status;
    data['priority'] = priority;
    data['start_date'] = startDate;
    data['target_date'] = targetDate;
    data['project_id'] = projectId;
    data['project_name'] = projectName;
    data['assigned_to_name'] = assignedToName;
    data['assigned_by_name'] = assignedByName;
    data['created_by_name'] = createdByName;
    return data;
  }
}
