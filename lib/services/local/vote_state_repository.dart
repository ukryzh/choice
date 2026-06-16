import 'dart:convert';

import 'package:hive/hive.dart';

import '../../models/vote_state.dart';
import 'encrypted_storage_service.dart';

class VoteStateRepository {
  VoteStateRepository(this._storage);

  static const _boxName = 'vote_states';

  final EncryptedStorageService _storage;

  Future<List<VoteState>> fetchVoteStates() async {
    final box = await _openBox();
    return box.values
        .map((json) => VoteState.fromJson(jsonDecode(json) as Map<String, dynamic>))
        .toList();
  }

  Future<VoteState?> fetchVoteState(String question) async {
    final box = await _openBox();
    final stored = box.get(question);
    if (stored == null) return null;
    return VoteState.fromJson(jsonDecode(stored) as Map<String, dynamic>);
  }

  Future<void> saveVoteState(VoteState voteState) async {
    final box = await _openBox();
    await box.put(voteState.question, voteState.encode());
  }

  Future<void> deleteVoteState(String question) async {
    final box = await _openBox();
    await box.delete(question);
  }

  Future<Box<String>> _openBox() async {
    return _storage.openEncryptedBox<String>(_boxName);
  }
}


