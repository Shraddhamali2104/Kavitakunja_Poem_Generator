import 'package:get/get.dart';
import '../modules/auth/login_page.dart';
import '../modules/auth/otp_page.dart';
import '../modules/auth/admin_login.dart';
import '../modules/dashboard/dashboard_page.dart';
import '../modules/dashboard/dashboard_overview_page.dart';
import '../modules/dashboard/dashboard_binding.dart';
// HR
import '../modules/hr/birthday.dart';
// HR -> Manage Employee
import '../modules/hr/manage_employee/manage_employee_layout.dart';
import '../modules/hr/manage_employee/add_employee.dart';
// HR -> Attendence
import '../modules/hr/attendence/daily_records.dart';
import '../modules/hr/attendence/monthly_by_employee.dart';
import '../modules/hr/attendence/monthly_reports.dart';
import '../modules/hr/attendence/attendence_request.dart';
import '../modules/hr/attendence/yearly_report.dart';
// HR -> Salary
import '../modules/hr/ledger/salary_ledger.dart';
import '../modules/hr/ledger/advance_ledger.dart';
// HR -> Holiday
import '../modules/hr/services/hr_services_layout.dart';
// HR -> Todo
import '../modules/hr/todo/todos_screen.dart';

// Store
// import '../modules/store/store_layout.dart';
import '../modules/store/items/items_screen.dart';
import '../modules/store/grn/grn_layout.dart';
//Store --> Items
import '../modules/store/items/item_buy/additem_page.dart';
import '../modules/store/items/item_buy/rm_form.dart';
import '../modules/store/items/item_buy/asset_form.dart';
import '../modules/store/items/item_buy/service_form.dart';
//Store --> GRN
import '../modules/store/grn/gst_form.dart';
import '../modules/store/grn/est_form.dart';
import '../modules/store/grn/foc_form.dart';
import '../modules/store/grn/reta_form.dart';
import '../modules/store/grn/retr_form.dart';
//Store --> Challan/Log
import '../modules/store/stock/adjustmentchallan.dart';
import '../modules/store/stock/transferchallan.dart';
import '../modules/store/adjustment_log.dart';
import '../modules/store/transfer_log.dart';
import '../modules/store/stock/stock.dart';
// Sales
import '../modules/sales/customer_layout.dart';
import '../modules/sales/sales_layout.dart';
import '../modules/sales/customer_page.dart';
// Purchase
import '../modules/purchase/supplier_layout.dart';
import '../modules/purchase/purchase_layout.dart';
import '../modules/purchase/supplier_page.dart';
// Management
import '../modules/management/master.dart';
import '../modules/management/permissions.dart';
import '../modules/management/threshold.dart';
import '../modules/management/log_table.dart'; // Placeholder for log table, no UI yet
// Design
import '../modules/design/design_layout.dart';
import '../modules/design/project/project_layout.dart';

class AppRoutes {
  static const login = '/';
  static const otp = '/otp';
  static const dashboard = '/dashboard';
  static const adminlogin = '/admin-login';
  static const hrBirthday = '/dashboard/hr/birthday';

  static final pages = [
    GetPage(name: login, page: () => const LoginPage()),
    GetPage(name: otp, page: () => const OtpPage()),
    GetPage(name: adminlogin, page: () => const AdminLoginPage()),
    // Dashboard shell and all subpages as top-level routes
    GetPage(
      name: dashboard,
      page: () => DashboardPage(child: DashboardOverviewPage()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/overview',
      page: () => DashboardPage(child: DashboardOverviewPage()),
      binding: DashboardBinding(),
    ),
    // HR (all as direct children of dashboard)
    GetPage(
      name: hrBirthday,
      page: () => DashboardPage(child: BirthdayPage()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/hr/manage_employee',
      page: () => DashboardPage(child: ManageEmployeeLayout()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/hr/manage_employee/add',
      page: () => DashboardPage(child: AddEmployee()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/hr/manage_employee/edit/:id',
      page: () {
        final empId = int.tryParse(Get.parameters['id'] ?? '');
        return DashboardPage(child: AddEmployee(empId: empId));
      },
      binding: DashboardBinding(),
    ),
    // Attendance - direct children for each subpage
    GetPage(
      name: '/dashboard/hr/attendance',
      page: () => DashboardPage(child: DailyRecord()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/hr/attendance/daily',
      page: () => DashboardPage(child: DailyRecord()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/hr/attendance/monthly_employee',
      page: () => DashboardPage(child: MonthlyByEmployee()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/hr/attendance/monthly_report',
      page: () => DashboardPage(child: MonthlyReport()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/hr/attendance/request',
      page: () => DashboardPage(child: AttendanceRequest()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/hr/attendance/yearly_report',
      page: () => DashboardPage(child: YearlyReport()),
      binding: DashboardBinding(),
    ),
    // Ledger (was Salary)
    GetPage(
      name: '/dashboard/hr/ledger',
      page: () => DashboardPage(child: SalaryLedger()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/hr/ledger/advance',
      page: () => DashboardPage(child: AdvanceLedger()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/hr/hr_services',
      page: () => DashboardPage(child: HrServicesLayout()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/hr/todo',
      page: () => DashboardPage(child: TodosScreen()),
      binding: DashboardBinding(),
    ),
    // Store
    GetPage(
      name: '/dashboard/store/items',
      page: () => DashboardPage(child: ItemsScreen()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/store/items/add',
      page: () => DashboardPage(child: AddItemPage()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/store/items/buy/rm',
      page: () => DashboardPage(child: RMForm.fromArguments()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/store/items/buy/asset',
      page: () => DashboardPage(child: AssetForm.fromArguments()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/store/items/buy/service',
      page: () => DashboardPage(child: ServiceForm.fromArguments()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/store/grn',
      page: () => DashboardPage(child: GrnLayout()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/store/grn/gst',
      page: () => DashboardPage(child: GstForm()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/store/grn/gst/edit/:id',
      page: () => DashboardPage(child: GstForm()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/store/grn/est',
      page: () => DashboardPage(child: EstForm()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/store/grn/est/edit/:id',
      page: () => DashboardPage(child: EstForm()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/store/grn/foc',
      page: () => DashboardPage(child: FocForm()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/store/grn/foc/edit/:id',
      page: () => DashboardPage(child: FocForm()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/store/grn/reta',
      page: () => DashboardPage(child: RetaForm()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/store/grn/reta/edit/:id',
      page: () => DashboardPage(child: RetaForm()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/store/grn/retr',
      page: () => DashboardPage(child: RetrForm()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/store/grn/retr/edit/:id',
      page: () => DashboardPage(child: RetrForm()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/store/adjustment_log',
      page: () => DashboardPage(child: AdjustmentLog()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/store/transfer_log',
      page: () => DashboardPage(child: TransferLog()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/store/stock',
      page: () => DashboardPage(child: Stock()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/store/stock/adjust',
      page: () => DashboardPage(child: AdjustmentChallan()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/store/stock/transfer',
      page: () => DashboardPage(child: TransferChallan()),
      binding: DashboardBinding(),
    ),
    // Sales
    GetPage(
      name: '/dashboard/sales',
      page: () => DashboardPage(child: SalesLayout()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/sales/customer',
      page: () => DashboardPage(child: CustomerLayout()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/sales/customer/add',
      page: () => DashboardPage(child: CustomerPage()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/sales/customer/edit/:id',
      page: () {
        final customerId = int.tryParse(Get.parameters['id'] ?? '');
        return DashboardPage(child: CustomerPage(customerId: customerId));
      },
      binding: DashboardBinding(),
    ),
    // Purchase
    GetPage(
      name: '/dashboard/purchase',
      page: () => DashboardPage(child: PurchaseLayout()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/purchase/suppliers',
      page: () => DashboardPage(child: SupplierLayout()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/purchase/suppliers/add',
      page: () => DashboardPage(child: SupplierPage()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/purchase/suppliers/edit/:id',
      page: () {
        final supplierId = int.tryParse(Get.parameters['id'] ?? '');
        // You may need to fetch the supplier by ID in SupplierPage
        return DashboardPage(child: SupplierPage(supplierId: supplierId));
      },
      binding: DashboardBinding(),
    ),
    // Management
    GetPage(
      name: '/dashboard/management/permission',
      page: () => DashboardPage(child: PermissionPage()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/management/master',
      page: () => DashboardPage(child: MasterPage()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/management/threshold',
      page: () => DashboardPage(child: ThresholdPage()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/management/logtable',
      page: () => DashboardPage(child: ActivityLogTable()),
      binding: DashboardBinding(),
    ),
    // Design
    GetPage(
      name: '/dashboard/design',
      page: () => DashboardPage(child: DesignLayout()),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: '/dashboard/design/project',
      page: () => DashboardPage(child: ProjectLayout()),
      binding: DashboardBinding(),
    ),
  ];
}
