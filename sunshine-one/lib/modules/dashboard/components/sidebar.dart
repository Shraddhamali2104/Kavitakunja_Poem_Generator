import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import '../dashboard_controller.dart';
// import '../../../routes/app_routes.dart';

// Route constants (define here for now)
const String routeDashboard = '/dashboard';
const String routeHrBirthday = '/dashboard/hr/birthday';
const String routeHrManageEmployee = '/dashboard/hr/manage_employee';
const String routeHrAttendance = '/dashboard/hr/attendance';
const String routeHrLedger = '/dashboard/hr/ledger';
const String routeHrLedgerSalary = '/dashboard/hr/ledger/salary';
const String routeHrLedgerAdvance = '/dashboard/hr/ledger/advance';
const String routeHrHoliday = '/dashboard/hr/hr_services';
const String routeHrTodo = '/dashboard/hr/todo';
const String routeStoreItems = '/dashboard/store/items';
const String routeStoreAddItem = '/dashboard/store/items/add';
const String routeStoreBuyRM = '/dashboard/store/items/buy/rm';
const String routeStoreBuyAsset = '/dashboard/store/items/buy/asset';
const String routeStoreBuyService = '/dashboard/store/items/buy/service';
const String routeStoreGrn = '/dashboard/store/grn';
const String routeStoreGrnGst = '/dashboard/store/grn/gst';
const String routeStoreGrnEst = '/dashboard/store/grn/est';
const String routeStoreGrnFoc = '/dashboard/store/grn/foc';
const String routeStoreGrnReta = '/dashboard/store/grn/reta';
const String routeStoreGrnRetr = '/dashboard/store/grn/retr';
const String routeSalesCustomer = '/dashboard/sales/customer';
const String routePurchaseSuppliers = '/dashboard/purchase/suppliers';
const String routeManagementPermission = '/dashboard/management/permission';
const String routeManagementMaster = '/dashboard/management/master';
const String routeManagementThreshold = '/dashboard/management/threshold';
const String routeManagementLogTable = '/dashboard/management/logtable';
const String routeDesignProject = '/dashboard/design/project';
const String routeStoreAdjustmentLog = '/dashboard/store/adjustment_log';
const String routeStoreTransferLog = '/dashboard/store/transfer_log';
const String routeStoreStock = '/dashboard/store/stock';

class SidebarItem {
  final String title;
  final String route;
  final IconData icon;
  final List<SidebarItem>? children;
  final String sectionKey; // For expansion
  final String? tooltip;
  const SidebarItem({
    required this.title,
    required this.route,
    required this.icon,
    this.children,
    required this.sectionKey,
    this.tooltip,
  });
}

final List<SidebarItem> sidebarItems = [
  SidebarItem(
    title: 'Dashboard',
    route: routeDashboard,
    icon: Icons.dashboard,
    sectionKey: 'dashboard',
    tooltip: 'Dashboard Overview',
  ),
  // HR main item (routes to birthday, has expandable submenu)
  SidebarItem(
    title: 'HR',
    route: routeHrBirthday, // Route to birthday
    icon: Icons.people,
    sectionKey: 'hr',
    tooltip: 'HR Features',
    children: [
      SidebarItem(
        title: 'Manage Employee',
        route: routeHrManageEmployee,
        icon: Icons.people_outline,
        sectionKey: 'hr',
        tooltip: 'Manage Employee',
      ),
      SidebarItem(
        title: 'Attendance',
        route: routeHrAttendance,
        icon: Icons.calendar_today,
        sectionKey: 'hr',
        tooltip: 'Attendance',
      ),
      SidebarItem(
        title: 'Ledger',
        route: routeHrLedger,
        icon: Icons.account_balance_wallet,
        sectionKey: 'hr',
        tooltip: 'Ledger',
        children: [
          SidebarItem(
            title: 'Salary Ledger',
            route: routeHrLedgerSalary,
            icon: Icons.account_balance_wallet,
            sectionKey: 'hr',
            tooltip: 'Salary Ledger',
          ),
          SidebarItem(
            title: 'Advance Ledger',
            route: routeHrLedgerAdvance,
            icon: Icons.payment,
            sectionKey: 'hr',
            tooltip: 'Advance Ledger',
          ),
        ],
      ),
      SidebarItem(
        title: 'Holiday',
        route: routeHrHoliday,
        icon: Icons.event,
        sectionKey: 'hr',
        tooltip: 'Holiday',
      ),
      SidebarItem(
        title: 'Todo',
        route: routeHrTodo,
        icon: Icons.check_circle_outline,
        sectionKey: 'hr',
        tooltip: 'Todo',
      ),
      SidebarItem(
        title: 'Attendance Request',
        route: '/dashboard/hr/attendance/request',
        icon: Icons.assignment_turned_in,
        sectionKey: 'hr',
        tooltip: 'Attendance Request',
      ),
    ],
  ),
  SidebarItem(
    title: 'Store',
    route: routeStoreItems,
    icon: Icons.store,
    sectionKey: 'store',
    tooltip: 'Store Features',
    children: [
      SidebarItem(
        title: 'Items',
        route: routeStoreItems,
        icon: Icons.inventory,
        sectionKey: 'store',
        tooltip: 'Items',
      ),
      SidebarItem(
        title: 'GRN',
        route: routeStoreGrn,
        icon: Icons.receipt_long,
        sectionKey: 'store',
        tooltip: 'GRN',
        children: [
          SidebarItem(
            title: 'GST',
            route: routeStoreGrnGst,
            icon: Icons.receipt,
            sectionKey: 'store',
            tooltip: 'GST GRN',
          ),
          SidebarItem(
            title: 'EST',
            route: routeStoreGrnEst,
            icon: Icons.receipt,
            sectionKey: 'store',
            tooltip: 'EST GRN',
          ),
          SidebarItem(
            title: 'FOC',
            route: routeStoreGrnFoc,
            icon: Icons.receipt,
            sectionKey: 'store',
            tooltip: 'FOC GRN',
          ),
          SidebarItem(
            title: 'RETA',
            route: routeStoreGrnReta,
            icon: Icons.receipt,
            sectionKey: 'store',
            tooltip: 'RETA GRN',
          ),
          SidebarItem(
            title: 'RETR',
            route: routeStoreGrnRetr,
            icon: Icons.receipt,
            sectionKey: 'store',
            tooltip: 'RETR GRN',
          ),
        ],
      ),
      SidebarItem(
        title: 'Stock',
        route: routeStoreStock,
        icon: Icons.inventory_2,
        sectionKey: 'store',
        tooltip: 'Stock',
      ),
      SidebarItem(
        title: 'Transfer Log',
        route: routeStoreTransferLog,
        icon: Icons.swap_horiz,
        sectionKey: 'store',
        tooltip: 'Transfer Log',
      ),
      SidebarItem(
        title: 'Adjustment Log',
        route: routeStoreAdjustmentLog,
        icon: Icons.tune,
        sectionKey: 'store',
        tooltip: 'Adjustment Log',
      ),
           
    ],
  ),
  SidebarItem(
    title: 'Sales',
    route: routeSalesCustomer,
    icon: Icons.point_of_sale,
    sectionKey: 'sales',
    tooltip: 'Sales Features',
    children: [
      SidebarItem(
        title: 'Customer',
        route: routeSalesCustomer,
        icon: Icons.people_alt,
        sectionKey: 'sales',
        tooltip: 'Customer',
      ),
    ],
  ),
  SidebarItem(
    title: 'Purchase',
    route: routePurchaseSuppliers,
    icon: Icons.shopping_cart,
    sectionKey: 'purchase',
    tooltip: 'Purchase Features',
    children: [
      SidebarItem(
        title: 'Suppliers',
        route: routePurchaseSuppliers,
        icon: Icons.local_shipping,
        sectionKey: 'purchase',
        tooltip: 'Suppliers',
      ),
    ],
  ),
  SidebarItem(
    title: 'Design',
    route: routeDesignProject,
    icon: Icons.design_services,
    sectionKey: 'design',
    tooltip: 'Design Features',
    children: [
      SidebarItem(
        title: 'Project',
        route: routeSalesCustomer,
        icon: Icons.assessment_outlined,
        sectionKey: 'Design',
        tooltip: 'Project',
      ),
    ],
  ),
  SidebarItem(
    title: 'Management',
    route: routeManagementPermission,
    icon: Icons.admin_panel_settings,
    sectionKey: 'management',
    tooltip: 'Management Features',
    children: [
      SidebarItem(
        title: 'Permission',
        route: routeManagementPermission,
        icon: Icons.settings,
        sectionKey: 'management',
        tooltip: 'Permission',
      ),
      SidebarItem(
        title: 'Master',
        route: routeManagementMaster,
        icon: Icons.tune,
        sectionKey: 'management',
        tooltip: 'Master',
      ),
      SidebarItem(
        title: 'Threshold',
        route: routeManagementThreshold,
        icon: Icons.trending_up,
        sectionKey: 'management',
        tooltip: 'Threshold',
      ),
      SidebarItem(
        title: 'Log Table',
        route: routeManagementLogTable,
        icon: Icons.bar_chart,
        sectionKey: 'management',
        tooltip: 'Log Table',
      ),
    ],
  ),
];

class Sidebar extends StatefulWidget {
  const Sidebar({super.key});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {
    'dashboard': GlobalKey(),
    'hr': GlobalKey(),
    'store': GlobalKey(),
    'sales': GlobalKey(),
    'purchase': GlobalKey(),
    'design': GlobalKey(),
    'management': GlobalKey(),
  };

  // Only one section expanded at a time
  String? expandedSection;

  void _scrollToSection(String sectionKey) {
    final context = _sectionKeys[sectionKey]?.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 350), alignment: 0.1);
    }
  }

  void _toggleSection(String sectionKey) {
    setState(() {
      if (expandedSection == sectionKey) {
        expandedSection = null;
      } else {
        expandedSection = sectionKey;
        _scrollToSection(sectionKey);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final DashboardController controller = Get.find();
    return Obx(() {
      final bool collapsed = controller.sidebarCollapsed.value;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: collapsed ? 70 : 250,
        color: Colors.black,
        child: Column(
          children: [
            // Collapse/Expand button
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(
                  collapsed ? Icons.arrow_right : Icons.arrow_left,
                  color: Colors.white,
                ),
                onPressed: () => controller.sidebarCollapsed.value = !collapsed,
                tooltip: collapsed ? 'Expand' : 'Collapse',
              ),
            ),
            Expanded(
              child: ListView(
                controller: _scrollController,
                children: [
                  SizedBox(
                    height: collapsed ? 80 : 120,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.only(top: collapsed ? 10 : 20),
                        child: Image(
                          image: const AssetImage('assets/images/sunshine_logo.png'),
                          width: collapsed ? 60 : 140,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  ...sidebarItems.map((item) => _SidebarItemWidget(
                        item: item,
                        collapsed: collapsed,
                        expandedSection: expandedSection,
                        onSectionToggle: _toggleSection,
                        onSectionCollapse: () => setState(() => expandedSection = null),
                        sectionKeys: _sectionKeys,
                      )),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _SidebarItemWidget extends StatelessWidget {
  final SidebarItem item;
  final bool collapsed;
  final String? expandedSection;
  final void Function(String sectionKey) onSectionToggle;
  final VoidCallback onSectionCollapse;
  final Map<String, GlobalKey> sectionKeys;

  const _SidebarItemWidget({
    required this.item,
    required this.collapsed,
    required this.expandedSection,
    required this.onSectionToggle,
    required this.onSectionCollapse,
    required this.sectionKeys,
  });

  @override
  Widget build(BuildContext context) {
    final isExpandable = item.children != null && item.children!.isNotEmpty;
    final isExpanded = expandedSection == item.sectionKey;
    final bool isSelected = Get.currentRoute == item.route ||
        (isExpandable && item.children!.any((c) => Get.currentRoute == c.route));

    // Special handling for HR: label/icon tap routes, arrow toggles
    if (item.title == 'HR' && isExpandable) {
      Widget tile = ListTile(
        leading: Tooltip(
          message: item.tooltip ?? item.title,
          child: Icon(item.icon, color: Colors.white),
        ),
        title: collapsed
            ? null
            : Text(item.title, style: const TextStyle(color: Colors.white)),
        trailing: !collapsed
            ? GestureDetector(
                onTap: () => onSectionToggle(item.sectionKey),
                child: Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.white),
              )
            : null,
        selected: isSelected,
        selectedTileColor: Colors.white24,
        onTap: () {
          // Always route to birthday on label/icon tap
          Get.toNamed(item.route);
          if (!kIsWeb) Get.back();
        },
        contentPadding: EdgeInsets.symmetric(horizontal: collapsed ? 8 : 16),
        minLeadingWidth: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        hoverColor: Colors.white10,
        focusColor: Colors.white24,
      );
      if (collapsed) {
        tile = Tooltip(
          message: item.tooltip ?? item.title,
          child: tile,
        );
      }
      return Container(
        key: sectionKeys[item.sectionKey],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tile,
            if (isExpanded && !collapsed)
              Padding(
                padding: const EdgeInsets.only(left: 32.0),
                child: Column(
                  children: item.children!.map((child) => _SidebarChildItemWidget(
                        child: child,
                        collapsed: collapsed,
                        onSectionCollapse: onSectionCollapse,
                      )).toList(),
                ),
              ),
          ],
        ),
      );
    }

    // Default behavior for other items
    Widget tile = ListTile(
      leading: Tooltip(
        message: item.tooltip ?? item.title,
        child: Icon(item.icon, color: Colors.white),
      ),
      title: collapsed
          ? null
          : Text(item.title, style: const TextStyle(color: Colors.white)),
      trailing: isExpandable && !collapsed
          ? Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.white)
          : null,
      selected: isSelected,
      selectedTileColor: Colors.white24,
      onTap: () {
        if (isExpandable) {
          onSectionToggle(item.sectionKey);
        } else {
          Get.toNamed(item.route);
          if (!kIsWeb) Get.back();
        }
      },
      contentPadding: EdgeInsets.symmetric(horizontal: collapsed ? 8 : 16),
      minLeadingWidth: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      hoverColor: Colors.white10,
      focusColor: Colors.white24,
    );

    if (collapsed) {
      tile = Tooltip(
        message: item.tooltip ?? item.title,
        child: tile,
      );
    }

    return Container(
      key: sectionKeys[item.sectionKey],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          tile,
          if (isExpandable && isExpanded && !collapsed)
            Padding(
              padding: const EdgeInsets.only(left: 32.0),
              child: Column(
                children: item.children!.map((child) => _SidebarChildItemWidget(
                      child: child,
                      collapsed: collapsed,
                      onSectionCollapse: onSectionCollapse,
                    )).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _SidebarChildItemWidget extends StatelessWidget {
  final SidebarItem child;
  final bool collapsed;
  final VoidCallback onSectionCollapse;

  const _SidebarChildItemWidget({
    required this.child,
    required this.collapsed,
    required this.onSectionCollapse,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Tooltip(
        message: child.tooltip ?? child.title,
        child: Icon(child.icon, color: Colors.white70),
      ),
      title: collapsed
          ? null
          : Text(child.title, style: const TextStyle(color: Colors.white70, fontSize: 15)),
      selected: Get.currentRoute == child.route,
      selectedTileColor: Colors.white12,
      onTap: () {
        Get.toNamed(child.route);
        onSectionCollapse();
        if (!kIsWeb) Get.back();
      },
      contentPadding: EdgeInsets.symmetric(horizontal: collapsed ? 8 : 16),
      minLeadingWidth: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      hoverColor: Colors.white10,
      focusColor: Colors.white24,
    );
  }
}
