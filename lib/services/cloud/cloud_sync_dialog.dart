import 'package:flutter/material.dart';

/// Dialog to ask user if they want to enable cloud sync
/// Shows after successful Google sign-in
Future<bool> showCloudSyncDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Enable Cloud Sync?'),
      content: const Text(
        'Would you like to enable cloud sync? Your data will be encrypted and stored securely in the cloud, allowing you to access it from multiple devices.\n\n'
        'You can change this setting later in Profile.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not now'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Enable'),
        ),
      ],
    ),
  );

  return result ?? false;
}






