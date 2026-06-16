import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app_router.dart';
import 'services/local/encrypted_storage_service.dart';
import 'state/app_providers.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  await Hive.initFlutter();

  final encryptedStorage = EncryptedStorageService();
  await encryptedStorage.initialize();

  runApp(
    ProviderScope(
      overrides: [
        encryptedStorageProvider.overrideWithValue(encryptedStorage),
      ],
      child: const ChoiceApp(),
    ),
  );
}

class ChoiceApp extends ConsumerWidget {
  const ChoiceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'choice',
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}




