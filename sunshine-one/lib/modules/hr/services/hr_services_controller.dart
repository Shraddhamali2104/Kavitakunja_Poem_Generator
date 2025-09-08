import 'package:get/get.dart';

class HrServicesController extends GetxController {
  final currentPage = 'holiday'.obs;
 
  void changePage(String page) {
    currentPage.value = page;
  }
} 