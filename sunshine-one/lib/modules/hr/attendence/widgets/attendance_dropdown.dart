import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AttendanceDropdown extends StatelessWidget {
  const AttendanceDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.08 * 255).toInt()),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: PopupMenuButton<AttendanceMenuItem>(
        tooltip: 'Attendance Sections',
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        offset: const Offset(0, 40),
        color: Colors.white,
        elevation: 8,
        onSelected: (item) => Get.toNamed(item.route),
        itemBuilder: (context) => [
          _buildMenuItem(
            context,
            const AttendanceMenuItem(
              label: 'Daily Records',
              icon: Icons.calendar_today,
              route: '/dashboard/hr/attendance/daily',
            ),
          ),
          _buildMenuItem(
            context,
            const AttendanceMenuItem(
              label: 'Monthly by Employee',
              icon: Icons.person,
              route: '/dashboard/hr/attendance/monthly_employee',
            ),
          ),
          _buildMenuItem(
            context,
            const AttendanceMenuItem(
              label: 'Monthly Reports',
              icon: Icons.assessment,
              route: '/dashboard/hr/attendance/monthly_report',
            ),
          ),
          _buildMenuItem(
            context,
            const AttendanceMenuItem(
              label: 'Yearly Report',
              icon: Icons.bar_chart,
              route: '/dashboard/hr/attendance/yearly_report',
            ),
          ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                'Sections',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<AttendanceMenuItem> _buildMenuItem(
    BuildContext context,
    AttendanceMenuItem item,
  ) {
    return PopupMenuItem<AttendanceMenuItem>(
      value: item,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Icon(item.icon, size: 20, color: Colors.black),
          ),
          const SizedBox(width: 14),
          Text(
            item.label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class AttendanceMenuItem {
  final String label;
  final IconData icon;
  final String route;
  const AttendanceMenuItem({
    required this.label,
    required this.icon,
    required this.route,
  });
}
