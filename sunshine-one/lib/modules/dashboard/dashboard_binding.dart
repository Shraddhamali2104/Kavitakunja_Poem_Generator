import 'package:get/get.dart';
import 'dashboard_controller.dart';
import '../hr/services/hr_services_controller.dart';

class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(DashboardController());
    Get.put(HrServicesController());
  }
} 