import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_learn/core/error/failure.dart';
import 'package:flutter_learn/features/auth/domain/entities/app_user.dart';
import 'package:flutter_learn/features/auth/presentation/providers/auth_providers.dart';

part 'auth_state_notifier.freezed.dart';
part 'auth_state_notifier.g.dart';

// ---------------------------------------------------------------------------
// AuthState: 認証状態の全パターンを Sealed class で表現
//
// なぜ Sealed class か？
//   - `bool isLoading + User? user` のような複数フラグは
//     「isLoading=true かつ user=non-null」という矛盾状態が生まれる
//   - Sealed class なら状態は常に1つ。コンパイラが switch の全ケース網羅を強制する
// ---------------------------------------------------------------------------

@freezed
sealed class AuthState with _$AuthState {
  /// アプリ起動直後（Firebase の状態確認前）
  const factory AuthState.initial() = _Initial;

  /// 処理中（ログイン/登録ボタンを押した後）
  const factory AuthState.loading() = _Loading;

  /// 認証済み
  const factory AuthState.authenticated(AppUser user) = _Authenticated;

  /// 未認証（ログアウト後 or 未ログイン）
  const factory AuthState.unauthenticated() = _Unauthenticated;

  /// エラー（ログイン失敗など）
  const factory AuthState.error(Failure failure) = _Error;
}

// ---------------------------------------------------------------------------
// AuthStateNotifier: 状態遷移を管理する Notifier
// ---------------------------------------------------------------------------

@riverpod
class AuthStateNotifier extends _$AuthStateNotifier {
  @override
  AuthState build() {
    // Firebase の authStateChanges ストリームを監視
    // ログイン・ログアウトが起きると自動で状態が更新される
    ref.listen<AsyncValue<AppUser?>>(
      authStateChangesProvider,
      (_, next) {
        next.when(
          data: (user) {
            state = user != null
                ? AuthState.authenticated(user)
                : const AuthState.unauthenticated();
          },
          loading: () => state = const AuthState.loading(),
          error: (e, s) => state = const AuthState.unauthenticated(),
        );
      },
    );
    return const AuthState.initial();
  }

  /// メールアドレス + パスワードでサインイン
  Future<void> signInWithEmail(String email, String password) async {
    state = const AuthState.loading();
    final result = await ref
        .read(signInWithEmailUseCaseProvider)
        .call(email: email, password: password);
    state = result.fold(
      AuthState.error,
      AuthState.authenticated,
    );
  }

  /// Google アカウントでサインイン
  Future<void> signInWithGoogle() async {
    state = const AuthState.loading();
    final result = await ref.read(signInWithGoogleUseCaseProvider).call();
    state = result.fold(
      AuthState.error,
      AuthState.authenticated,
    );
  }

  /// 新規登録
  Future<void> signUpWithEmail(String email, String password) async {
    state = const AuthState.loading();
    final result = await ref
        .read(signUpWithEmailUseCaseProvider)
        .call(email: email, password: password);
    state = result.fold(
      AuthState.error,
      AuthState.authenticated,
    );
  }

  /// サインアウト
  Future<void> signOut() async {
    state = const AuthState.loading();
    final result = await ref.read(signOutUseCaseProvider).call();
    state = result.fold(
      AuthState.error,
      (_) => const AuthState.unauthenticated(),
    );
  }
}
