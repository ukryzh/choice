import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Handles encrypted Hive box access backed by a secure local key.
class EncryptedStorageService {
  EncryptedStorageService({FlutterSecureStorage? keychain})
      : _secureStorage = keychain ?? const FlutterSecureStorage();

  static const _encryptionKeyStorageKey = 'choice_hive_key_v1';

  final FlutterSecureStorage _secureStorage;

  HiveCipher? _cipher;
  bool _initialized = false;
  final Set<String> _openedBoxes = <String>{};

  Future<void> initialize() async {
    if (_initialized) return;
    var encodedKey = await _secureStorage.read(key: _encryptionKeyStorageKey);
    if (encodedKey == null) {
      final key = Hive.generateSecureKey();
      encodedKey = base64Encode(key);
      await _secureStorage.write(
        key: _encryptionKeyStorageKey,
        value: encodedKey,
      );
    }
    final keyBytes = base64Decode(encodedKey);
    _cipher = HiveAesCipher(keyBytes);
    _initialized = true;
  }

  Future<Box<T>> openEncryptedBox<T>(String name) async {
    if (!_initialized || _cipher == null) {
      throw StateError('EncryptedStorageService not initialized');
    }
    final box = await Hive.openBox<T>(
      name,
      encryptionCipher: _cipher,
    );
    _openedBoxes.add(name);
    return box;
  }

  Future<void> clearAll() async {
    if (!_initialized) return;
    for (final name in _openedBoxes.toList()) {
      if (Hive.isBoxOpen(name)) {
        await Hive.box(name).clear();
      }
    }
  }
}


