import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';

import '../../models/cycle_entry.dart';
import '../local/cycle_repository.dart';
import 'cloud_storage_service.dart';
import 'encryption_service.dart';
import 'firebase_cloud_storage_service.dart';
import 'syncable_repository_mixin.dart';

/// Service for restoring data from cloud storage to local storage
class DataRestoreService {
  DataRestoreService({
    required CloudStorageService cloudStorage,
    required EncryptionService encryptionService,
    required CycleRepository cycleRepository,
  })  : _cloudStorage = cloudStorage,
        _encryptionService = encryptionService,
        _cycleRepository = cycleRepository;

  final CloudStorageService _cloudStorage;
  final EncryptionService _encryptionService;
  final CycleRepository _cycleRepository;

  /// Restore cycle entries from cloud storage
  /// [alternativeUserId] - optional userId to use instead of current user's userId
  /// Returns the number of restored entries
  Future<int> restoreCycleEntries({String? alternativeUserId}) async {
    try {
      // Use UID-derived key when a Firebase user is signed in so data can
      // be decrypted after reinstall (random key stored in secure storage
      // is deleted on Android uninstall).
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        await _encryptionService.initializeForUser(firebaseUser.uid);
      } else {
        await _encryptionService.initialize();
      }

      // Create sync mixin for cycle entries
      final syncMixin = CycleEntrySyncMixin(
        cloudStorage: _cloudStorage,
        encryptionService: _encryptionService,
      );

      // Temporarily enable sync to download data
      final wasEnabled = _cloudStorage.isEnabled;
      if (!wasEnabled) {
        await _cloudStorage.initialize();
        await _cloudStorage.enableSync();
      }

      try {
        // Download all cycle entries from cloud
        var cloudEntries = await syncMixin.syncAllFromCloud();

        // If alternativeUserId is provided, use it to download data
        if (cloudEntries.isEmpty && alternativeUserId != null && _cloudStorage is FirebaseCloudStorageService) {
          print('[DataRestoreService] Using alternative userId: $alternativeUserId');
          final firebaseStorage = _cloudStorage as FirebaseCloudStorageService;
          // Download records using alternative userId
          final encryptedMap = await firebaseStorage.downloadAllRecordsForUserId(
            alternativeUserId,
            'cycle_entry',
          );
          
          if (encryptedMap.isNotEmpty) {
            print('[DataRestoreService] Decrypting ${encryptedMap.length} records...');
            // Decrypt entries
            cloudEntries = <CycleEntry>[];
            for (final entry in encryptedMap.entries) {
              try {
                final decrypted = await _encryptionService.decryptRecord(entry.value);
                final record = CycleEntry.fromJson(
                  (jsonDecode(decrypted) as Map<String, dynamic>),
                );
                if (record != null) {
                  cloudEntries.add(record);
                }
              } catch (e) {
                print('[DataRestoreService] Error decrypting record ${entry.key}: $e');
              }
            }
            print('[DataRestoreService] Successfully decrypted ${cloudEntries.length} entries');
          }
        } else if (cloudEntries.isEmpty && _cloudStorage is FirebaseCloudStorageService) {
          // If no data found for current userId and no alternativeUserId, try to find by email
          final firebaseStorage = _cloudStorage as FirebaseCloudStorageService;
          final userEmail = await _getCurrentUserEmail();
          if (userEmail != null) {
            print('[DataRestoreService] No data for current userId, searching by email: $userEmail');
            final foundUserId = await firebaseStorage.findUserIdByEmail(userEmail);
            if (foundUserId != null) {
              print('[DataRestoreService] Found userId $foundUserId for email $userEmail, downloading data...');
              // Download records using found userId
              final encryptedMap = await firebaseStorage.downloadAllRecordsForUserId(
                foundUserId,
                'cycle_entry',
              );
              
              if (encryptedMap.isNotEmpty) {
                print('[DataRestoreService] Decrypting ${encryptedMap.length} records...');
                // Decrypt entries
                cloudEntries = <CycleEntry>[];
                for (final entry in encryptedMap.entries) {
                  try {
                    final decrypted = await _encryptionService.decryptRecord(entry.value);
                    final record = CycleEntry.fromJson(
                      (jsonDecode(decrypted) as Map<String, dynamic>),
                    );
                    if (record != null) {
                      cloudEntries.add(record);
                    }
                  } catch (e) {
                    print('[DataRestoreService] Error decrypting record ${entry.key}: $e');
                  }
                }
                print('[DataRestoreService] Successfully decrypted ${cloudEntries.length} entries');
              }
            }
          }
        }

        if (cloudEntries.isEmpty) {
          return 0;
        }

        // Get existing local entries
        final localEntries = await _cycleRepository.fetchEntries();
        final localIds = localEntries.map((e) => e.id).toSet();

        // Merge: keep local entries, add new ones from cloud
        final entriesToSave = <CycleEntry>[];
        
        // Add all local entries
        entriesToSave.addAll(localEntries);
        
        // Add cloud entries that don't exist locally
        for (final cloudEntry in cloudEntries) {
          if (!localIds.contains(cloudEntry.id)) {
            entriesToSave.add(cloudEntry);
          } else {
            // If entry exists locally, use the one with later timestamp
            final localEntry = localEntries.firstWhere((e) => e.id == cloudEntry.id);
            if (cloudEntry.createdAt.isAfter(localEntry.createdAt)) {
              entriesToSave.removeWhere((e) => e.id == cloudEntry.id);
              entriesToSave.add(cloudEntry);
            }
          }
        }

        // Save all entries locally
        // Note: upsertEntry will try to sync to cloud, but that's okay - 
        // it will sync to current userId, which is what we want
        print('[DataRestoreService] Saving ${entriesToSave.length} entries locally...');
        for (final entry in entriesToSave) {
          await _cycleRepository.upsertEntry(entry);
        }
        
        print('[DataRestoreService] Successfully saved ${entriesToSave.length} entries locally');

        return cloudEntries.length;
      } finally {
        // Restore original sync state
        if (!wasEnabled) {
          await _cloudStorage.disableSync();
        }
      }
    } catch (e) {
      print('[DataRestoreService] Error restoring cycle entries: $e');
      rethrow;
    }
  }

  /// Check if there are cycle entries in cloud storage
  /// If data is not found for current userId, tries to find by email
  Future<bool> hasCycleEntriesInCloud() async {
    try {
      final wasEnabled = _cloudStorage.isEnabled;
      if (!wasEnabled) {
        await _cloudStorage.initialize();
        await _cloudStorage.enableSync();
      }

      try {
        // First try with current userId
        final syncMixin = CycleEntrySyncMixin(
          cloudStorage: _cloudStorage,
          encryptionService: _encryptionService,
        );
        var entries = await syncMixin.syncAllFromCloud();
        
        if (entries.isNotEmpty) {
          return true;
        }
        
        // If no data found, try to find by email (if cloudStorage supports it)
        if (_cloudStorage is FirebaseCloudStorageService) {
          final firebaseStorage = _cloudStorage as FirebaseCloudStorageService;
          final user = await _getCurrentUserEmail();
          if (user != null) {
            final foundUserId = await firebaseStorage.findUserIdByEmail(user);
            if (foundUserId != null) {
              // Download records using found userId
              final encryptedMap = await firebaseStorage.downloadAllRecordsForUserId(
                foundUserId,
                'cycle_entry',
              );
              
              if (encryptedMap.isNotEmpty) {
                // Decrypt and count entries
                entries = <CycleEntry>[];
                for (final entry in encryptedMap.entries) {
                  try {
                    final decrypted = await _encryptionService.decryptRecord(entry.value);
                    final record = CycleEntry.fromJson(
                      (jsonDecode(decrypted) as Map<String, dynamic>),
                    );
                    if (record != null) {
                      entries.add(record);
                    }
                  } catch (e) {
                    print('[DataRestoreService] Error decrypting record: $e');
                  }
                }
                return entries.isNotEmpty;
              }
            }
          }
        }
        
        return false;
      } finally {
        if (!wasEnabled) {
          await _cloudStorage.disableSync();
        }
      }
    } catch (e) {
      print('[DataRestoreService] Error checking cloud entries: $e');
      return false;
    }
  }

  /// Get count of cycle entries in cloud storage
  /// If data is not found for current userId, tries to find by email
  Future<int> getCloudCycleEntriesCount() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        await _encryptionService.initializeForUser(firebaseUser.uid);
      }

      final wasEnabled = _cloudStorage.isEnabled;
      if (!wasEnabled) {
        await _cloudStorage.initialize();
        await _cloudStorage.enableSync();
      }

      try {
        // First try with current userId
        final syncMixin = CycleEntrySyncMixin(
          cloudStorage: _cloudStorage,
          encryptionService: _encryptionService,
        );
        var entries = await syncMixin.syncAllFromCloud();
        
        if (entries.isNotEmpty) {
          return entries.length;
        }
        
        // If no data found, try to find by email (if cloudStorage supports it)
        if (_cloudStorage is FirebaseCloudStorageService) {
          final firebaseStorage = _cloudStorage as FirebaseCloudStorageService;
          final user = await _getCurrentUserEmail();
          if (user != null) {
            final foundUserId = await firebaseStorage.findUserIdByEmail(user);
            if (foundUserId != null) {
              // Download records using found userId
              final encryptedMap = await firebaseStorage.downloadAllRecordsForUserId(
                foundUserId,
                'cycle_entry',
              );
              
              if (encryptedMap.isNotEmpty) {
                // Decrypt and count entries
                entries = <CycleEntry>[];
                for (final entry in encryptedMap.entries) {
                  try {
                    final decrypted = await _encryptionService.decryptRecord(entry.value);
                    final record = CycleEntry.fromJson(
                      (jsonDecode(decrypted) as Map<String, dynamic>),
                    );
                    if (record != null) {
                      entries.add(record);
                    }
                  } catch (e) {
                    print('[DataRestoreService] Error decrypting record: $e');
                  }
                }
                return entries.length;
              }
            }
          }
        }
        
        return 0;
      } finally {
        if (!wasEnabled) {
          await _cloudStorage.disableSync();
        }
      }
    } catch (e) {
      print('[DataRestoreService] Error getting cloud entries count: $e');
      return 0;
    }
  }

  /// Get current user email from Firebase Auth
  Future<String?> _getCurrentUserEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      return user?.email;
    } catch (e) {
      print('[DataRestoreService] Error getting user email: $e');
      return null;
    }
  }
}

