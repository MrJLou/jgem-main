import 'package:flutter/material.dart';

class ErrorDialogUtils {
  /// Shows an error dialog with the provided message
  static Future<void> showErrorDialog({
    required BuildContext context,
    required String title,
    required String message,
    String? buttonText,
    VoidCallback? onPressed,
  }) async {
    if (!context.mounted) return;
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red[600],
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: onPressed ?? () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(buttonText ?? 'OK'),
            ),
          ],
        );
      },
    );
  }

  /// Shows a success dialog with the provided message
  static Future<void> showSuccessDialog({
    required BuildContext context,
    required String title,
    required String message,
    String? buttonText,
    VoidCallback? onPressed,
  }) async {
    if (!context.mounted) return;
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Colors.green[600],
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: onPressed ?? () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(buttonText ?? 'OK'),
            ),
          ],
        );
      },
    );
  }

  /// Shows a warning dialog with the provided message
  static Future<void> showWarningDialog({
    required BuildContext context,
    required String title,
    required String message,
    String? buttonText,
    VoidCallback? onPressed,
  }) async {
    if (!context.mounted) return;
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_outlined,
                color: Colors.orange[600],
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: onPressed ?? () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(buttonText ?? 'OK'),
            ),
          ],
        );
      },
    );
  }

  /// Shows an info dialog with the provided message
  static Future<void> showInfoDialog({
    required BuildContext context,
    required String title,
    required String message,
    String? buttonText,
    VoidCallback? onPressed,
  }) async {
    if (!context.mounted) return;
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.blue[600],
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: onPressed ?? () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(buttonText ?? 'OK'),
            ),
          ],
        );
      },
    );
  }

  /// Shows a simple error dialog with default title
  static Future<void> showSimpleErrorDialog({
    required BuildContext context,
    required String message,
    String? buttonText,
    VoidCallback? onPressed,
  }) async {
    return showErrorDialog(
      context: context,
      title: 'Error',
      message: message,
      buttonText: buttonText,
      onPressed: onPressed,
    );
  }

  /// Shows a simple success dialog with default title
  static Future<void> showSimpleSuccessDialog({
    required BuildContext context,
    required String message,
    String? buttonText,
    VoidCallback? onPressed,
  }) async {
    return showSuccessDialog(
      context: context,
      title: 'Success',
      message: message,
      buttonText: buttonText,
      onPressed: onPressed,
    );
  }

  /// Shows a simple warning dialog with default title
  static Future<void> showSimpleWarningDialog({
    required BuildContext context,
    required String message,
    String? buttonText,
    VoidCallback? onPressed,
  }) async {
    return showWarningDialog(
      context: context,
      title: 'Warning',
      message: message,
      buttonText: buttonText,
      onPressed: onPressed,
    );
  }
}
