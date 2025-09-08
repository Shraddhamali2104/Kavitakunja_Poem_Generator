import 'package:get/get.dart';
import 'hr_services_controller.dart';

class HrServicesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HrServicesController>(() => HrServicesController());
  }
} 