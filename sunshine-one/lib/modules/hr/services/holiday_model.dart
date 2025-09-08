class Holidays {
  String? holidayDate;
  String? holidayName;
  String? holidayDescription;
  String? remarks;

  Holidays({
    this.holidayDate,
    this.holidayName,
    this.holidayDescription,
    this.remarks,
  });

  Holidays.fromJson(Map<String, dynamic> json) {
    holidayDate = json['holiday_date'];
    holidayName = json['holiday_name'];
    holidayDescription = json['holiday_description'];
    remarks = json['remarks'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['holiday_date'] = holidayDate;
    data['holiday_name'] = holidayName;
    data['holiday_description'] = holidayDescription;
    data['remarks'] = remarks;
    return data;
  }
}
