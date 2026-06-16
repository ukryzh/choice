import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/auth/auth_service.dart';
import '../services/auth/pin_service.dart';
import '../services/cloud/encryption_service.dart';
import 'app_providers.dart';

enum AuthStatus {
  unauthenticated,
  authenticated,
  pinRequired,
  authenticatedWithPin,
}

class AuthState {
  const AuthState({
    required this.status,
    this.email,
    this.displayName,
    this.provider,
  });

  final AuthStatus status;
  final String? email;
  final String? displayName;
  final AuthProvider? provider;

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    String? displayName,
    AuthProvider? provider,
  }) {
    return AuthState(
      status: status ?? this.status,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      provider: provider ?? this.provider,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({
    required AuthService authService,
    required PinService pinService,
    EncryptionService? encryptionService,
  })  : _authService = authService,
        _pinService = pinService,
        _encryptionService = encryptionService,
        super(const AuthState(status: AuthStatus.unauthenticated)) {
    _checkAuthStatus();
  }

  final AuthService _authService;
  final PinService _pinService;
  final EncryptionService? _encryptionService;
  static const _authEmailKey = 'auth_email';
  static const _authDisplayNameKey = 'auth_display_name';
  static const _authProviderKey = 'auth_provider';
  static const _authUserIdKey = 'auth_user_id';
  static const _authCompletedKey = 'auth_completed';
  final _storage = const FlutterSecureStorage();

  Future<void> _checkAuthStatus() async {
    try {
      // Проверяем Firebase authentication статус
      final isFirebaseSignedIn = await _authService.isSignedIn();
      final firebaseUser = _authService.currentUser;
      
      // Если пользователь авторизован в Firebase, обновляем локальные данные
      if (isFirebaseSignedIn && firebaseUser != null) {
        await _storage.write(key: _authEmailKey, value: firebaseUser.email ?? '');
        await _storage.write(key: _authDisplayNameKey, value: firebaseUser.displayName ?? '');
        await _storage.write(key: _authUserIdKey, value: firebaseUser.uid);
        await _storage.write(key: _authProviderKey, value: AuthProvider.google.name);
        await _storage.write(key: _authCompletedKey, value: 'true');
        // Derive encryption key from UID so cloud data survives reinstalls
        await _encryptionService?.initializeForUser(firebaseUser.uid);
      }
      
      // Сначала проверяем PIN - если установлен, показываем PIN Entry
      final pinSet = await _pinService.isPinSet();
      if (pinSet) {
        final email = await _storage.read(key: _authEmailKey);
        final displayName = await _storage.read(key: _authDisplayNameKey);
        final providerStr = await _storage.read(key: _authProviderKey);
        final provider = providerStr != null
            ? AuthProvider.values.firstWhere(
                (p) => p.name == providerStr,
                orElse: () => AuthProvider.none,
              )
            : AuthProvider.none;
        
        state = AuthState(
          status: AuthStatus.pinRequired,
          email: email,
          displayName: displayName,
          provider: provider,
        );
        return;
      }

      // Если PIN не установлен, проверяем auth_completed
      final authCompleted = await _storage.read(key: _authCompletedKey);
      if (authCompleted == 'true' || isFirebaseSignedIn) {
        final email = firebaseUser?.email ?? await _storage.read(key: _authEmailKey);
        final displayName = firebaseUser?.displayName ?? await _storage.read(key: _authDisplayNameKey);
        final providerStr = await _storage.read(key: _authProviderKey);
        final provider = providerStr != null
            ? AuthProvider.values.firstWhere(
                (p) => p.name == providerStr,
                orElse: () => AuthProvider.none,
              )
            : AuthProvider.none;

        // PIN не установлен, но авторизация пройдена - нужно установить PIN
        state = AuthState(
          status: AuthStatus.authenticated,
          email: email,
          displayName: displayName,
          provider: provider,
        );
      } else {
        // Первый запуск - показываем экран авторизации
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } catch (e) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final result = await _authService.signInWithGoogle();
      if (result != null) {
        await _saveAuthData(result);
        // Derive encryption key from UID so cloud data survives reinstalls
        if (result.userId != null) {
          await _encryptionService?.initializeForUser(result.userId!);
        }

        // Check if PIN is already set - if yes, go to pinRequired state
        // If no, go to authenticated state (which will show PIN setup)
        final pinSet = await _pinService.isPinSet();
        if (pinSet) {
          state = AuthState(
            status: AuthStatus.pinRequired,
            email: result.email,
            displayName: result.displayName,
            provider: result.provider,
          );
        } else {
          state = AuthState(
            status: AuthStatus.authenticated,
            email: result.email,
            displayName: result.displayName,
            provider: result.provider,
          );
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> skipAuth() async {
    // Сохраняем, что авторизация пройдена (даже если пропущена)
    await _storage.write(key: _authCompletedKey, value: 'true');
    state = const AuthState(status: AuthStatus.authenticated);
  }

  Future<void> _saveAuthData(AuthResult result) async {
    await _storage.write(key: _authEmailKey, value: result.email);
    await _storage.write(key: _authDisplayNameKey, value: result.displayName);
    await _storage.write(key: _authProviderKey, value: result.provider.name);
    if (result.userId != null) {
      await _storage.write(key: _authUserIdKey, value: result.userId!);
    }
    await _storage.write(key: _authCompletedKey, value: 'true');
  }

  Future<void> setPin(String pin) async {
    await _pinService.setPin(pin);
    // Обновляем статус только если еще не в состоянии authenticatedWithPin,
    // чтобы не пересоздавать роутер и не сбрасывать текущую страницу (например, Profile).
    if (state.status != AuthStatus.authenticatedWithPin) {
      state = state.copyWith(status: AuthStatus.authenticatedWithPin);
    }
  }

  /// Change PIN after verifying the current one.
  Future<void> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    if (newPin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(newPin)) {
      throw ArgumentError('New PIN must be exactly 4 digits');
    }
    final isCurrentValid = await _pinService.verifyPin(currentPin);
    if (!isCurrentValid) {
      throw StateError('Current PIN is incorrect');
    }
    await _pinService.setPin(newPin);
    // Смена PIN не должна менять текущую страницу, если пользователь уже авторизован с PIN.
    if (state.status != AuthStatus.authenticatedWithPin) {
      state = state.copyWith(status: AuthStatus.authenticatedWithPin);
    }
  }

  Future<bool> verifyPin(String pin) async {
    final isValid = await _pinService.verifyPin(pin);
    if (isValid) {
      // Re-derive encryption key from Firebase UID on each PIN entry
      // so cloud data is accessible after reinstall
      final firebaseUser = _authService.currentUser;
      if (firebaseUser != null) {
        await _encryptionService?.initializeForUser(firebaseUser.uid);
      }
      state = state.copyWith(status: AuthStatus.authenticatedWithPin);
    }
    return isValid;
  }

  /// Manually update email (e.g., after linking account or user edit).
  Future<void> updateEmail(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Email cannot be empty');
    }
    await _storage.write(key: _authEmailKey, value: trimmed);
    state = state.copyWith(email: trimmed);
  }

  /// Switch to a different Google account without clearing PIN
  /// This is used when user wants to change their email/account
  Future<void> switchAccount() async {
    await _authService.signOut();
    await _encryptionService?.clearKey();
    // Clear auth data but keep PIN and auth_completed flag
    // This allows user to switch accounts without re-setting PIN
    await _storage.delete(key: _authEmailKey);
    await _storage.delete(key: _authDisplayNameKey);
    await _storage.delete(key: _authProviderKey);
    await _storage.delete(key: _authUserIdKey);
    // Don't delete _authCompletedKey and don't clear PIN
    // This ensures PIN setup is only shown on first app launch
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Full sign out - clears everything including PIN
  Future<void> signOut() async {
    await _authService.signOut();
    await _encryptionService?.clearKey();
    await _storage.delete(key: _authEmailKey);
    await _storage.delete(key: _authDisplayNameKey);
    await _storage.delete(key: _authProviderKey);
    await _storage.delete(key: _authUserIdKey);
    await _storage.delete(key: _authCompletedKey);
    await _pinService.clearPin();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  bool get isAuthenticated =>
      state.status == AuthStatus.authenticated ||
      state.status == AuthStatus.authenticatedWithPin;
}

