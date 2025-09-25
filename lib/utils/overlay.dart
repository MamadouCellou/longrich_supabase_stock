import 'package:flutter/material.dart';

OverlayEntry? _loaderOverlay;

void showBlockingLoader(BuildContext context, String message) {
  if (_loaderOverlay != null) return; // éviter doublons

  _loaderOverlay = OverlayEntry(
    builder: (_) => Stack(
      children: [
        // Fond semi-transparent
        Positioned.fill(
          child: Container(color: Colors.black54),
        ),
        // Loader + message au centre
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Overlay.of(context).insert(_loaderOverlay!);
}

void hideBlockingLoader() {
  _loaderOverlay?.remove();
  _loaderOverlay = null;
}
