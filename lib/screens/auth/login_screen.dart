import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/cloud/cloud_sync_dialog.dart';
import '../../services/cloud/data_restore_dialog.dart';
import '../../services/cloud/firebase_cloud_storage_service.dart';
import '../../state/app_providers.dart';
import '../../widgets/primary_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  static const routeName = 'login';
  static const routePath = '/login';

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authNotifierProvider.notifier).signInWithGoogle();
      if (mounted) {
        // Wait a bit for Firebase Auth to update currentUser state
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Get user email from Firebase Auth
        final firebaseUser = FirebaseAuth.instance.currentUser;
        final userEmail = firebaseUser?.email;
        print('[LoginScreen] User authenticated with email: $userEmail');
        
        // Navigate to PIN setup if auth successful
        // Data restoration will happen after PIN is set
        if (mounted) {
          context.go('/pin-setup');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showSkipWarning() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Skip sign-in?'),
        content: const Text(
          'If you skip sign-in, your data cannot be restored if the app is removed from your phone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Skip anyway'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await ref.read(authNotifierProvider.notifier).skipAuth();
      context.go('/pin-setup');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                Icons.lock_outline,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 32),
              Text(
                'Welcome',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Sign in to save your data',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              PrimaryButton(
                label: 'Sign in with Google',
                expanded: true,
                onPressed: _isLoading ? null : _signInWithGoogle,
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: _isLoading ? null : _showSkipWarning,
                child: const Text('Skip'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

