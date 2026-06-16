/// Abstract interface for cloud storage service.
/// Implementations should encrypt records before storing them.
abstract class CloudStorageService {
  /// Initialize the cloud storage service
  Future<void> initialize();

  /// Upload a single encrypted record to cloud storage
  /// [recordId] - unique identifier for the record
  /// [recordType] - type of record (e.g., 'cycle_entry', 'transaction')
  /// [encryptedData] - already encrypted record data (base64 string)
  /// [timestamp] - last modified timestamp
  Future<void> uploadRecord({
    required String recordId,
    required String recordType,
    required String encryptedData,
    required DateTime timestamp,
  });

  /// Download a single encrypted record from cloud storage
  /// Returns encrypted data (base64 string) or null if not found
  Future<String?> downloadRecord({
    required String recordId,
    required String recordType,
  });

  /// Download all records of a specific type
  /// Returns map of recordId -> encryptedData
  Future<Map<String, String>> downloadAllRecords(String recordType);

  /// Delete a record from cloud storage
  Future<void> deleteRecord({
    required String recordId,
    required String recordType,
  });

  /// Check if cloud sync is enabled and configured
  bool get isEnabled;

  /// Enable cloud sync (should be called after user authentication)
  Future<void> enableSync();

  /// Disable cloud sync
  Future<void> disableSync();

  /// Get sync status
  Future<SyncStatus> getSyncStatus();

  /// Sync all local records to cloud (full sync)
  Future<void> syncAll();

  /// Sync changes since last sync (incremental sync)
  Future<void> syncChanges();

  /// Delete all user data from cloud storage (for \"delete everywhere\" / \"delete from cloud\" flows)
  Future<void> deleteAllUserData();

  /// Check if user has any data in cloud storage
  /// Returns true if there are any records for this user, false otherwise
  /// This method works even if sync is not enabled, to check for existing data
  Future<bool> hasCloudData();
}

/// Sync status information
class SyncStatus {
  const SyncStatus({
    required this.isEnabled,
    required this.isConfigured,
    this.lastSyncTime,
    this.pendingUploads = 0,
    this.pendingDownloads = 0,
  });

  final bool isEnabled;
  final bool isConfigured;
  final DateTime? lastSyncTime;
  final int pendingUploads;
  final int pendingDownloads;
}




