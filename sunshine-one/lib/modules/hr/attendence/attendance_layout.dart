import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AttendanceLayout extends StatelessWidget {
  const AttendanceLayout({super.key});

  @override
  Widget build(BuildContext context) {
    // Navigation buttons for attendance subpages
    return Material(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Attendance',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: () => Get.toNamed('/dashboard/hr/attendance/daily'),
                      child: const Text('Daily Records'),
                    ),
                    ElevatedButton(
                      onPressed: () => Get.toNamed('/dashboard/hr/attendance/monthly_employee'),
                      child: const Text('Monthly by Employee'),
                    ),
                    ElevatedButton(
                      onPressed: () => Get.toNamed('/dashboard/hr/attendance/monthly_report'),
                      child: const Text('Monthly Reports'),
                    ),
                    ElevatedButton(
                      onPressed: () => Get.toNamed('/dashboard/hr/attendance/yearly_report'),
                      child: const Text('Yearly Report'),
                    ),
                    ElevatedButton(
                      onPressed: () => Get.toNamed('/dashboard/hr/attendance/request'),
                      child: const Text('Attendance Request'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Optionally, you can show a default page or instructions here
            const Center(
              child: Text(
                'Select a section above to view attendance details.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 