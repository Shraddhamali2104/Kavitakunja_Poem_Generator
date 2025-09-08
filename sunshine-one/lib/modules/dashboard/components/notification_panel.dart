
import 'package:flutter/material.dart';


class NotificationPanel extends StatelessWidget {
  final List<Map<String, String>> notifications;

  const NotificationPanel({Key? key, required this.notifications})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.28,
        height: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Notifications",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            Expanded(
              child: notifications.isEmpty
                  ? const Center(child: Text("No notifications"))
                  : ListView.builder(
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final notif = notifications[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.notifications,
                            color: Colors.blue,
                          ),
                          title: Text(
                            notif['title'] ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            "${notif['details'] ?? ''}\n${notif['time'] ?? ''}",
                            style: TextStyle(fontSize: 12),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

