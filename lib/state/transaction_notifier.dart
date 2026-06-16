import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import 'app_providers.dart';

class TransactionsNotifier extends AsyncNotifier<List<Transaction>> {
  @override
  Future<List<Transaction>> build() async {
    final repository = ref.watch(transactionRepositoryProvider);
    return repository.fetchTransactions();
  }

  Future<void> addTransaction(Transaction transaction) async {
    final repository = ref.read(transactionRepositoryProvider);
    await repository.saveTransaction(transaction);
    state = await AsyncValue.guard(() => repository.fetchTransactions());
  }

  Future<void> deleteTransaction(String id) async {
    final repository = ref.read(transactionRepositoryProvider);
    await repository.deleteTransaction(id);
    state = await AsyncValue.guard(() => repository.fetchTransactions());
  }
}


