import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'cloud_storage_service.dart';
import 'encryption_service.dart';

/// Firebase Cloud Storage implementation using Firestore.
/// 
/// Structure: users/{userId}/records/{recordType}/data/{recordId}
/// 
/// Each record is stored as a document with:
/// - encryptedData: base64 encoded encrypted JSON
/// - timestamp: ISO8601 string of last modification
/// - recordType: type of record (e.g., 'cycle_entry', 'transaction')
class FirebaseCloudStorageService implements CloudStorageService {
  FirebaseCloudStorageService({
    required EncryptionService encryptionService,
    FlutterSecureStorage? storage,
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  })  : _encryptionService = encryptionService,
        _storage = storage ?? const FlutterSecureStorage(),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  static const _syncEnabledKey = 'cloud_sync_enabled';
  static const _lastSyncTimeKey = 'cloud_last_sync_time';

  final EncryptionService _encryptionService;
  final FlutterSecureStorage _storage;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  bool _isInitialized = false;
  bool _isEnabled = false;

  /// Get current user ID from Firebase Auth
  String? get _userId => _firebaseAuth.currentUser?.uid;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _encryptionService.initialize();
    final enabled = await _storage.read(key: _syncEnabledKey);
    _isEnabled = enabled == 'true';

    _isInitialized = true;
  }

  /// Save user email to user document and create email->userId mapping
  Future<void> _saveUserEmail(String userId, String email) async {
    try {
      // Save email in user document
      await _firestore
          .collection('users')
          .doc(userId)
          .set({
        'email': email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      // Also save email->userId mapping in separate collection for easy lookup
      // Use email as document ID (sanitized) so we can read it directly
      final emailDocId = email.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
      await _firestore
          .collection('user_emails')
          .doc(emailDocId)
          .set({
        'userId': userId,
        'email': email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      print('[FirebaseCloudStorage] Saved email mapping: $email -> $userId');
    } catch (e) {
      print('[FirebaseCloudStorage] Error saving user email: $e');
      // Don't throw - this is not critical
    }
  }

  @override
  Future<void> uploadRecord({
    required String recordId,
    required String recordType,
    required String encryptedData,
    required DateTime timestamp,
  }) async {
    if (!_isEnabled) {
      throw StateError('Cloud sync is not enabled');
    }

    final userId = _userId;
    if (userId == null) {
      throw StateError('User not authenticated');
    }

    final user = _firebaseAuth.currentUser;
    // Save email for future identification
    if (user?.email != null) {
      await _saveUserEmail(userId, user!.email!);
    }

    try {
      print('[FirebaseCloudStorage] Uploading record: userId=$userId, recordType=$recordType, recordId=$recordId');
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('records')
          .doc(recordType)
          .collection('data')
          .doc(recordId)
          .set({
        'encryptedData': encryptedData,
        'timestamp': Timestamp.fromDate(timestamp),
        'recordType': recordType,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('[FirebaseCloudStorage] ✓ Successfully uploaded record: $recordId');
    } catch (e) {
      print('[FirebaseCloudStorage] ✗ Failed to upload record: $e');
      throw Exception('Failed to upload record to Firestore: $e');
    }
  }

  @override
  Future<String?> downloadRecord({
    required String recordId,
    required String recordType,
  }) async {
    if (!_isEnabled) {
      return null;
    }

    final userId = _userId;
    if (userId == null) {
      return null;
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('records')
          .doc(recordType)
          .collection('data')
          .doc(recordId)
          .get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data();
      return data?['encryptedData'] as String?;
    } catch (e) {
      print('[FirebaseCloudStorage] Error downloading record: $e');
      return null;
    }
  }

  @override
  Future<Map<String, String>> downloadAllRecords(String recordType) async {
    if (!_isEnabled) {
      return {};
    }

    final userId = _userId;
    if (userId == null) {
      return {};
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('records')
          .doc(recordType)
          .collection('data')
          .get();

      final result = <String, String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final encryptedData = data['encryptedData'] as String?;
        if (encryptedData != null) {
          result[doc.id] = encryptedData;
        }
      }
      return result;
    } catch (e) {
      print('[FirebaseCloudStorage] Error downloading all records: $e');
      return {};
    }
  }

  @override
  Future<void> deleteRecord({
    required String recordId,
    required String recordType,
  }) async {
    if (!_isEnabled) {
      return;
    }

    final userId = _userId;
    if (userId == null) {
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('records')
          .doc(recordType)
          .collection('data')
          .doc(recordId)
          .delete();
    } catch (e) {
      print('[FirebaseCloudStorage] Error deleting record: $e');
      // Don't throw - deletion failures are not critical
    }
  }

  @override
  bool get isEnabled => _isEnabled;

  @override
  Future<void> enableSync() async {
    await _storage.write(key: _syncEnabledKey, value: 'true');
    _isEnabled = true;
    await _updateLastSyncTime();
  }

  @override
  Future<void> disableSync() async {
    await _storage.write(key: _syncEnabledKey, value: 'false');
    _isEnabled = false;
  }

  @override
  Future<SyncStatus> getSyncStatus() async {
    final lastSyncStr = await _storage.read(key: _lastSyncTimeKey);
    final lastSyncTime = lastSyncStr != null ? DateTime.parse(lastSyncStr) : null;

    return SyncStatus(
      isEnabled: _isEnabled,
      isConfigured: _isInitialized,
      lastSyncTime: lastSyncTime,
      pendingUploads: 0, // TODO: Calculate from local vs cloud comparison
      pendingDownloads: 0, // TODO: Calculate from cloud vs local comparison
    );
  }

  @override
  Future<void> syncAll() async {
    if (!_isEnabled) {
      throw StateError('Cloud sync is not enabled');
    }

    // TODO: Implement full sync
    // 1. Download all records from cloud
    // 2. Compare with local records
    // 3. Upload missing local records
    // 4. Download missing cloud records
    // 5. Resolve conflicts (use latest timestamp)

    await _updateLastSyncTime();
  }

  @override
  Future<void> syncChanges() async {
    if (!_isEnabled) {
      throw StateError('Cloud sync is not enabled');
    }

    // TODO: Implement incremental sync
    // 1. Get last sync time
    // 2. Download records modified since last sync
    // 3. Upload local records modified since last sync
    // 4. Resolve conflicts

    await _updateLastSyncTime();
  }

  @override
  Future<void> deleteAllUserData() async {
    if (!_isEnabled) {
      return;
    }

    final userId = _userId;
    if (userId == null) {
      return;
    }

    try {
      // Get all record types for this user
      final recordsRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('records');

      final recordTypesSnapshot = await recordsRef.get();

      // Delete all documents in each record type collection
      for (final recordTypeDoc in recordTypesSnapshot.docs) {
        final dataSnapshot = await recordTypeDoc.reference
            .collection('data')
            .get();

        // Use batch for efficient deletion (max 500 operations per batch)
        WriteBatch? batch;
        int batchCount = 0;
        const maxBatchSize = 500;

        for (final doc in dataSnapshot.docs) {
          if (batch == null) {
            batch = _firestore.batch();
          }

          batch.delete(doc.reference);
          batchCount++;

          // Firestore batch limit is 500 operations
          if (batchCount >= maxBatchSize) {
            await batch.commit();
            batch = null;
            batchCount = 0;
          }
        }

        // Commit remaining operations
        if (batch != null && batchCount > 0) {
          await batch.commit();
        }

        // Delete the record type document itself
        await recordTypeDoc.reference.delete();
      }
    } catch (e) {
      print('[FirebaseCloudStorage] Error deleting all user data: $e');
      throw Exception('Failed to delete all user data: $e');
    }
  }

  /// Find userId by email using the user_emails collection
  /// This uses a direct document lookup instead of querying all users
  Future<String?> _findUserIdByEmail(String email) async {
    try {
      print('[FirebaseCloudStorage] ===== Searching for userId by email: $email =====');
      
      // Use email as document ID (sanitized) to read directly
      final emailDocId = email.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
      
      try {
        final emailDoc = await _firestore
            .collection('user_emails')
            .doc(emailDocId)
            .get();
        
        if (emailDoc.exists) {
          final data = emailDoc.data();
          final userId = data?['userId'] as String?;
          final storedEmail = data?['email'] as String?;
          
          // Verify email matches (case-insensitive)
          if (userId != null && storedEmail != null && 
              storedEmail.toLowerCase().trim() == email.toLowerCase().trim()) {
            print('[FirebaseCloudStorage] ✓ MATCH FOUND! userId: $userId for email: $email');
            return userId;
          } else {
            print('[FirebaseCloudStorage] Email document exists but email mismatch: stored=$storedEmail, requested=$email');
          }
        } else {
          print('[FirebaseCloudStorage] No email document found for: $emailDocId');
        }
      } catch (e) {
        print('[FirebaseCloudStorage] Error reading email document: $e');
        // Fall through to return null
      }
      
      print('[FirebaseCloudStorage] ✗ No userId found for email: $email');
      return null;
    } catch (e) {
      print('[FirebaseCloudStorage] ERROR finding userId by email: $e');
      print('[FirebaseCloudStorage] Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Download all records for a specific userId (used when finding data by email)
  /// This is a public method to allow restoring data from a different userId
  Future<Map<String, String>> downloadAllRecordsForUserId(String userId, String recordType) async {
    try {
      print('[FirebaseCloudStorage] Downloading records for userId: $userId, recordType: $recordType');
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('records')
          .doc(recordType)
          .collection('data')
          .get();

      final result = <String, String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final encryptedData = data['encryptedData'] as String?;
        if (encryptedData != null) {
          result[doc.id] = encryptedData;
        }
      }
      print('[FirebaseCloudStorage] Downloaded ${result.length} records for userId: $userId');
      return result;
    } catch (e) {
      print('[FirebaseCloudStorage] Error downloading records for userId $userId: $e');
      return {};
    }
  }

  /// Find and return userId that has data for the given email
  Future<String?> findUserIdByEmail(String email) async {
    return await _findUserIdByEmail(email);
  }

  @override
  Future<bool> hasCloudData() async {
    // Wait for auth state to be ready and reload user if needed
    var user = _firebaseAuth.currentUser;
    if (user == null) {
      print('[FirebaseCloudStorage] No current user, waiting for auth state...');
      // Wait a bit for auth state to update
      await Future.delayed(const Duration(milliseconds: 500));
      user = _firebaseAuth.currentUser;
    }
    
    if (user == null) {
      print('[FirebaseCloudStorage] Still no current user after wait');
      return false;
    }

    // Reload user to ensure we have the latest data
    try {
      await user.reload();
      user = _firebaseAuth.currentUser;
    } catch (e) {
      print('[FirebaseCloudStorage] Error reloading user: $e');
      // Continue anyway
    }

    final userId = user?.uid;
    final userEmail = user?.email;
    
    if (userId == null) {
      print('[FirebaseCloudStorage] User ID is null');
      return false;
    }

    print('[FirebaseCloudStorage] Checking cloud data for userId: $userId, email: $userEmail');

    try {
      // Query the data subcollection directly. The intermediate 'cycle_entry'
      // doc is never written to Firestore (only used as a path prefix), so
      // querying the 'records' collection for documents always returns 0.
      bool hasData = false;
      for (final recordType in ['cycle_entry', 'transaction']) {
        final dataSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('records')
            .doc(recordType)
            .collection('data')
            .limit(1)
            .get();

        print('[FirebaseCloudStorage] Record type "$recordType" has ${dataSnapshot.docs.length} documents for current userId');

        if (dataSnapshot.docs.isNotEmpty) {
          print('[FirebaseCloudStorage] Found cloud data in record type: $recordType');
          hasData = true;
          break;
        }
      }

      // If no data found for current userId, try to find by email
      if (!hasData && userEmail != null && userEmail.isNotEmpty) {
        print('[FirebaseCloudStorage] No data found for current userId, trying to find by email: $userEmail');
        final foundUserId = await _findUserIdByEmail(userEmail);

        if (foundUserId != null && foundUserId != userId) {
          print('[FirebaseCloudStorage] Found different userId: $foundUserId, checking for data...');
          for (final recordType in ['cycle_entry', 'transaction']) {
            final dataSnapshot = await _firestore
                .collection('users')
                .doc(foundUserId)
                .collection('records')
                .doc(recordType)
                .collection('data')
                .limit(1)
                .get();

            if (dataSnapshot.docs.isNotEmpty) {
              print('[FirebaseCloudStorage] Found cloud data for email $userEmail under userId: $foundUserId');
              return true;
            }
          }
        }
      }

      if (!hasData) {
        print('[FirebaseCloudStorage] No data found in any record type collection');
      }

      return hasData;
    } catch (e) {
      print('[FirebaseCloudStorage] Error checking cloud data: $e');
      print('[FirebaseCloudStorage] Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  Future<void> _updateLastSyncTime() async {
    await _storage.write(
      key: _lastSyncTimeKey,
      value: DateTime.now().toIso8601String(),
    );
  }
}




