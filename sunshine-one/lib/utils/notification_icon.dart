import 'package:flutter/material.dart';

class NotificationIcon extends StatelessWidget {
  final bool hasNewNotification;
  final VoidCallback onPressed;

  const NotificationIcon({
    super.key,
    required this.hasNewNotification,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(
            Icons.notifications_outlined,
            color: Colors.white,
          ),
          onPressed: onPressed,
        ),
        if (hasNewNotification)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              height: 10,
              width: 10,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
