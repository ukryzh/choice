import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/user_profile.dart';
import '../../services/auth/auth_service.dart';
import '../../services/cloud/cloud_sync_dialog.dart';
import '../../services/cloud/cloud_storage_service.dart';
import '../../state/app_providers.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/primary_button.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const routeName = 'profile';
  static const routePath = '/profile';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: SafeArea(
        child: profile.when(
          data: (data) => _ProfileBody(profile: data),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => EmptyState(
            title: 'Profile unavailable',
            message: error.toString(),
            action: PrimaryButton(
              label: 'Retry',
              onPressed: () => ref.invalidate(userProfileProvider),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavigation(),
    );
  }
}

class _ProfileBody extends ConsumerStatefulWidget {
  const _ProfileBody({required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody> {
  bool _isGoogleLoading = false;
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isCloudBackupLoading = false;

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final authState = ref.watch(authNotifierProvider);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: theme.colorScheme.secondary,
              child: Text(
                profile.displayName.isNotEmpty
                    ? profile.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(fontSize: 24, color: Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          profile.displayName,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () => _editName(profile.displayName),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (authState.provider == AuthProvider.google &&
                      profile.email != null &&
                      profile.email!.isNotEmpty)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            profile.email!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ),
                        if (authState.provider == AuthProvider.google)
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            tooltip: 'Change email',
                            onPressed: () => _changeEmailWithGoogle(),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Change PIN
        PrimaryButton(
          label: 'Change PIN',
          expanded: true,
          onPressed: _showChangePinDialog,
        ),
        const SizedBox(height: 16),

        // Save my data
        PrimaryButton(
          label: _isExporting ? 'Exporting...' : 'Save my data',
          expanded: true,
          onPressed: _isExporting ? null : _exportData,
        ),
        const SizedBox(height: 16),

        // Load my data
        PrimaryButton(
          label: _isImporting ? 'Importing...' : 'Load my data',
          expanded: true,
          onPressed: _isImporting ? null : _importData,
        ),
        const SizedBox(height: 16),

        // Delete all data
        PrimaryButton(
          label: 'Delete all data',
          expanded: true,
          onPressed: _showDeleteDataOptions,
        ),
        const SizedBox(height: 16),

        // Cloud backup section - only show if authenticated with Google
        if (authState.provider == AuthProvider.google)
          _CloudBackupSection(
            isCloudBackupLoading: _isCloudBackupLoading,
            onEnableBackup: _enableCloudBackup,
            onDisableBackup: _disableCloudBackup,
          ),
        
        // Sign in with Google - only show if NOT authenticated
        if (authState.provider != AuthProvider.google) ...[
          Text(
            'Connect your account',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: _isGoogleLoading ? 'Connecting...' : 'Sign in with Google',
            expanded: true,
            onPressed: _isGoogleLoading ? null : _connectGoogle,
          ),
          const SizedBox(height: 24),
        ],

        // Sign out - only show if authenticated with Google
        if (authState.provider == AuthProvider.google) ...[
          const SizedBox(height: 8),
          PrimaryButton(
            label: 'Sign out',
            expanded: true,
            onPressed: _signOut,
          ),
          const SizedBox(height: 24),
        ],

        ListTile(
          title: const Text('Terms & Conditions'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/terms'),
        ),
        ListTile(
          title: const Text('Privacy policy'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/privacy-policy'),
        ),
        ListTile(
          title: const Text('FAQ'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/faq'),
        ),
      ],
    );
  }

  Future<void> _editName(String currentName) async {
    final controller = TextEditingController(text: currentName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      await ref.read(userProfileProvider.notifier).updateDisplayName(result);
    }
  }

  Future<void> _changeEmailWithGoogle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change email'),
        content: const Text(
          'To change your email, you will need to sign in with a different Google account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isGoogleLoading = true);
      try {
        // Switch account without clearing PIN
        await ref.read(authNotifierProvider.notifier).switchAccount();
        
        // Sign in with new Google account
        await ref.read(authNotifierProvider.notifier).signInWithGoogle();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email changed successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to change email: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isGoogleLoading = false);
        }
      }
    }
  }

  Future<void> _showChangePinDialog() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final pinRegex = RegExp(r'^\d{4}$');
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change PIN'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentController,
                  decoration: const InputDecoration(labelText: 'Current PIN'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  obscureText: true,
                  maxLength: 4,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (v) =>
                      v != null && pinRegex.hasMatch(v) ? null : 'Enter 4 digits',
                ),
                TextFormField(
                  controller: newController,
                  decoration: const InputDecoration(labelText: 'New PIN'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  obscureText: true,
                  maxLength: 4,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (v) =>
                      v != null && pinRegex.hasMatch(v) ? null : 'Enter 4 digits',
                ),
                TextFormField(
                  controller: confirmController,
                  decoration: const InputDecoration(labelText: 'Confirm new PIN'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  obscureText: true,
                  maxLength: 4,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (v) {
                    if (v == null || !pinRegex.hasMatch(v)) {
                      return 'Enter 4 digits';
                    }
                    if (v != newController.text) {
                      return 'PINs do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Changing your PIN will replace the current code and will be required for future logins.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == true && mounted) {
      try {
        await ref.read(authNotifierProvider.notifier).changePin(
              currentPin: currentController.text,
              newPin: newController.text,
            );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN updated')),
        );
      } catch (e) {
        final message = e is StateError
            ? 'Current PIN is incorrect'
            : 'Failed to change PIN: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  Future<void> _connectGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      await ref.read(authNotifierProvider.notifier).signInWithGoogle();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connected with Google')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google sign-in failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _enableCloudBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enable cloud backup'),
        content: const Text(
          'You are enabling cloud backup of your data. Your data is sent to the server in encrypted form and cannot be read by third parties. You can disable cloud backup at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isCloudBackupLoading = true);
      try {
        final cloudStorage = ref.read(cloudStorageServiceProvider);
        await cloudStorage.initialize();
        await cloudStorage.enableSync();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cloud backup enabled')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to enable cloud backup: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isCloudBackupLoading = false);
          ref.invalidate(cloudBackupEnabledProvider);
        }
      }
    }
  }

  Future<void> _disableCloudBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Disable cloud backup'),
        content: const Text(
          'You are disabling cloud backup of your data. You will not be able to recover your data if you lose your device. You can enable cloud backup of your data at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Disable'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isCloudBackupLoading = true);
      try {
        final cloudStorage = ref.read(cloudStorageServiceProvider);
        await cloudStorage.initialize();
        await cloudStorage.disableSync();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cloud backup disabled')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to disable cloud backup: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isCloudBackupLoading = false);
          ref.invalidate(cloudBackupEnabledProvider);
        }
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text(
          'Are you sure you want to sign out? You will need to sign in again to access your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(authNotifierProvider.notifier).signOut();
        // Navigation will be handled by router based on auth state
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to sign out: $e')),
          );
        }
      }
    }
  }

  Future<void> _exportData() async {
    setState(() => _isExporting = true);
    try {
      final exportService = ref.read(dataExportServiceProvider);
      final filePath = await exportService.exportAllData();

      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Report exported'),
            content: Text(
              'Your cycle report has been saved as a PDF file:\n$filePath\n\nYou can find it in your Downloads or Documents folder.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () async {
                  await Share.shareXFiles(
                    [XFile(filePath)],
                    text: 'My cycle report',
                  );
                },
                child: const Text('Share'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _importData() async {
    setState(() => _isImporting = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (!mounted || picked == null || picked.files.isEmpty) return;

      final path = picked.files.single.path;
      if (path == null || path.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to read selected file')),
        );
        return;
      }

      final exportService = ref.read(dataExportServiceProvider);
      final importedEntries = await exportService.importFromPdfPath(path);
      if (importedEntries.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No importable data found in this PDF')),
        );
        return;
      }

      final existing = ref.read(cycleEntriesProvider).valueOrNull ?? const [];
      if (existing.isNotEmpty) {
        final proceed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: const Text(
              'Your calendar already contains data. If you upload new data, the old data will not be saved. Do you want to proceed?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes'),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }

      await ref.read(cycleEntriesProvider.notifier).replaceAll(importedEntries);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data imported')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to import data: $e')),
      );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _showDeleteDataOptions() async {
    final choice = await showDialog<_DeleteChoice>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('Delete all data'),
        content: const Text(
          'You can delete your data locally and in the cloud.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_DeleteChoice.cloud),
            child: const Text('Delete from cloud'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_DeleteChoice.local),
            child: const Text('Delete locally'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_DeleteChoice.everywhere),
            child: const Text('Delete everywhere'),
          ),
        ],
      ),
    );

    if (!mounted || choice == null) return;

    switch (choice) {
      case _DeleteChoice.cloud:
        await _confirmDeleteFromCloud();
        break;
      case _DeleteChoice.local:
        await _confirmDeleteLocally();
        break;
      case _DeleteChoice.everywhere:
        await _confirmDeleteEverywhere();
        break;
    }
  }

  Future<void> _confirmDeleteFromCloud() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Delete from cloud'),
        content: const Text(
          'Your data will be deleted from the cloud and you will not be able to restore it if you lose your device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final cloudStorage = ref.read(cloudStorageServiceProvider);
        await cloudStorage.initialize();
        await cloudStorage.deleteAllUserData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cloud data deletion requested')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete data from cloud: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteLocally() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Delete locally'),
        content: const Text(
          'Your data will be deleted from this device. If you signed in, it can be restored from the cloud.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // Delete all Calendar data (cycle entries) and refresh provider
        await ref.read(cycleEntriesProvider.notifier).clearAll();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Local calendar data deleted')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete local data: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteEverywhere() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Delete everywhere'),
        content: const Text(
          'Your data will be deleted from the cloud and from this device without the possibility of recovery.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final cloudStorage = ref.read(cloudStorageServiceProvider);
        await cloudStorage.initialize();
        await cloudStorage.deleteAllUserData();

        // Delete all Calendar data locally as well and refresh provider
        await ref.read(cycleEntriesProvider.notifier).clearAll();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All calendar data deletion requested')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete data: $e')),
        );
      }
    }
  }
}

class _CloudBackupSection extends ConsumerStatefulWidget {
  const _CloudBackupSection({
    super.key,
    required this.isCloudBackupLoading,
    required this.onEnableBackup,
    required this.onDisableBackup,
  });

  final bool isCloudBackupLoading;
  final VoidCallback onEnableBackup;
  final VoidCallback onDisableBackup;

  @override
  ConsumerState<_CloudBackupSection> createState() => _CloudBackupSectionState();
}

class _CloudBackupSectionState extends ConsumerState<_CloudBackupSection> {
  @override
  Widget build(BuildContext context) {
    final status = ref.watch(cloudBackupEnabledProvider);
    // Keep showing previous value while refreshing to avoid flicker.
    final isEnabled = status.value ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cloud backup',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: widget.isCloudBackupLoading
              ? (isEnabled ? 'Disabling...' : 'Enabling...')
              : (isEnabled ? 'Disable cloud backup' : 'Enable cloud backup'),
          expanded: true,
          onPressed: widget.isCloudBackupLoading
              ? null
              : (isEnabled ? widget.onDisableBackup : widget.onEnableBackup),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

enum _DeleteChoice {
  cloud,
  local,
  everywhere,
}

