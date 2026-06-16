import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/cloud/data_restore_dialog.dart';
import '../../services/cloud/firebase_cloud_storage_service.dart';
import '../../state/app_providers.dart';
import '../../widgets/primary_button.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  static const routeName = 'pin-setup';
  static const routePath = '/pin-setup';

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final List<TextEditingController> _controllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String? _errorMessage;

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      _controllers[index].text = value[value.length - 1];
    }

    final currentPin = _controllers.map((c) => c.text).join();
    
    if (!_isConfirming) {
      _pin = currentPin;
      if (_pin.length == 4) {
        setState(() {
          _isConfirming = true;
          _errorMessage = null;
        });
        // Clear all fields
        for (final controller in _controllers) {
          controller.clear();
        }
        // Focus first field
        _focusNodes[0].requestFocus();
      } else if (value.isNotEmpty && index < 3) {
        _focusNodes[index + 1].requestFocus();
      }
    } else {
      _confirmPin = currentPin;
      if (_confirmPin.length == 4) {
        if (_pin == _confirmPin) {
          _savePin();
        } else {
          setState(() {
            _errorMessage = 'PIN codes do not match';
            _isConfirming = false;
            _pin = '';
            _confirmPin = '';
          });
          for (final controller in _controllers) {
            controller.clear();
          }
          _focusNodes[0].requestFocus();
        }
      } else if (value.isNotEmpty && index < 3) {
        _focusNodes[index + 1].requestFocus();
      }
    }
  }

  Future<void> _savePin() async {
    // Cloud restore must happen BEFORE setPin(), because setPin() changes
    // auth state to authenticatedWithPin which causes the router to rebuild
    // and unmounts this screen — killing any mounted-guarded async chains.
    try {
      await _checkAndRestoreCloudData();
    } catch (_) {
      // Don't block PIN setup if cloud restore fails
    }

    try {
      await ref.read(authNotifierProvider.notifier).setPin(_pin);
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to save PIN: $e';
        });
      }
    }
  }

  Future<void> _checkAndRestoreCloudData() async {
    try {
      // Get user email from Firebase Auth
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final userEmail = firebaseUser?.email;
      
      if (userEmail == null || userEmail.isEmpty) {
        print('[PinSetupScreen] No email found, skipping data check');
        return;
      }
      
      print('[PinSetupScreen] ===== Checking for cloud data for email: $userEmail =====');
      
      // Initialize cloud storage and encryption service
      final cloudStorage = ref.read(cloudStorageServiceProvider);
      final encryptionService = ref.read(encryptionServiceProvider);
      
      await cloudStorage.initialize();
      await encryptionService.initialize();
      
      // Check if user has data in Firestore by email
      bool hasCloudData = false;
      int entryCount = 0;
      String? foundUserId;
      
      try {
        // First check by current userId
        print('[PinSetupScreen] Step 1: Checking data for current userId...');
        hasCloudData = await cloudStorage.hasCloudData();
        print('[PinSetupScreen] hasCloudData (by current userId) result: $hasCloudData');
        
        // If no data found, try to find by email
        if (!hasCloudData && cloudStorage is FirebaseCloudStorageService) {
          print('[PinSetupScreen] Step 2: No data for current userId, searching by email...');
          final firebaseStorage = cloudStorage as FirebaseCloudStorageService;
          foundUserId = await firebaseStorage.findUserIdByEmail(userEmail);
          
          if (foundUserId != null) {
            print('[PinSetupScreen] Step 3: Found userId $foundUserId for email $userEmail');
            // Check if this userId has cycle entries
            print('[PinSetupScreen] Step 4: Downloading cycle entries for found userId...');
            final encryptedMap = await firebaseStorage.downloadAllRecordsForUserId(
              foundUserId,
              'cycle_entry',
            );
            
            print('[PinSetupScreen] Step 5: Downloaded ${encryptedMap.length} encrypted records');
            
            if (encryptedMap.isNotEmpty) {
              hasCloudData = true;
              entryCount = encryptedMap.length;
              print('[PinSetupScreen] ✓ Found $entryCount cycle entries for email $userEmail');
            } else {
              print('[PinSetupScreen] ✗ No cycle entries found for userId $foundUserId');
            }
          } else {
            print('[PinSetupScreen] ✗ No userId found for email $userEmail');
          }
        } else if (hasCloudData) {
          // If data found by userId, get count
          print('[PinSetupScreen] Data found for current userId, getting count...');
          final restoreService = ref.read(dataRestoreServiceProvider);
          entryCount = await restoreService.getCloudCycleEntriesCount();
          print('[PinSetupScreen] Found $entryCount cycle entries for current userId');
        }
      } catch (e) {
        print('[PinSetupScreen] ✗ ERROR checking cloud data: $e');
        print('[PinSetupScreen] Stack trace: ${StackTrace.current}');
        // Continue even if check fails
      }
      
      print('[PinSetupScreen] Final result: hasCloudData=$hasCloudData, entryCount=$entryCount');
      
      // If cloud has data, offer to restore
      if (hasCloudData && entryCount > 0 && mounted) {
        print('[PinSetupScreen] Offering to restore $entryCount entries');
        
        // Show the dialog and restore if user agrees
        final shouldRestore = await showDataRestoreDialog(
          context,
          entryCount: entryCount,
        );
        
        if (shouldRestore && mounted) {
          // Enable sync temporarily for restoration if not already enabled
          final wasEnabled = cloudStorage.isEnabled;
          if (!wasEnabled) {
            await cloudStorage.enableSync();
          }
          
          try {
            // Show loading indicator
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const Center(
                child: CircularProgressIndicator(),
              ),
            );
            
            // Restore data
            final restoreService = ref.read(dataRestoreServiceProvider);
            final restoredCount = await restoreService.restoreCycleEntries(
              alternativeUserId: foundUserId,
            );
            
            print('[PinSetupScreen] Restored $restoredCount entries');
            
            // Force refresh cycle entries provider to update UI
            ref.invalidate(cycleEntriesProvider);
            
            // Wait for provider to reload
            try {
              await ref.read(cycleEntriesProvider.future);
              print('[PinSetupScreen] Cycle entries provider refreshed, entries loaded');
            } catch (e) {
              print('[PinSetupScreen] Error refreshing provider: $e');
            }
            
            // Wait a bit more to ensure UI updates
            await Future.delayed(const Duration(milliseconds: 500));
            
            if (mounted) {
              Navigator.of(context).pop(); // Close loading dialog
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Восстановлено $restoredCount ${restoredCount == 1 ? 'запись' : restoredCount < 5 ? 'записи' : 'записей'} из облака',
                  ),
                ),
              );
            }
          } catch (e) {
            print('[PinSetupScreen] Error restoring data: $e');
            if (mounted) {
              Navigator.of(context).pop(); // Close loading dialog
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Не удалось восстановить данные: $e'),
                ),
              );
              
              // If restoration failed and we enabled sync just for restore, disable it
              if (!wasEnabled) {
                await cloudStorage.disableSync();
              }
            }
          }
        }
      } else {
        print('[PinSetupScreen] No cloud data found for email $userEmail');
      }
    } catch (e) {
      print('[PinSetupScreen] Error in _checkAndRestoreCloudData: $e');
      // Don't block PIN setup if data check fails
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up PIN'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isConfirming ? Icons.lock_outline : Icons.pin,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 32),
              Text(
                _isConfirming ? 'Confirm your PIN' : 'Set a 4-digit PIN',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _isConfirming
                    ? 'Enter your PIN again to confirm'
                    : 'Enter 4 digits to protect your data',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return Container(
                    width: 60,
                    height: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      obscureText: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                      ),
                      onChanged: (value) => _onDigitChanged(index, value),
                    ),
                  );
                }),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}







