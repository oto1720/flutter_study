# Phase 4: Presentation 層（Provider）— DI グラフ / AuthState / Notifier

## 概要

Riverpod を使って依存性注入（DI）グラフを構築し、
認証状態（AuthState）の遷移を管理する Notifier を実装する。
**Widget なしで状態遷移をテストできる**ことがこの層の設計目標。

---

## 1. DI グラフとは何か

DI（Dependency Injection）とは「クラスが自分で依存物を作らず、外から注入してもらう」パターン。

```dart
// ❌ DI なし: テストで差し替えられない
class SignInWithEmail {
  final _repository = AuthRepositoryImpl(
    AuthRemoteDataSourceImpl(
      FirebaseAuth.instance,
      GoogleSignIn(),
    ),
  );
}

// ✅ DI あり: コンストラクタで注入 → テストで差し替え可能
class SignInWithEmail {
  final AuthRepository _repository; // インターフェースに依存
  const SignInWithEmail(this._repository);
}
```

Riverpod では Provider がこの「注入の仕組み」を提供する。

---

## 2. auth_providers.dart — DI グラフの全体

```
FirebaseAuth.instance  GoogleSignIn()
        ↓                    ↓
authRemoteDataSourceProvider（AuthRemoteDataSourceImpl）
        ↓
authRepositoryProvider（AuthRepositoryImpl）
        ├── authStateChangesProvider（Stream<AppUser?>）
        ├── signInWithEmailUseCaseProvider
        ├── signInWithGoogleUseCaseProvider
        ├── signUpWithEmailUseCaseProvider
        ├── signOutUseCaseProvider
        └── getCurrentUserUseCaseProvider
```

**テストでの差し替え：**

```dart
// 本番コード: 上記の連鎖がそのまま動く
// テストコード: authRepositoryProvider を1箇所差し替えるだけで
// 全 UseCase が Mock Repository を使うようになる

ProviderContainer(
  overrides: [
    authRepositoryProvider.overrideWithValue(mockRepository),
    // ↑ この1行で signInWithEmailUseCase も signOutUseCase も全部 Mock を使う
  ],
)
```

---

## 3. @riverpod アノテーション — コード生成の仕組み

```dart
// 書くコード
@riverpod
FirebaseAuth firebaseAuth(Ref ref) => FirebaseAuth.instance;

// build_runner が生成するコード（firebase_auth_providers.g.dart）
final firebaseAuthProvider = AutoDisposeProvider<FirebaseAuth>.internal(
  firebaseAuth,
  name: r'firebaseAuthProvider',
  ...
);
```

**`@riverpod` が生成するものの一覧：**

| アノテーション | 生成される Provider の型 | 用途 |
|---|---|---|
| 関数に `@riverpod` | `AutoDisposeProvider<T>` | 単純な値・オブジェクト |
| Stream を返す関数に `@riverpod` | `AutoDisposeStreamProvider<T>` | 継続ストリーム |
| クラスに `@riverpod` | `AutoDisposeNotifierProvider<T>` | 状態を持つ Notifier |

**`AutoDispose` とは：**

Provider を誰も watch していない（リスナーがいない）状態になったとき、自動的に破棄する。
メモリリーク防止のため、デフォルトは `AutoDispose` がオン。

```dart
// AutoDispose がある場合
// 画面を離れてリスナーがいなくなると Provider が破棄される → メモリ解放

// keepAlive: true にすると破棄しない（キャッシュとして使いたいとき）
@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) => ...
```

---

## 4. AuthState — Sealed class による状態表現

### コード

```dart
@freezed
sealed class AuthState with _$AuthState {
  const factory AuthState.initial() = _Initial;
  const factory AuthState.loading() = _Loading;
  const factory AuthState.authenticated(AppUser user) = _Authenticated;
  const factory AuthState.unauthenticated() = _Unauthenticated;
  const factory AuthState.error(Failure failure) = _Error;
}
```

### なぜ `bool isLoading` + `AppUser? user` ではいけないか

```dart
// ❌ フラグ方式: 矛盾する状態が生まれる可能性がある
class AuthState {
  final bool isLoading;
  final AppUser? user;
  final Failure? failure;
  // isLoading=true かつ user!=null という状態が存在できてしまう
  // どの組み合わせが有効か、UI が知る必要がある
}

// ✅ Sealed class: 状態は常に1つ。矛盾しない
sealed class AuthState {
  // authenticated のときだけ user を持つ
  const factory AuthState.authenticated(AppUser user) = _Authenticated;
  // error のときだけ failure を持つ
  const factory AuthState.error(Failure failure) = _Error;
}
```

### UI での使い方

```dart
// switch 文で全パターンを強制処理
return switch (authState) {
  _Initial()                  => const SplashScreen(),
  _Loading()                  => const CircularProgressIndicator(),
  _Authenticated(:final user) => HomeContent(user: user),
  _Unauthenticated()          => const LoginForm(),
  _Error(:final failure)      => ErrorDisplay(failure: failure),
};
// ↑ 1つでも書き忘れると「非網羅的な switch」コンパイルエラー

// maybeWhen: 必要なケースだけ処理
final isLoading = authState.maybeWhen(
  loading: () => true,
  orElse: () => false,
);
```

---

## 5. AuthStateNotifier — 状態遷移の実装

### コード

```dart
@riverpod
class AuthStateNotifier extends _$AuthStateNotifier {
  @override
  AuthState build() {
    // ① Firebase の authStateChanges ストリームを監視
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
    return const AuthState.initial(); // 初期状態
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = const AuthState.loading(); // ② ローディング開始

    final result = await ref
        .read(signInWithEmailUseCaseProvider)
        .call(email: email, password: password);

    // ③ 結果に応じて状態を更新
    state = result.fold(
      AuthState.error,         // Left → error 状態
      AuthState.authenticated, // Right → authenticated 状態
    );
  }
}
```

### `ref.listen` vs `ref.watch`

| | `ref.watch` | `ref.listen` |
|---|---|---|
| 用途 | 値を読む + 変化で再描画 | 変化を検知して副作用を実行 |
| 使う場所 | `build()` メソッド内 | `build()` 内でも可 |
| 戻り値 | 現在の値 | なし（コールバックを受け取る） |

```dart
// watch: 値が変化するとウィジェットを再描画
final user = ref.watch(currentUserProvider);

// listen: 値が変化したときだけ処理を実行（再描画はしない）
ref.listen(authStateChangesProvider, (previous, next) {
  // previous: 変化前の値
  // next: 変化後の値
  if (next.hasValue && next.value != null) {
    navigateToHome();
  }
});
```

### `ref.read` vs `ref.watch`（Notifier 内での使い分け）

```dart
// ✅ Notifier のメソッド内では ref.read を使う
// （メソッドは build() の外で呼ばれるため、watch で監視する必要がない）
Future<void> signInWithEmail(...) async {
  final result = await ref.read(signInWithEmailUseCaseProvider).call(...);
}

// ❌ メソッド内で ref.watch は使わない
// （build() の外で watch すると意図しない再ビルドが起きる）
Future<void> signInWithEmail(...) async {
  final useCase = ref.watch(signInWithEmailUseCaseProvider); // ❌
}
```

### `result.fold(AuthState.error, AuthState.authenticated)` の意味

```dart
// fold は (Left処理, Right処理) を受け取る
state = result.fold(
  AuthState.error,         // Left の場合: AuthState.error(failure)
  AuthState.authenticated, // Right の場合: AuthState.authenticated(user)
);

// これは以下と同じ意味（簡略記法）
state = result.fold(
  (failure) => AuthState.error(failure),
  (user)    => AuthState.authenticated(user),
);
```

---

## 6. テスト戦略 — ProviderContainer を使ったテスト

### なぜ Widget なしでテストできるか

```dart
// ProviderContainer = Provider のストア（ProviderScope の非 Widget 版）
final container = ProviderContainer(
  overrides: [
    authRepositoryProvider.overrideWithValue(mockRepository),
  ],
);

// Widget なしで Notifier のメソッドを呼べる
await container.read(authStateNotifierProvider.notifier).signInWithEmail(...);

// Widget なしで状態を確認できる
final state = container.read(authStateNotifierProvider);
expect(state, AuthState.authenticated(tUser));
```

### 状態遷移の順序を検証する方法

```dart
final states = <AuthState>[];

// listen で全状態変化を記録
container.listen(
  authStateNotifierProvider,
  (_, next) => states.add(next),
  fireImmediately: false, // 初期状態は記録しない
);

await container.read(authStateNotifierProvider.notifier)
    .signInWithEmail('a@b.com', 'pass');

// 遷移の順序を検証
expect(states, [
  const AuthState.loading(),       // まず loading
  AuthState.authenticated(tUser),  // 次に authenticated
]);
```

### StreamController を使ってストリームを制御する

```dart
// ❌ Stream.value(null) だと即座に emit して状態を上書きしてしまう
when(() => mockRepository.authStateChanges)
    .thenAnswer((_) => Stream.value(null));
// → signInWithEmail の途中に unauthenticated が割り込む

// ✅ StreamController で発火タイミングを制御
final controller = StreamController<AppUser?>.broadcast();
when(() => mockRepository.authStateChanges)
    .thenAnswer((_) => controller.stream);

// 任意のタイミングでイベントを流せる
controller.add(tUser);    // → authenticated に遷移
controller.add(null);     // → unauthenticated に遷移
```

### `addTearDown(container.dispose)` でメモリリーク防止

```dart
setUp(() {
  container = ProviderContainer(...);
  addTearDown(container.dispose); // テスト終了後に必ず dispose
});
```

`dispose()` を呼ばないと、Provider のリスナーが残り続けてメモリリークになる。
`addTearDown` は Flutter Test の仕組みで、テスト終了時に自動的に呼ばれる。

---

## 7. つまずきポイントと解決策

### 問題: テストで `unauthenticated` が `loading` と `authenticated` の間に割り込む

```
Expected: [loading, authenticated]
Actual:   [loading, unauthenticated, authenticated]
```

**原因：** `Stream.value(null)` を使ったため、
stream がすぐに `null` を emit → `ref.listen` が `unauthenticated` を設定してしまう。

**解決：** `StreamController.broadcast()` を使い、ストリームの発火タイミングを手動制御する。

### 問題: `unnecessary_underscores` lint エラー

```dart
// ❌ 二重アンダースコアの無名変数
error: (_, __) => state = const AuthState.unauthenticated(),

// ✅ 意味のある名前に変更
error: (e, s) => state = const AuthState.unauthenticated(),
```

---

## 8. 完了チェックリスト

- [ ] `auth_providers.dart` が build_runner で `.g.dart` を生成できる
- [ ] `authRepositoryProvider` を override するだけで全 UseCase が Mock を使う
- [ ] `AuthState` の全パターンが Sealed class で定義されている
- [ ] `AuthStateNotifier.signInWithEmail` が loading → authenticated/error の遷移をする
- [ ] `ref.listen` で authStateChanges ストリームが自動的に状態を更新する
- [ ] Notifier テストが全通過（Widget なし）

---

## 9. 次のフェーズへの接続

Phase 4 で作った `authStateNotifierProvider` を、
Phase 5 の UI が watch して画面を描画する。

```dart
// Phase 5 (login_screen.dart)
final isLoading = ref.watch(
  authStateNotifierProvider.select(
    (s) => s.maybeWhen(loading: () => true, orElse: () => false),
  ),
);
// ↑ loading 状態のときだけ true → ボタンを無効化
```
