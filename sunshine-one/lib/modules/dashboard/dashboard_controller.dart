import 'package:get/get.dart';

class DashboardController extends GetxController {
  // Example: Track the selected page/menu
  var selectedPage = 'dashboard'.obs;

  // Controls expansion of HR submenu
  var hrExpanded = false.obs;

  // Controls expansion of Store submenu
  var storeExpanded = false.obs;

  // Controls expansion of Sales submenu
  var salesExpanded = false.obs;

  // Controls expansion of Purchase submenu
  var purchaseExpanded = false.obs;

  // Controls expansion of Management submenu
  var managementExpanded = false.obs;
  // Controls expansion of Design submenu
  var designExpanded = false.obs;
  final currentModule = 'dashboard'.obs;
  final currentPage = 'dashboard'.obs;
  final RxBool sidebarCollapsed = false.obs;

  void selectPage(String page) {
    selectedPage.value = page;
    currentPage.value = page;
  }

  void changeModule(String module) {
    currentModule.value = module;
    currentPage.value = module;
    selectedPage.value = module;
  }
}
