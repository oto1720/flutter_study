import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_learn/features/auth/presentation/providers/auth_state_notifier.dart';
import 'package:flutter_learn/features/auth/presentation/screens/home_screen.dart';
import 'package:flutter_learn/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_learn/features/auth/presentation/screens/register_screen.dart';

part 'app_router.g.dart';

/// ルート名の定数
abstract final class Routes {
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
}

/// GoRouter の設定
///
/// redirect で認証ガードを一元管理する。
/// - 未認証 → /login へ強制リダイレクト
/// - 認証済みで /login or /register → /home へリダイレクト
@riverpod
GoRouter appRouter(Ref ref) {
  final authState = ref.watch(authStateNotifierProvider);

  return GoRouter(
    initialLocation: Routes.login,
    redirect: (BuildContext context, GoRouterState state) {
      // maybeWhen で authenticated ケースだけ true を返す
      final isAuthenticated = authState.maybeWhen(
        authenticated: (_) => true,
        orElse: () => false,
      );
      final isOnAuthPage =
          state.matchedLocation == Routes.login ||
          state.matchedLocation == Routes.register;

      // 未認証 + 認証ページ以外にアクセス → ログインへ
      if (!isAuthenticated && !isOnAuthPage) return Routes.login;
      // 認証済み + 認証ページにいる → ホームへ
      if (isAuthenticated && isOnAuthPage) return Routes.home;
      // それ以外はリダイレクト不要
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
}
