import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:myoffice_sunshine/utils/snackbar_message.dart';
import 'holiday_model.dart';
import 'hr_controller.dart';

class HrServicesLayout extends StatefulWidget {
  const HrServicesLayout({super.key});

  @override
  State<HrServicesLayout> createState() => _HrServicesLayoutState();
}

class _HrServicesLayoutState extends State<HrServicesLayout> {
  final HolidayController controller = Get.put(HolidayController());

  final List<String> monthNames = const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// controls edit mode
  final RxBool editMode = false.obs;

  @override
  void initState() {
    super.initState();
    controller.fetchHolidays();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text(
          'Holiday Calendar',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          /// Edit toggle button
          Obx(() => IconButton(
                icon: Icon(
                  editMode.value ? Icons.lock_open : Icons.lock,
                  color: Colors.white,
                ),
                tooltip: editMode.value ? "Disable Edit Mode" : "Enable Edit Mode",
                onPressed: () {
                  editMode.value = !editMode.value;
                },
              )),
          Obx(
            () => DropdownButton<int>(
              value: controller.selectedYear.value,
              underline: const SizedBox(),
              dropdownColor: Colors.white,
              style: const TextStyle(color: Colors.black),
              items: controller.availableYears
                  .map(
                    (year) => DropdownMenuItem(
                      value: year,
                      child: Text(year.toString()),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  controller.selectedYear.value = val;
                  controller.fetchHolidays();
                }
              },
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Obx(
        () => controller.isLoading.value
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(12),
                child: GridView.builder(
                  itemCount: 12,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, // 3 cards per row
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.9, // fixed height ratio
                  ),
                  itemBuilder: (_, monthIdx) {
                    final currentMonth = monthIdx + 1;

                    final monthHolidays = controller.holidays.where((h) {
                      try {
                        final date =
                            DateFormat('dd-MM-yyyy').parse(h.holidayDate ?? '');
                        return date.month == currentMonth &&
                            date.year == controller.selectedYear.value;
                      } catch (_) {
                        return false;
                      }
                    }).toList();

                    return Card(
                      color: Colors.grey[200],
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  monthNames[monthIdx],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                /// Add button only visible in edit mode
                                Obx(() => editMode.value
                                    ? IconButton(
                                        icon: const Icon(Icons.add,
                                            color: Colors.green),
                                        onPressed: () =>
                                            _showAddDialog(context, currentMonth),
                                      )
                                    : const SizedBox.shrink()),
                              ],
                            ),
                            const Divider(),
                            Expanded(
                              child: monthHolidays.isEmpty
                                  ? const Center(
                                      child: Text(
                                        "No holidays",
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: monthHolidays.length,
                                      itemBuilder: (context, i) {
                                        final holiday = monthHolidays[i];
                                        return ListTile(
                                          dense: true,
                                          contentPadding: EdgeInsets.zero,
                                          leading: const Icon(Icons.event,
                                              size: 18, color: Colors.blue),
                                          title: Text(
                                            holiday.holidayName ?? '',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                          subtitle: Text(
                                            holiday.holidayDate ?? '',
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                          /// Edit/Delete visible only in edit mode
                                          trailing: Obx(() => editMode.value
                                              ? Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(Icons.edit,
                                                          size: 18,
                                                          color: Colors.blue),
                                                      onPressed: () =>
                                                          _showEditDialog(
                                                              context, holiday),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.delete,
                                                          size: 18,
                                                          color: Colors.red),
                                                      onPressed: () => controller
                                                          .confirmAndDeleteHoliday(
                                                        context,
                                                        holiday.holidayDate ?? '',
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              : const SizedBox.shrink()),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  /// Show dialog to add holiday
  void _showAddDialog(BuildContext context, int month) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final remarksController = TextEditingController();
    DateTime selectedDate = DateTime(controller.selectedYear.value, month, 1);

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: Colors.white,
            title: Text(
              'Add Holiday - ${monthNames[month - 1]} ${controller.selectedYear.value}',
            ),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(DateFormat('dd-MM-yyyy').format(selectedDate)),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(controller.selectedYear.value, month, 1),
                        lastDate:
                            DateTime(controller.selectedYear.value, month + 1, 0),
                      );
                      if (picked != null) {
                        setState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Holiday Name *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: remarksController,
                    decoration: const InputDecoration(
                      labelText: 'Remarks',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                child: const Text('Submit'),
                onPressed: () async {
                  final newDate = DateFormat('dd-MM-yyyy').format(selectedDate);
                  final exists = controller.holidays.any(
                    (h) => h.holidayDate == newDate,
                  );

                  if (exists) {
                    SnackbarUtils.showInfo(
                      "A holiday already exists for $newDate",
                    );
                    return;
                  }

                  final holiday = Holidays(
                    holidayDate: newDate,
                    holidayName: nameController.text.trim(),
                    holidayDescription: descController.text.trim(),
                    remarks: remarksController.text.trim(),
                  );

                  await controller.addHoliday(holiday);
                  Get.back();
                  SnackbarUtils.showSuccess("Holiday added successfully");
                },
              ),
            ],
          );
        },
      ),
    );
  }

  /// Show dialog to edit holiday
  void _showEditDialog(BuildContext context, Holidays holiday) {
    final nameController = TextEditingController(text: holiday.holidayName);
    final descController = TextEditingController(text: holiday.holidayDescription);
    final remarksController = TextEditingController(text: holiday.remarks);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Holiday - ${holiday.holidayDate}'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Holiday Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: remarksController,
                decoration: const InputDecoration(
                  labelText: 'Remarks',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              holiday.holidayName = nameController.text.trim();
              holiday.holidayDescription = descController.text.trim();
              holiday.remarks = remarksController.text.trim();
              await controller.updateHoliday(holiday);
              Get.back();
              SnackbarUtils.showSuccess("Holiday updated successfully");
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
