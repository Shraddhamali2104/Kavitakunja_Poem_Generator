import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'design_add_project.dart'; // <-- import your form page
import 'project_page_controller.dart'; // <-- import the controller
import 'package:flutter/foundation.dart' show kIsWeb;

class ProjectLayout extends StatefulWidget {
  const ProjectLayout({super.key});

  @override
  State<ProjectLayout> createState() => _ProjectLayoutState();
}

class _ProjectLayoutState extends State<ProjectLayout> {
  final ProjectPageController controller = Get.put(ProjectPageController());

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600 && screenWidth < 1200;
    final isDesktop = screenWidth >= 1200;

    return Material(
      color: Colors.white,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            color: Colors.white,
            padding: EdgeInsets.all(isWeb ? 24.0 : 16.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Column(
                  children: [
                    _buildHeader(isWeb),
                    const SizedBox(height: 24),
                    _buildContentArea(controller, isWeb, isTablet, isDesktop),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentArea(
    ProjectPageController controller,
    bool isWeb,
    bool isTablet,
    bool isDesktop,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.04).toInt()),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFDDDDDD)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Obx(() {
          if (controller.currentPage.value == 'add') {
            return ProjectForm();
          } else {
            if (controller.isLoading.value) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (controller.projectList.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No projects found.')),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.projectList.length,
              itemBuilder: (context, index) {
                final project = controller.projectList[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    title: Text(project.name ?? 'No Name'),
                    subtitle: Text('Model No: ${project.modelNo ?? 'N/A'}'),
                    trailing: Text(project.status ?? 'No Status'),
                  ),
                );
              },
            );
          }
        }),
      ),
    );
  }

  Widget _buildHeader(bool isWeb) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.04).toInt()),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFDDDDDD)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Project Management',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Manage your projects efficiently',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF444444),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          // ➕ Add Project Button
          ElevatedButton.icon(
            onPressed: () => controller.changePage('add'),
            icon: const Icon(Icons.add_task_outlined),
            label: const Text('Add Project'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              elevation: 0,
              shadowColor: Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}
