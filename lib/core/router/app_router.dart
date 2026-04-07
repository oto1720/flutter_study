import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_learn/features/auth/presentation/providers/auth_state_notifier.dart';
import 'package:flutter_learn/features/auth/presentation/screens/home_screen.dart';
import 'package:flutter_learn/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_learn/features/auth/presentation/screens/register_screen.dart';
import 'package:flutter_learn/features/leak_demo/leak_demo_menu_screen.dart';
import 'package:flutter_learn/features/leak_demo/pattern1_stream_screen.dart';
import 'package:flutter_learn/features/leak_demo/pattern2_controller_screen.dart';
import 'package:flutter_learn/features/leak_demo/pattern3_listener_screen.dart';
import 'package:flutter_learn/features/leak_demo/pattern4_async_context_screen.dart';

part 'app_router.g.dart';

/// ルート名の定数
abstract final class Routes {
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  // メモリリーク学習デモ
  static const leakDemo = '/leak-demo';
  static const leakPattern1 = '/leak-demo/pattern1';
  static const leakPattern2 = '/leak-demo/pattern2';
  static const leakPattern3 = '/leak-demo/pattern3';
  static const leakPattern4 = '/leak-demo/pattern4';
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
      GoRoute(
        path: Routes.leakDemo,
        builder: (context, state) => const LeakDemoMenuScreen(),
      ),
      GoRoute(
        path: Routes.leakPattern1,
        builder: (context, state) => const Pattern1CompareScreen(),
      ),
      GoRoute(
        path: Routes.leakPattern2,
        builder: (context, state) => const Pattern2CompareScreen(),
      ),
      GoRoute(
        path: Routes.leakPattern3,
        builder: (context, state) => const Pattern3CompareScreen(),
      ),
      GoRoute(
        path: Routes.leakPattern4,
        builder: (context, state) => const Pattern4CompareScreen(),
      ),
    ],
  );
}
