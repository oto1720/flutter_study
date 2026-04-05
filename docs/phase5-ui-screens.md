# Phase 5: UI 画面 — GoRouter 認証ガード / 3 画面 / Widget テスト

## 概要

GoRouter の `redirect` 機能で認証ガードを実装し、
ログイン・登録・ホームの 3 画面を構築する。
Widget テストで UI の振る舞いを検証する。

---

## 1. GoRouter の認証ガード設計

### なぜ画面ごとに認証チェックを書かないのか

```dart
// ❌ 画面ごとに認証チェック: DRY 原則違反・漏れが出やすい
class HomeScreen extends StatelessWidget {
  Widget build(BuildContext context) {
    // 全画面にこれを書くのは冗長で漏れが起きやすい
    if (!isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/login');
      });
      return const SizedBox.shrink();
    }
    return HomeContent();
  }
}

// ✅ Router に集約: 1 箇所だけ修正すれば全画面に反映
redirect: (context, state) {
  if (!isAuthenticated && !isOnAuthPage) return '/login';
  if (isAuthenticated && isOnAuthPage) return '/home';
  return null;
}
```

### コード

```dart
@riverpod
GoRouter appRouter(Ref ref) {
  // authStateNotifierProvider を watch → 認証状態が変わると redirect が再実行
  final authState = ref.watch(authStateNotifierProvider);

  return GoRouter(
    initialLocation: Routes.login,
    redirect: (BuildContext context, GoRouterState state) {
      final isAuthenticated = authState.maybeWhen(
        authenticated: (_) => true,
        orElse: () => false,
      );
      final isOnAuthPage =
          state.matchedLocation == Routes.login ||
          state.matchedLocation == Routes.register;

      if (!isAuthenticated && !isOnAuthPage) return Routes.login;
      if (isAuthenticated && isOnAuthPage) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(path: Routes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (_, __) => const RegisterScreen()),
      GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen()),
    ],
  );
}
```

### 認証状態変化時の自動リダイレクト

```
ユーザーがサインイン
    ↓
AuthStateNotifier.state が authenticated に変化
    ↓
appRouterProvider が再評価（ref.watch しているため）
    ↓
redirect 関数が再実行
    ↓
isAuthenticated=true + isOnAuthPage=true → '/home' を返す
    ↓
GoRouter が /home に自動ナビゲート
```

この仕組みにより、`signInWithEmail` の完了後に手動で `context.go('/home')` を呼ぶ必要がない。

---

## 2. main.dart — MaterialApp.router への接続

```dart
class MyApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // appRouterProvider を watch
    // → authStateNotifier が変化 → appRouter が再生成 → 自動リダイレクト
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      routerConfig: router, // GoRouter を渡す
    );
  }
}
```

**`MaterialApp` vs `MaterialApp.router` の違い：**

| | `MaterialApp` | `MaterialApp.router` |
|---|---|---|
| ナビゲーション | `Navigator` を直接使う | `RouterConfig`（GoRouter）を使う |
| ディープリンク | 手動実装が必要 | GoRouter が自動処理 |
| 宣言的ルーティング | 不可 | 可能（redirect） |

---

## 3. LoginScreen — 設計のポイント

### ref.listen でエラーを SnackBar 表示

```dart
ref.listen<AuthState>(authStateNotifierProvider, (previous, next) {
  next.maybeWhen(
    error: (failure) {
      final message = switch (failure) {
        AuthFailure(:final message) => message,        // Firebase のエラーメッセージ
        NetworkFailure() => 'ネットワークエラーが発生しました',
        UnexpectedFailure() => '予期しないエラーが発生しました',
      };
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    },
    orElse: () {},
  );
});
```

**なぜ `ref.watch` ではなく `ref.listen` か：**

```dart
// watch: 毎回 build() が呼ばれるたびに実行
// → SnackBar を毎回表示してしまう

// listen: 値が「変化した」ときだけ実行
// → エラーになったタイミング 1 回だけ SnackBar を出す
```

### select で isLoading だけ監視する（不要なリビルド防止）

```dart
// ❌ 全状態を監視: loading 以外の変化でもリビルドが起きる
final authState = ref.watch(authStateNotifierProvider);
final isLoading = authState is _Loading; // ← ビルドできない（private クラス）

// ✅ select で loading の真偽値だけ監視
final isLoading = ref.watch(
  authStateNotifierProvider.select(
    (s) => s.maybeWhen(loading: () => true, orElse: () => false),
  ),
);
// isLoading の値が変わったときだけリビルド（true→false, false→true のみ）
```

**`select` の原理：**

```
select((s) => s.maybeWhen(...)) が返す値が
前回と同じ場合 → リビルドしない
前回と違う場合 → リビルドする

例:
  authenticated → loading: true に変化 → リビルド
  authenticated → error:   false のまま → リビルドしない
```

---

## 4. Freezed プライベートクラスの扱い

### 問題: `is _Authenticated` が外部ファイルで使えない

```dart
// ❌ コンパイルエラー（_Authenticated は private クラス）
final isAuthenticated = authState is _Authenticated;

// ❌ コンパイルエラー（外部ファイルからは _Loading にアクセスできない）
final isLoading = authState is _Loading;
```

**なぜこうなるか：**

Freezed が `= _Authenticated` と書いたとき、`_Authenticated` はプライベートクラスとして生成される。
プライベートクラスは同一ファイル（同一ライブラリ）の中からしか参照できない。

**解決策：`maybeWhen` / `when` を使う**

```dart
// ✅ maybeWhen: 特定ケースのみ処理
final isAuthenticated = authState.maybeWhen(
  authenticated: (_) => true,
  orElse: () => false,
);

final isLoading = authState.maybeWhen(
  loading: () => true,
  orElse: () => false,
);

// ✅ when: 全ケースを処理（1つでも抜けるとコンパイルエラー）
final text = authState.when(
  initial: () => '初期化中',
  loading: () => '読み込み中',
  authenticated: (user) => 'ようこそ ${user.email}',
  unauthenticated: () => 'ログインしてください',
  error: (failure) => 'エラー: $failure',
);
```

**`when` vs `maybeWhen` の使い分け：**

| | `when` | `maybeWhen` |
|---|---|---|
| 全ケース | 必須（漏れるとコンパイルエラー） | 不要（`orElse` でまとめて処理） |
| 使用場面 | 全ケースに異なる処理がある | 一部のケースだけ特別処理したい |

---

## 5. ConsumerWidget / ConsumerStatefulWidget

> **Note:** Phase 6 で `ConsumerStatefulWidget` → `HookConsumerWidget` に移行した。
> 現在の `LoginScreen` / `RegisterScreen` は `HookConsumerWidget` を使っている。
> 移行の詳細は [phase6-flutter-hooks.md](./phase6-flutter-hooks.md) を参照。

### なぜ通常の Widget ではなく Consumer 系を使うか

```dart
// StatelessWidget: ref が使えない
class LoginScreen extends StatelessWidget {
  Widget build(BuildContext context) {
    // ref が存在しない → ref.watch / ref.listen 不可
  }
}

// ConsumerWidget: ref が使える（StatelessWidget の Riverpod 版）
class HomeScreen extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateNotifierProvider); // OK
  }
}

// ConsumerStatefulWidget: ref + State が両方使える
// TextEditingController などのローカル状態が必要な場面で使う（Phase 5 時点の実装）
class LoginScreen extends ConsumerStatefulWidget {
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController(); // ローカル状態
  Widget build(BuildContext context) {
    ref.listen(...); // ref も使える
  }
}

// HookConsumerWidget: ConsumerStatefulWidget の代替（Phase 6 以降）
// useTextEditingController で dispose 不要・State クラス不要
class LoginScreen extends HookConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    final emailController = useTextEditingController(); // 自動 dispose
    ref.listen(...); // ref も使える
  }
}
```

### `dispose()` でコントローラーをクリーンアップ（Phase 5 時点）

```dart
// Phase 5: ConsumerStatefulWidget では手動 dispose が必要だった
@override
void dispose() {
  _emailController.dispose();   // メモリ解放
  _passwordController.dispose();
  super.dispose(); // 必ず呼ぶ
}
```

`TextEditingController` は内部でリスナーを持つため、`dispose()` を呼ばないとメモリリークになる。
Phase 6 では `useTextEditingController()` が自動で `dispose` するため、この記述が不要になった。

---

## 6. Widget テスト戦略

### FakeAuthStateNotifier でテスト用の初期状態を注入

```dart
// テスト用の Notifier: 任意の初期状態を返す
class FakeAuthStateNotifier extends AuthStateNotifier {
  FakeAuthStateNotifier(this._initialState);
  final AuthState _initialState;

  @override
  AuthState build() => _initialState; // Firebase なしで固定値を返す
}

// テストヘルパー: ProviderScope でラップして pump
Widget buildLoginScreen(AuthState initialState) {
  return ProviderScope(
    overrides: [
      authStateNotifierProvider.overrideWith(
        () => FakeAuthStateNotifier(initialState),
      ),
    ],
    child: const MaterialApp(home: LoginScreen()),
  );
}
```

### テストコードの読み方

```dart
testWidgets('バリデーション: 空のまま送信するとエラーメッセージが表示される', (tester) async {
  // 1. 画面を描画
  await tester.pumpWidget(
    buildLoginScreen(const AuthState.unauthenticated()),
  );

  // 2. ボタンをタップ（フォームは空のまま）
  await tester.tap(find.widgetWithText(FilledButton, 'ログイン'));

  // 3. バリデーションの結果を描画
  await tester.pump();

  // 4. エラーメッセージが表示されているか確認
  expect(find.text('メールアドレスを入力してください'), findsOneWidget);
  expect(find.text('パスワードを入力してください'), findsOneWidget);
});
```

### `pump()` vs `pumpAndSettle()` の違い

| メソッド | 動作 | 使う場面 |
|---|---|---|
| `pump()` | 1フレーム進める | バリデーション・同期処理の確認 |
| `pump(Duration)` | 指定時間分フレームを進める | アニメーション途中の確認 |
| `pumpAndSettle()` | アニメーションが終わるまで進める | SnackBar の表示完了など |

### SnackBar の表示テスト（状態変化のトリガー）

```dart
testWidgets('error 状態のとき SnackBar が表示される', (tester) async {
  await tester.pumpWidget(
    buildLoginScreen(const AuthState.unauthenticated()),
  );

  // ref.listen は「変化」を検知するため、
  // 別の状態から error 状態に遷移させる必要がある
  final container = ProviderScope.containerOf(
    tester.element(find.byType(LoginScreen)),
  );

  // unauthenticated → error に遷移させる
  container.read(authStateNotifierProvider.notifier).state =
      const AuthState.error(
        Failure.auth(message: 'パスワードが間違っています', code: 'wrong-password'),
      );
  await tester.pump();

  expect(find.byType(SnackBar), findsOneWidget);
  expect(find.text('パスワードが間違っています'), findsOneWidget);
});
```

---

## 7. つまずきポイントと解決策

### 問題: `is _Authenticated` が外部ファイルで使えない

```dart
// app_router.dart
final isAuthenticated = authState is _Authenticated; // ❌ コンパイルエラー
```

**解決：** `maybeWhen` に変更（詳細は Section 4 参照）

### 問題: GoRouter で `Ref` が未定義

```dart
@riverpod
GoRouter appRouter(Ref ref) { ... }
// Error: Undefined class 'Ref'
```

**原因：** `flutter_riverpod` をインポートしていなかった。

**解決：** `import 'package:flutter_riverpod/flutter_riverpod.dart';` を追加

### 問題: widget_test.dart が Phase 5 で失敗する

**原因：** `main.dart` が `MaterialApp.router` に変わり、
以前のテストで確認していたテキストが画面に存在しなくなった。

**解決：** テストを `LoginScreen` のテストに更新

```dart
testWidgets('Phase 5: 未認証状態でアプリ起動するとログイン画面が表示される', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateNotifierProvider.overrideWith(
          () => _FakeUnauthNotifier(),
        ),
      ],
      child: const MaterialApp(home: LoginScreen()),
    ),
  );
  expect(find.text('ログイン'), findsWidgets);
});
```

---

## 8. 完了チェックリスト

- [ ] 未認証状態でアプリ起動 → ログイン画面が表示される
- [ ] ログイン成功 → ホーム画面に自動遷移する
- [ ] ホームからサインアウト → ログイン画面に自動遷移する
- [ ] 誤ったパスワード → SnackBar でエラーが表示される
- [ ] フォームが空の状態でログインボタン → バリデーションエラーが表示される
- [ ] Widget テストが全通過

---

## 9. アーキテクチャ全体の振り返り

Phase 1 〜 5 を通して実装したデータの流れ：

```
ユーザーが「ログイン」ボタンをタップ
    ↓
LoginScreen の onSignIn()（Phase 6 以降は build 内のローカル関数）
    ↓
ref.read(authStateNotifierProvider.notifier).signInWithEmail(email, password)
    ↓ [Phase 4: Notifier]
state = AuthState.loading()
    ↓
ref.read(signInWithEmailUseCaseProvider).call(email: email, password: password)
    ↓ [Phase 2: UseCase]
repository.signInWithEmail(email: email, password: password)
    ↓ [Phase 3: RepositoryImpl]
try {
  dataSource.signInWithEmail(email: email, password: password)
  ↓ [Phase 3: DataSource]
  FirebaseAuth.signInWithEmailAndPassword(email, password)
  ↓
  UserModel.fromFirebaseUser(user)
  ↓
  Right(model.toEntity())  ← AppUser
} on FirebaseAuthException catch (e) {
  Left(Failure.auth(message: e.message, code: e.code))
}
    ↓ [Phase 4: Notifier]
state = result.fold(AuthState.error, AuthState.authenticated)
    ↓ [Phase 5: GoRouter redirect]
isAuthenticated=true + isOnAuthPage=true → '/home' へリダイレクト
    ↓
HomeScreen が表示される
```
