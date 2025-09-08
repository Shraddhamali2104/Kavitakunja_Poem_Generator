import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

class SnackbarUtils {
  static void showSuccess(String message) {
    toastification.show(
      type: ToastificationType.success,
      style: ToastificationStyle.minimal,
      title: const Text("Success"),
      description: Text(message),
      autoCloseDuration: const Duration(seconds: 4),
      alignment: Alignment.topRight, // 👈 changed
      showProgressBar: true,
      icon: const Icon(Icons.check_circle, color: Colors.green),
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
    );
  }

  static void showError(String message) {
    toastification.show(
      type: ToastificationType.error,
      style: ToastificationStyle.minimal,
      title: const Text("Error"),
      description: Text(message),
      autoCloseDuration: const Duration(seconds: 4),
      alignment: Alignment.topRight, // 👈 changed
      showProgressBar: true,
      icon: const Icon(Icons.cancel, color: Colors.red),
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
    );
  }

  static void showInfo(String message) {
    toastification.show(
      type: ToastificationType.info,
      style: ToastificationStyle.minimal,
      title: const Text("Info"),
      description: Text(message),
      autoCloseDuration: const Duration(seconds: 4),
      alignment: Alignment.topRight, // 👈 changed
      showProgressBar: true,
      icon: const Icon(Icons.info, color: Colors.blue),
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
    );
  }
}
