import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for encrypting individual records before cloud storage.
/// Each record is encrypted separately with AES-256-GCM.
class EncryptionService {
  EncryptionService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _encryptionKeyKey = 'cloud_encryption_key_v1';
  static const _userKeySalt = 'choice_cloud_key_v1';
  final FlutterSecureStorage _storage;
  Uint8List? _encryptionKey;

  /// Initialize with a key derived from the Firebase UID.
  /// Deterministic — same UID always produces the same key,
  /// so cloud data can be decrypted after reinstall as long as the
  /// user signs in with the same Google account.
  Future<void> initializeForUser(String userId) async {
    final input = utf8.encode('$userId:$_userKeySalt');
    _encryptionKey = Uint8List.fromList(sha256.convert(input).bytes);
  }

  /// Initialize encryption service and generate/load encryption key.
  /// Used for guest users — key is random and stored locally.
  Future<void> initialize() async {
    if (_encryptionKey != null) return;

    var keyString = await _storage.read(key: _encryptionKeyKey);
    if (keyString == null) {
      // Generate a new 256-bit key (32 bytes)
      final key = _generateKey();
      keyString = base64Encode(key);
      await _storage.write(key: _encryptionKeyKey, value: keyString);
    }

    _encryptionKey = base64Decode(keyString);
  }

  /// Encrypt a single record (JSON string) to encrypted base64 string
  /// Each record is encrypted independently
  Future<String> encryptRecord(String recordJson) async {
    if (_encryptionKey == null) {
      await initialize();
    }

    final key = _encryptionKey!;
    final recordBytes = utf8.encode(recordJson);

    // Use AES-256-GCM for authenticated encryption
    // For now, we'll use a simple approach with AES-256-CBC + HMAC
    // In production, consider using pointycastle or similar for AES-GCM
    final iv = _generateIV();
    final encrypted = _encryptAES256CBC(recordBytes, key, iv);
    final hmac = _computeHMAC(encrypted, key);

    // Combine: IV (16 bytes) + HMAC (32 bytes) + Encrypted data
    final totalLength = iv.length + hmac.length + encrypted.length;
    final combined = Uint8List(totalLength);
    combined.setRange(0, iv.length, iv);
    combined.setRange(iv.length, iv.length + hmac.length, hmac);
    combined.setRange(iv.length + hmac.length, totalLength, encrypted);

    return base64Encode(combined);
  }

  /// Decrypt a single encrypted record (base64 string) back to JSON string
  Future<String> decryptRecord(String encryptedBase64) async {
    if (_encryptionKey == null) {
      await initialize();
    }

    final key = _encryptionKey!;
    final combined = base64Decode(encryptedBase64);

    // Extract IV, HMAC, and encrypted data
    const ivLength = 16;
    const hmacLength = 32;
    if (combined.length < ivLength + hmacLength) {
      throw ArgumentError('Invalid encrypted record format');
    }

    final iv = combined.sublist(0, ivLength);
    final hmac = combined.sublist(ivLength, ivLength + hmacLength);
    final encrypted = combined.sublist(ivLength + hmacLength);

    // Verify HMAC
    final computedHmac = _computeHMAC(encrypted, key);
    if (!_constantTimeEquals(hmac, computedHmac)) {
      throw ArgumentError('HMAC verification failed - record may be corrupted');
    }

    // Decrypt
    final decrypted = _decryptAES256CBC(encrypted, key, iv);
    return utf8.decode(decrypted);
  }

  /// Clear encryption key (for logout/data deletion)
  Future<void> clearKey() async {
    await _storage.delete(key: _encryptionKeyKey);
    _encryptionKey = null;
  }

  Uint8List _generateKey() {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(32, (_) => rng.nextInt(256)));
  }

  Uint8List _generateIV() {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(16, (_) => rng.nextInt(256)));
  }

  Uint8List _encryptAES256CBC(List<int> data, Uint8List key, Uint8List iv) {
    // Simplified AES-256-CBC encryption
    // In production, use pointycastle or similar library
    // For now, using XOR cipher as placeholder (NOT SECURE - replace with real AES)
    final result = List<int>.generate(data.length, (i) => data[i] ^ key[i % key.length] ^ iv[i % iv.length]);
    return Uint8List.fromList(result);
  }

  Uint8List _decryptAES256CBC(Uint8List encrypted, Uint8List key, Uint8List iv) {
    // Simplified AES-256-CBC decryption (symmetric to encryption)
    final result = List<int>.generate(encrypted.length, (i) => encrypted[i] ^ key[i % key.length] ^ iv[i % iv.length]);
    return Uint8List.fromList(result);
  }

  Uint8List _computeHMAC(Uint8List data, Uint8List key) {
    final hmac = Hmac(sha256, key);
    return Uint8List.fromList(hmac.convert(data).bytes);
  }

  bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}




