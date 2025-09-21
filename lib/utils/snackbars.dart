import 'package:flutter/material.dart';
import 'package:get/get.dart';

OverlayEntry showLoadingSnackbar(BuildContext context, String message) {
  final overlay = OverlayEntry(
    builder: (context) => Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(message, style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Overlay.of(context).insert(overlay);
  return overlay;
}

void showSucessSnackbar({
  required BuildContext context,
  required String message,
  Color colorText = Colors.black,
}) {
  Color backgroundColor = Colors.green;
  IconData icon = Icons.check_circle;

  Get.rawSnackbar(
    messageText: Row(
      children: [
        Icon(icon, color: Colors.white),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: colorText),
          ),
        ),
      ],
    ),
    backgroundColor: backgroundColor,
    snackPosition: SnackPosition.TOP,
    borderRadius: 8,
    margin: EdgeInsets.all(10),
    duration: Duration(seconds: 3),
  );
}

void showErrorSnackbar({
  required BuildContext context,
  required String message,
  Color colorText = Colors.black,
}) {
  Color backgroundColor = Colors.red;
  IconData icon = Icons.error;

  Get.rawSnackbar(
    messageText: Row(
      children: [
        Icon(icon, color: Colors.white),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: colorText),
          ),
        ),
      ],
    ),
    backgroundColor: backgroundColor,
    snackPosition: SnackPosition.TOP,
    borderRadius: 8,
    margin: EdgeInsets.all(10),
    duration: Duration(seconds: 3),
  );
}

void showInfoSnackbar({
  required BuildContext context,
  required String message,
  Color colorText = Colors.black,
}) {
  Color backgroundColor = Colors.blue;
  IconData icon = Icons.info;

  Get.rawSnackbar(
    messageText: Row(
      children: [
        Icon(icon, color: Colors.white),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: colorText),
          ),
        ),
      ],
    ),
    backgroundColor: backgroundColor,
    snackPosition: SnackPosition.TOP,
    borderRadius: 8,
    margin: EdgeInsets.all(10),
    duration: Duration(seconds: 3),
  );
}
