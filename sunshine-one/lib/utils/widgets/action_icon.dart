import 'package:flutter/material.dart';

Widget editIcon({required String tooltip, required VoidCallback onPressed}) {
  return SizedBox(
    width: 28,
    height: 28,
    child: IconButton(
      icon: const Icon(Icons.edit, size: 14),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.orange.shade50,
        foregroundColor: Colors.orange.shade700,
        padding: const EdgeInsets.all(2),
      ),
    ),
  );
}

Widget viewIcon({required String tooltip, required VoidCallback onPressed}) {
  return SizedBox(
    width: 28,
    height: 28,
    child: IconButton(
      icon: const Icon(Icons.visibility, size: 14),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.blue.shade50,
        foregroundColor: Colors.blue.shade700,
        padding: const EdgeInsets.all(2),
      ),
    ),
  );
}
Widget statusChip({
  required String value,
  required Color color,
}) {
  return Align(
    alignment: Alignment.center,
    child: Chip(
      label: Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: color.withValues(alpha: 0.1),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      side: BorderSide.none,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );
}

