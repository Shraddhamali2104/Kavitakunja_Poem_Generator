// Function to update notification read status via API

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_breadcrumb/flutter_breadcrumb.dart';
import 'package:myoffice_sunshine/controllers/user_controller.dart';
import 'package:myoffice_sunshine/modules/dashboard/components/notification_panel.dart';
import 'package:myoffice_sunshine/utils/snackbar_message.dart';
import 'package:myoffice_sunshine/utils/notification_icon.dart';
import '../../../models/employee_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../controllers/options_controller.dart';
import '../../../routes/app_routes.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Navbar extends StatelessWidget implements PreferredSizeWidget {
  // Notifier for notification state
  static final ValueNotifier<bool> hasNewNotificationNotifier =
      ValueNotifier<bool>(false);
  @override
  final Size preferredSize;

  const Navbar({super.key}) : preferredSize = const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final userController = Get.find<UserController>();
    final route = Get.currentRoute;
    return SafeArea(
      child: Container(
        height: preferredSize.height,
        color: Colors.black,
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Breadcrumb
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.18 * 255).toInt()),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: BreadCrumb(
                  items: _buildBreadcrumbItems(route, context),
                  divider: const Icon(
                    Icons.chevron_right,
                    color: Colors.amber,
                    size: 22,
                  ),
                  overflow: ScrollableOverflow(),
                ),
              ),

              // Right: User Profile or Loading Indicator
              Obx(() {
                if (userController.currentUser.value == null) {
                  debugPrint(
                    '🔄 Navbar: currentUser is null, showing loading indicator',
                  );
                  return Container(
                    width: 80,
                    alignment: Alignment.centerRight,
                    child: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                }

                final user = userController.currentUser.value!;
                final employee = userController.currentEmployee.value;
                debugPrint('🔄 Navbar: currentUser loaded: ${user.empName}');
                debugPrint(
                  '🔄 Navbar: currentEmployee: ${employee?.empName ?? 'null'}',
                );

                return Row(
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: hasNewNotificationNotifier,
                      builder: (context, hasNewNotification, _) {
                        return NotificationIcon(
                          hasNewNotification: hasNewNotification,
                          onPressed: () async {
                            try {
                              final notifications = await fetchNotifications();
                              for (var notif in notifications) {
                                final idStr = notif['id'];
                                if (notif['readStatus'] == '0' &&
                                    idStr != null) {
                                  await markNotificationAsRead(
                                    int.parse(idStr),
                                  );
                                }
                              }
                              // Optionally refresh notification state/UI here
                              hasNewNotificationNotifier.value = false;
                              showNotificationPanel(context);
                            } catch (e) {
                              print("Error marking notifications as read: $e");
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey[700],
                      backgroundImage: (user.empProfilePic.isNotEmpty)
                          ? NetworkImage(user.empProfilePic)
                          : null,
                      child: (user.empProfilePic.isEmpty)
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      user.empName,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () {
                        debugPrint('🔄 Profile button pressed');
                        debugPrint(
                          '🔄 Employee object: ${employee?.empName ?? 'null'}',
                        );
                        if (employee != null) {
                          debugPrint('🔄 Showing employee profile dialog');
                          showEmployeeProfileDialog(context, employee);
                        } else {
                          debugPrint(
                            '🔄 Employee details not loaded, showing snackbar',
                          );
                          SnackbarUtils.showError(
                            'Employee details not loaded. Please try again later.',
                          );
                        }
                      },
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void showEmployeeProfileDialog(BuildContext context, Employee employee) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.topRight, // Position at top-right
          child: Padding(
            padding: const EdgeInsets.only(
              top: 80,
              right: 20,
            ), // adjust as needed
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 260, // compact like image
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: employee.empPassportSizePhoto.isNotEmpty
                          ? NetworkImage(employee.empPassportSizePhoto)
                          : null,
                      child: employee.empPassportSizePhoto.isEmpty
                          ? Icon(
                              Icons.person,
                              size: 36,
                              color: Colors.grey[700],
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      employee.empName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      employee.empEmailId,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const Divider(height: 20),
                    _detailRow('ID', employee.empId.toString()),
                    _detailRow(
                      'Designation',
                      _getDesignation(employee.empDesignation),
                    ),
                    _detailRow('Phone', employee.empPhoneNo),
                    _detailRow('Address', employee.empPermanentAddress),
                    _detailRow('Date of Birth', _formatDate(employee.empDob)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () {
                          logout(context); // Close dialog
                        },
                        child: const Text('Log Out'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('emp_id');

    final userController = Get.find<UserController>();
    userController.clearUser();

    Get.offAllNamed('/');
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  String _getDesignation(int designationId) {
    final OptionsController optionsController = Get.find<OptionsController>();
    final option = optionsController.getOptionByTypeAndId(
      OptionsController.typeDesignation,
      designationId,
    );
    if (option == null) return 'Unknown';
    // Remove 'Level xx' from designation name if present
    final regex = RegExp(r'Level\s*\d+\s*-?\s*', caseSensitive: false);
    final cleaned = option.optionName.replaceAll(regex, '').trim();
    return cleaned.isEmpty ? option.optionName : cleaned;
  }

  String _formatDate(DateTime date) {
    try {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      debugPrint('❌ Error formatting date: $e');
      return 'Unknown';
    }
  }

  // Helper to map full breadcrumb path to AppRoutes constant
  String? _getRouteForBreadcrumb(String path) {
    // Map of valid routes (add more as needed)
    const routeMap = {
      '/dashboard': AppRoutes.dashboard,
      '/dashboard/overview': '/dashboard/overview',
      '/dashboard/hr/birthday': AppRoutes.hrBirthday,
      '/dashboard/hr/manage_employee': '/dashboard/hr/manage_employee',
      '/dashboard/hr/manage_employee/add': '/dashboard/hr/manage_employee/add',
      '/dashboard/hr/attendance': '/dashboard/hr/attendance',
      '/dashboard/hr/attendance/daily': '/dashboard/hr/attendance/daily',
      '/dashboard/hr/attendance/monthly_employee':
          '/dashboard/hr/attendance/monthly_employee',
      '/dashboard/hr/attendance/monthly_report':
          '/dashboard/hr/attendance/monthly_report',
      '/dashboard/hr/attendance/request': '/dashboard/hr/attendance/request',
      '/dashboard/hr/ledger': '/dashboard/hr/ledger',
      '/dashboard/hr/ledger/advance': '/dashboard/hr/ledger/advance',
      '/dashboard/hr/hr_services': '/dashboard/hr/hr_services',
      '/dashboard/hr/todo': '/dashboard/hr/todo',
      '/dashboard/store/items': '/dashboard/store/items',
      '/dashboard/store/items/add': '/dashboard/store/items/add',
      '/dashboard/store/items/buy/rm': '/dashboard/store/items/buy/rm',
      '/dashboard/store/items/buy/asset': '/dashboard/store/items/buy/asset',
      '/dashboard/store/items/buy/service':
          '/dashboard/store/items/buy/service',
      '/dashboard/store/grn': '/dashboard/store/grn',
      '/dashboard/store/grn/gst': '/dashboard/store/grn/gst',
      '/dashboard/store/grn/est': '/dashboard/store/grn/est',
      '/dashboard/store/grn/foc': '/dashboard/store/grn/foc',
      '/dashboard/store/grn/reta': '/dashboard/store/grn/reta',
      '/dashboard/store/grn/retr': '/dashboard/store/grn/retr',
      '/dashboard/sales': '/dashboard/sales',
      '/dashboard/sales/customer': '/dashboard/sales/customer',
      '/dashboard/sales/customer/add': '/dashboard/sales/customer/add',
      '/dashboard/purchase': '/dashboard/purchase',
      '/dashboard/purchase/suppliers': '/dashboard/purchase/suppliers',
      '/dashboard/purchase/suppliers/add': '/dashboard/purchase/suppliers/add',
      '/dashboard/purchase/suppliers/edit':
          '/dashboard/purchase/suppliers/edit',
      '/dashboard/management/permission': '/dashboard/management/permission',
      '/dashboard/management/master': '/dashboard/management/master',
      '/dashboard/management/threshold': '/dashboard/management/threshold',
      '/dashboard/design': '/dashboard/design',
      '/dashboard/design/project': '/dashboard/design/project',
    };
    return routeMap[path];
  }

  // Add this method to build breadcrumb items
  List<BreadCrumbItem> _buildBreadcrumbItems(
    String route,
    BuildContext context,
  ) {
    final segments = route.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      return [
        BreadCrumbItem(
          content: _breadcrumbContent('Dashboard', Icons.dashboard, true),
          onTap: () => Get.toNamed(AppRoutes.dashboard),
        ),
      ];
    }
    List<BreadCrumbItem> items = [];
    String path = '';
    for (int i = 0; i < segments.length; i++) {
      path += '/${segments[i]}';
      final isLast = i == segments.length - 1;
      final label = _getBreadcrumbLabel(segments[i]);
      final icon = _getBreadcrumbIcon(segments[i]);
      final routeForBreadcrumb = _getRouteForBreadcrumb(path);
      items.add(
        BreadCrumbItem(
          content: _breadcrumbContent(label, icon, isLast),
          onTap: (!isLast && routeForBreadcrumb != null)
              ? () => Get.toNamed(routeForBreadcrumb)
              : null,
        ),
      );
    }
    return items;
  }

  Widget _breadcrumbContent(String label, IconData? icon, bool isLast) {
    return Row(
      children: [
        if (icon != null)
          Icon(icon, color: isLast ? Colors.amber : Colors.white70, size: 20),
        if (icon != null) const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: isLast ? Colors.amber : Colors.white,
            fontWeight: isLast ? FontWeight.bold : FontWeight.w500,
            fontSize: 17,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  // Helper to map route segment to readable label
  String _getBreadcrumbLabel(String segment) {
    switch (segment) {
      case 'dashboard':
        return 'Dashboard';
      case 'hr':
        return 'HR';
      case 'manage_employee':
        return 'Manage Employee';
      case 'attendance':
        return 'Attendance';
      case 'ledger':
        return 'Ledger';
      case 'salary':
        return 'Salary Ledger';
      case 'advance':
        return 'Advance Ledger';
      case 'hr_services':
        return 'Holiday';
      case 'todo':
        return 'Todo';
      case 'store':
        return 'Store';
      case 'items':
        return 'Items';
      case 'grn':
        return 'GRN';
      case 'sales':
        return 'Sales';
      case 'customer':
        return 'Customer';
      case 'purchase':
        return 'Purchase';
      case 'suppliers':
        return 'Suppliers';
      case 'management':
        return 'Management';
      case 'permission':
        return 'Permission';
      case 'master':
        return 'Master';
      case 'threshold':
        return 'Threshold';
      case 'design':
        return 'Design';
      case 'project':
        return 'Project';
      case 'birthday':
        return 'Birthday';
      case 'overview':
        return 'Overview';
      default:
        // Capitalize and replace underscores
        return segment
            .replaceAll('_', ' ')
            .replaceFirstMapped(RegExp(r'^[a-z]'), (m) => m[0]!.toUpperCase());
    }
  }

  // Helper to map route segment to an icon
  IconData? _getBreadcrumbIcon(String segment) {
    switch (segment) {
      case 'dashboard':
        return Icons.dashboard;
      case 'hr':
        return Icons.people_alt_rounded;
      case 'manage_employee':
        return Icons.badge_rounded;
      case 'attendance':
        return Icons.calendar_today_rounded;
      case 'ledger':
        return Icons.account_balance_wallet_rounded;
      case 'salary':
        return Icons.account_balance_wallet_rounded;
      case 'advance':
        return Icons.payment_rounded;
      case 'hr_services':
        return Icons.miscellaneous_services_rounded;
      case 'todo':
        return Icons.check_circle_outline_rounded;
      case 'store':
        return Icons.store_rounded;
      case 'items':
        return Icons.inventory_2_rounded;
      case 'grn':
        return Icons.receipt_long_rounded;
      case 'sales':
        return Icons.point_of_sale_rounded;
      case 'customer':
        return Icons.person_outline_rounded;
      case 'purchase':
        return Icons.shopping_cart_rounded;
      case 'suppliers':
        return Icons.local_shipping_rounded;
      case 'management':
        return Icons.settings_rounded;
      case 'permission':
        return Icons.lock_open_rounded;
      case 'master':
        return Icons.star_rounded;
      case 'threshold':
        return Icons.trending_up_rounded;
      case 'design':
        return Icons.design_services_rounded;
      case 'project':
        return Icons.architecture_rounded;
      case 'birthday':
        return Icons.cake_rounded;
      case 'overview':
        return Icons.home_rounded;
      default:
        return null;
    }
  }

  Future<void> showNotificationPanel(BuildContext context) async {
    try {
      final notifications = await fetchNotifications();

      // Check for unread notifications
      final hasUnread = notifications.any((n) => n["readStatus"] == "0");
      Navbar.hasNewNotificationNotifier.value = hasUnread;

      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: '',
        transitionDuration: Duration.zero,
        pageBuilder: (context, anim1, anim2) {
          return Material(
            color: Colors.black.withOpacity(0.3),
            child: NotificationPanel(notifications: notifications),
          );
        },
      );
    } catch (e) {
      print("Error fetching notifications: $e");
      SnackbarUtils.showError('Failed to load notifications');
    }
  }

  Future<List<Map<String, String>>> fetchNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    if (token.isEmpty) {
      throw Exception("No token found");
    }

    final response = await http.get(
      Uri.parse("https://1.sunshineiot.in/api/v2/hr/notification"),
      headers: {"Authorization": "Bearer $token", "Accept": "application/json"},
    );

    print("Status: ${response.statusCode}");
    print("Body: ${response.body}");

    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map<Map<String, String>>((item) {
        String formattedTime = "";
        if (item["datetime"] != null) {
          final dt = DateTime.parse(item["datetime"]).toLocal();
          formattedTime = DateFormat("dd MMM yy, hh:mm a 'IST'").format(dt);
        }
        return {
          "title": item["noti_title"] ?? "",
          "details": item["noti_details"] ?? "",
          "time": formattedTime,
          "readStatus": "${item["read_status"] ?? "0"}",
          "id": "${item["id"]}",
        };
      }).toList();
    } else {
      throw Exception("Failed to load notifications");
    }
  }

  Future<void> markNotificationAsRead(int notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    final response = await http.post(
      Uri.parse("https://1.sunshineiot.in/api/v2/hr/notification/read"),
      headers: {
        "Authorization": "Bearer $token",
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
      body: json.encode({"id": notificationId, "read_status": 1}),
    );
    if (response.statusCode == 200) {
      // Success: Optionally refresh notifications or update UI
    } else {
      throw Exception("Failed to update notification");
    }
  }
}
