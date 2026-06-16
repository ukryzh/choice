import 'dart:convert';

import 'package:hive/hive.dart';

import '../../models/transaction.dart';
import 'encrypted_storage_service.dart';

class TransactionRepository {
  TransactionRepository(this._storage);

  static const _boxName = 'transactions';

  final EncryptedStorageService _storage;

  Future<List<Transaction>> fetchTransactions() async {
    final box = await _openBox();
    return box.values
        .map((json) => Transaction.fromJson(jsonDecode(json) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> saveTransaction(Transaction transaction) async {
    final box = await _openBox();
    
    // For voting transactions, remove old transaction with same question
    if (transaction.type == TransactionType.voting && transaction.question != null) {
      final existing = box.values
          .map((json) => Transaction.fromJson(jsonDecode(json) as Map<String, dynamic>))
          .where((t) => t.type == TransactionType.voting && t.question == transaction.question)
          .toList();
      
      for (final old in existing) {
        await box.delete(old.id);
      }
    }
    
    await box.put(transaction.id, transaction.encode());
  }

  Future<void> deleteTransaction(String id) async {
    final box = await _openBox();
    await box.delete(id);
  }

  Future<Box<String>> _openBox() async {
    return _storage.openEncryptedBox<String>(_boxName);
  }
}


