import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cycle_entry.dart';
import '../models/transaction.dart';
import '../models/user_profile.dart';
import '../services/local/cycle_repository.dart';
import '../services/local/data_export_service.dart';
import '../services/local/encrypted_storage_service.dart';
import '../services/local/transaction_repository.dart';
import '../services/local/user_repository.dart';
import '../services/local/vote_state_repository.dart';
import '../services/auth/auth_service.dart';
import '../services/auth/pin_service.dart';
import '../services/cloud/cloud_storage_service.dart';
import '../services/cloud/data_restore_service.dart';
import '../services/cloud/encryption_service.dart';
import '../services/cloud/firebase_cloud_storage_service.dart';
import 'auth_notifier.dart';
import 'cycle_notifier.dart';
import 'transaction_notifier.dart';
import 'user_notifier.dart';

final encryptedStorageProvider = Provider<EncryptedStorageService>((ref) {
  throw UnimplementedError('EncryptedStorageService not initialized');
});

final cycleRepositoryProvider = Provider<CycleRepository>(
  (ref) => CycleRepository(
    ref.watch(encryptedStorageProvider),
    cloudStorage: ref.watch(cloudStorageServiceProvider),
    encryptionService: ref.watch(encryptionServiceProvider),
  ),
);

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(ref.watch(encryptedStorageProvider)),
);

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepository(ref.watch(encryptedStorageProvider)),
);

final voteStateRepositoryProvider = Provider<VoteStateRepository>(
  (ref) => VoteStateRepository(ref.watch(encryptedStorageProvider)),
);

final cycleEntriesProvider =
    AsyncNotifierProvider<CycleEntriesNotifier, List<CycleEntry>>(
  CycleEntriesNotifier.new,
);

final userProfileProvider =
    AsyncNotifierProvider<UserNotifier, UserProfile>(UserNotifier.new);

final transactionsProvider =
    AsyncNotifierProvider<TransactionsNotifier, List<Transaction>>(
  TransactionsNotifier.new,
);

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final pinServiceProvider = Provider<PinService>((ref) => PinService());

final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return EncryptionService();
});

final cloudStorageServiceProvider = Provider<CloudStorageService>((ref) {
  final encryptionService = ref.watch(encryptionServiceProvider);
  return FirebaseCloudStorageService(
    encryptionService: encryptionService,
  );
});

final dataExportServiceProvider = Provider<DataExportService>((ref) {
  return DataExportService(
    cycleRepository: ref.watch(cycleRepositoryProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
    userRepository: ref.watch(userRepositoryProvider),
  );
});

final dataRestoreServiceProvider = Provider<DataRestoreService>((ref) {
  return DataRestoreService(
    cloudStorage: ref.watch(cloudStorageServiceProvider),
    encryptionService: ref.watch(encryptionServiceProvider),
    cycleRepository: ref.watch(cycleRepositoryProvider),
  );
});

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    authService: ref.watch(authServiceProvider),
    pinService: ref.watch(pinServiceProvider),
    encryptionService: ref.watch(encryptionServiceProvider),
  );
});

final cloudBackupEnabledProvider = FutureProvider<bool>((ref) async {
  final cloudStorage = ref.watch(cloudStorageServiceProvider);
  await cloudStorage.initialize();
  return cloudStorage.isEnabled;
});

