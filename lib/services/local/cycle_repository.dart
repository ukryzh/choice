import 'dart:convert';

import 'package:hive/hive.dart';

import '../../models/cycle_entry.dart';
import '../cloud/cloud_storage_service.dart';
import '../cloud/encryption_service.dart';
import 'encrypted_storage_service.dart';

class CycleRepository {
  CycleRepository(
    this._storage, {
    CloudStorageService? cloudStorage,
    EncryptionService? encryptionService,
  })  : _cloudStorage = cloudStorage,
        _encryptionService = encryptionService;

  static const _boxName = 'cycle_entries';

  final EncryptedStorageService _storage;
  final CloudStorageService? _cloudStorage;
  final EncryptionService? _encryptionService;

  Future<List<CycleEntry>> fetchEntries() async {
    final box = await _openBox();
    return box.values
        .map((json) => CycleEntry.fromJson(jsonDecode(json) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.cycleStart.compareTo(a.cycleStart));
  }

  Future<void> upsertEntry(CycleEntry entry) async {
    final box = await _openBox();
    await box.put(
      entry.id,
      entry.encode(),
    );
    
    // Sync to cloud if enabled
    if (_cloudStorage != null && _encryptionService != null && _cloudStorage!.isEnabled) {
      try {
        final recordJson = entry.encode();
        final encrypted = await _encryptionService!.encryptRecord(recordJson);
        await _cloudStorage!.uploadRecord(
          recordId: entry.id,
          recordType: 'cycle_entry',
          encryptedData: encrypted,
          timestamp: entry.createdAt,
        );
      } catch (e) {
        // Log error but don't fail the local save
        print('Failed to sync entry to cloud: $e');
      }
    }
  }

  Future<void> deleteEntry(String id) async {
    final box = await _openBox();
    await box.delete(id);
    
    // Delete from cloud if enabled
    if (_cloudStorage != null && _cloudStorage!.isEnabled) {
      try {
        await _cloudStorage!.deleteRecord(
          recordId: id,
          recordType: 'cycle_entry',
        );
      } catch (e) {
        // Log error but don't fail the local delete
        print('Failed to delete entry from cloud: $e');
      }
    }
  }

  /// Clear all cycle entries (used for local data deletion from Calendar)
  Future<void> clearAllEntries() async {
    final box = await _openBox();
    await box.clear();
  }

  /// Replace all stored entries with the provided list.
  Future<void> replaceAllEntries(List<CycleEntry> entries) async {
    final box = await _openBox();
    await box.clear();
    for (final entry in entries) {
      await box.put(entry.id, entry.encode());
    }
  }

  Future<Box<String>> _openBox() async {
    final box = await _storage.openEncryptedBox<String>(_boxName);
    return box;
  }
}


