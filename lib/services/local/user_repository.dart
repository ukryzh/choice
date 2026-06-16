import 'dart:convert';

import 'package:hive/hive.dart';

import '../../models/user_profile.dart';
import 'encrypted_storage_service.dart';

class UserRepository {
  UserRepository(this._storage);

  static const _boxName = 'user_profile';
  static const _key = 'profile';

  final EncryptedStorageService _storage;

  Future<UserProfile> loadProfile() async {
    final box = await _openBox();
    final stored = box.get(_key);
    if (stored == null) {
      return UserProfile.empty();
    }

    final data = jsonDecode(stored) as Map<String, dynamic>;
    return UserProfile(
      displayName: data['displayName'] as String? ?? 'choice user',
      email: data['email'] as String?,
    );
  }

  Future<void> saveProfile(UserProfile profile) async {
    final box = await _openBox();
    await box.put(
      _key,
      jsonEncode({
        'displayName': profile.displayName,
        'email': profile.email,
      }),
    );
  }

  Future<Box<String>> _openBox() async {
    return _storage.openEncryptedBox<String>(_boxName);
  }
}


