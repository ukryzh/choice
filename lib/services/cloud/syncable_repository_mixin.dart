import 'dart:convert';

import '../../models/cycle_entry.dart';
import '../../models/transaction.dart';
import 'cloud_storage_service.dart';
import 'encryption_service.dart';

/// Mixin to add cloud sync capabilities to repositories
/// Each record type should implement this mixin
mixin SyncableRepositoryMixin<T> {
  CloudStorageService get cloudStorage;
  EncryptionService get encryptionService;
  String get recordType;

  /// Encrypt and upload a single record
  Future<void> syncRecordToCloud(T record) async {
    if (!cloudStorage.isEnabled) return;

    final recordJson = _recordToJson(record);
    final recordId = _getRecordId(record);
    final encrypted = await encryptionService.encryptRecord(recordJson);
    final timestamp = _getRecordTimestamp(record);

    await cloudStorage.uploadRecord(
      recordId: recordId,
      recordType: recordType,
      encryptedData: encrypted,
      timestamp: timestamp,
    );
  }

  /// Download and decrypt a single record from cloud
  Future<T?> syncRecordFromCloud(String recordId) async {
    if (!cloudStorage.isEnabled) return null;

    final encrypted = await cloudStorage.downloadRecord(
      recordId: recordId,
      recordType: recordType,
    );

    if (encrypted == null) return null;

    final decrypted = await encryptionService.decryptRecord(encrypted);
    return _recordFromJson(decrypted);
  }

  /// Sync all records of this type
  Future<void> syncAllToCloud(List<T> records) async {
    if (!cloudStorage.isEnabled) return;

    for (final record in records) {
      await syncRecordToCloud(record);
    }
  }

  /// Download all records of this type from cloud
  Future<List<T>> syncAllFromCloud() async {
    if (!cloudStorage.isEnabled) return [];

    final encryptedMap = await cloudStorage.downloadAllRecords(recordType);
    final records = <T>[];

    for (final entry in encryptedMap.entries) {
      try {
        final decrypted = await encryptionService.decryptRecord(entry.value);
        final record = _recordFromJson(decrypted);
        if (record != null) {
          records.add(record);
        }
      } catch (e) {
        // Skip corrupted records
        print('Failed to decrypt record ${entry.key}: $e');
      }
    }

    return records;
  }

  /// Delete record from cloud
  Future<void> deleteRecordFromCloud(String recordId) async {
    if (!cloudStorage.isEnabled) return;

    await cloudStorage.deleteRecord(
      recordId: recordId,
      recordType: recordType,
    );
  }

  // Abstract methods to be implemented by repositories
  String _recordToJson(T record);
  T? _recordFromJson(String json);
  String _getRecordId(T record);
  DateTime _getRecordTimestamp(T record);
}

/// Implementation for CycleEntry
class CycleEntrySyncMixin with SyncableRepositoryMixin<CycleEntry> {
  CycleEntrySyncMixin({
    required this.cloudStorage,
    required this.encryptionService,
  });

  @override
  final CloudStorageService cloudStorage;
  @override
  final EncryptionService encryptionService;
  @override
  final String recordType = 'cycle_entry';

  @override
  String _recordToJson(CycleEntry record) => record.encode();

  @override
  CycleEntry? _recordFromJson(String json) {
    try {
      return CycleEntry.fromJson(
        (jsonDecode(json) as Map<String, dynamic>),
      );
    } catch (e) {
      return null;
    }
  }

  @override
  String _getRecordId(CycleEntry record) => record.id;

  @override
  DateTime _getRecordTimestamp(CycleEntry record) => record.createdAt;
}

/// Implementation for Transaction
class TransactionSyncMixin with SyncableRepositoryMixin<Transaction> {
  TransactionSyncMixin({
    required this.cloudStorage,
    required this.encryptionService,
  });

  @override
  final CloudStorageService cloudStorage;
  @override
  final EncryptionService encryptionService;
  @override
  final String recordType = 'transaction';

  @override
  String _recordToJson(Transaction record) => record.encode();

  @override
  Transaction? _recordFromJson(String json) {
    try {
      return Transaction.fromJson(
        (jsonDecode(json) as Map<String, dynamic>),
      );
    } catch (e) {
      return null;
    }
  }

  @override
  String _getRecordId(Transaction record) => record.id;

  @override
  DateTime _getRecordTimestamp(Transaction record) => record.date;
}

