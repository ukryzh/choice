import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/pin_entry_screen.dart';
import 'screens/auth/pin_setup_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/legal/faq_screen.dart';
import 'screens/legal/terms_screen.dart';
import 'screens/legal/privacy_policy_screen.dart';
import 'screens/log_cycle/log_cycle_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'state/app_providers.dart';
import 'state/auth_notifier.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: _getInitialLocation(authState),
    redirect: (context, state) {
      final currentAuthState = ref.read(authNotifierProvider);
      final isLoginPage = state.matchedLocation == LoginScreen.routePath;
      final isPinSetupPage = state.matchedLocation == PinSetupScreen.routePath;
      final isPinEntryPage = state.matchedLocation == PinEntryScreen.routePath;
      final isAuthPage = isLoginPage || isPinSetupPage || isPinEntryPage;

      // Если авторизован с PIN и на страницах авторизации - редирект на главную
      if (currentAuthState.status == AuthStatus.authenticatedWithPin && isAuthPage) {
        return HomeScreen.routePath;
      }

      // Если НЕ авторизован с PIN - проверяем, куда направить
      if (currentAuthState.status != AuthStatus.authenticatedWithPin) {
        // Если PIN установлен (требуется ввод) - показываем PIN Entry
        if (currentAuthState.status == AuthStatus.pinRequired) {
          if (!isPinEntryPage) {
            return PinEntryScreen.routePath;
          }
          return null;
        }

        // Если авторизован, но PIN не установлен - показываем PIN Setup
        if (currentAuthState.status == AuthStatus.authenticated) {
          if (!isPinSetupPage) {
            return PinSetupScreen.routePath;
          }
          return null;
        }

        // Если не авторизован (первый запуск) - показываем Login
        if (currentAuthState.status == AuthStatus.unauthenticated) {
          if (!isLoginPage) {
            return LoginScreen.routePath;
          }
          return null;
        }
      }

      // Защита основных страниц - требуем авторизацию с PIN
      if (!isAuthPage && currentAuthState.status != AuthStatus.authenticatedWithPin) {
        if (currentAuthState.status == AuthStatus.pinRequired) {
          return PinEntryScreen.routePath;
        }
        if (currentAuthState.status == AuthStatus.authenticated) {
          return PinSetupScreen.routePath;
        }
        return LoginScreen.routePath;
      }

      return null;
    },
    routes: [
      GoRoute(
        name: LoginScreen.routeName,
        path: LoginScreen.routePath,
        pageBuilder: _page((_, __) => const LoginScreen()),
      ),
      GoRoute(
        name: PinSetupScreen.routeName,
        path: PinSetupScreen.routePath,
        pageBuilder: _page((_, __) => const PinSetupScreen()),
      ),
      GoRoute(
        name: PinEntryScreen.routeName,
        path: PinEntryScreen.routePath,
        pageBuilder: _page((_, __) => const PinEntryScreen()),
      ),
      GoRoute(
        name: HomeScreen.routeName,
        path: HomeScreen.routePath,
        pageBuilder: _page((_, __) => const HomeScreen()),
      ),
      GoRoute(
        name: LogCycleScreen.routeName,
        path: LogCycleScreen.routePath,
        pageBuilder: _page(
          (context, state) => LogCycleScreen(
            initialDay: state.extra as DateTime?,
          ),
        ),
      ),
      GoRoute(
        name: ProfileScreen.routeName,
        path: ProfileScreen.routePath,
        pageBuilder: _page((_, __) => const ProfileScreen()),
      ),
      GoRoute(
        name: TermsScreen.routeName,
        path: TermsScreen.routePath,
        pageBuilder: _page((_, __) => const TermsScreen()),
      ),
      GoRoute(
        name: PrivacyPolicyScreen.routeName,
        path: PrivacyPolicyScreen.routePath,
        pageBuilder: _page((_, __) => const PrivacyPolicyScreen()),
      ),
      GoRoute(
        name: FaqScreen.routeName,
        path: FaqScreen.routePath,
        pageBuilder: _page((_, __) => const FaqScreen()),
      ),
    ],
  );
});

String _getInitialLocation(AuthState authState) {
  switch (authState.status) {
    case AuthStatus.unauthenticated:
      return LoginScreen.routePath;
    case AuthStatus.authenticated:
      return PinSetupScreen.routePath;
    case AuthStatus.pinRequired:
      return PinEntryScreen.routePath;
    case AuthStatus.authenticatedWithPin:
      return HomeScreen.routePath;
    default:
      return LoginScreen.routePath;
  }
}

GoRouterPageBuilder _page(
    Widget Function(BuildContext, GoRouterState) builder) {
  return (context, state) => MaterialPage(
        key: state.pageKey,
        child: builder(context, state),
      );
}


