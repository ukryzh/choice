import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import 'app_providers.dart';
import 'auth_notifier.dart';

class UserNotifier extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() async {
    final repo = ref.watch(userRepositoryProvider);
    final profile = await repo.loadProfile();
    
    // Sync email from auth state if available
    final authState = ref.watch(authNotifierProvider);
    if (authState.email != null && profile.email != authState.email) {
      final updated = profile.copyWith(email: authState.email);
      await repo.saveProfile(updated);
      return updated;
    }
    
    // Listen for auth state changes to sync email
    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (next.email != null && state.valueOrNull?.email != next.email) {
        final currentProfile = state.valueOrNull ?? profile;
        final updated = currentProfile.copyWith(email: next.email);
        repo.saveProfile(updated).then((_) {
          state = AsyncData(updated);
        });
      } else if (next.email == null && state.valueOrNull?.email != null) {
        final currentProfile = state.valueOrNull ?? profile;
        final updated = UserProfile(displayName: currentProfile.displayName);
        repo.saveProfile(updated).then((_) {
          state = AsyncData(updated);
        });
      }
    });
    
    return profile;
  }

  Future<void> updateDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final repo = ref.read(userRepositoryProvider);
    final profile = state.valueOrNull ?? UserProfile.empty();
    final updated = profile.copyWith(displayName: trimmed);
    await repo.saveProfile(updated);
    state = AsyncData(updated);
  }
}


