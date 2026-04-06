# Phase 7: テスト戦略 — 4層テストで壊れないコードベースを作る

## 概要

テストは「動くことを確認するため」ではなく、**「安全にリファクタリングするため」** に書く。
テストがあるから大胆に改善できる。テストがないコードは触るのが怖い。
この Phase では 4 層に分けたテスト戦略と、テストの読み方・書き方・確認方法を学ぶ。

---

## 1. なぜテストを書くか

### テストなしの開発がどう壊れるか

```
機能 A を変更
  ↓
機能 B が壊れる（A に依存していた）
  ↓
手動で全画面を確認する（時間がかかる）
  ↓
見逃して本番でバグが発覚
  ↓
ユーザーに影響
```

### テストありの開発

```
機能 A を変更
  ↓
flutter test を実行（数秒）
  ↓
機能 B のテストが失敗 → 即座に気づく
  ↓
本番に届く前に修正完了
```

### テストが果たす3つの役割

| 役割 | 説明 |
|---|---|
| **リファクタリングの安全網** | テストがパスし続ける限り、内部を自由に変えられる |
| **仕様書** | テスト名が「何をすべきか」を語る。コードより先に読むべき |
| **設計の品質チェック** | テストしにくいコードは設計が悪いサイン。テストが書けないなら責務が混在している |

---

## 2. テストの実行方法

### 基本コマンド

```bash
# 全テストを実行
flutter test

# 特定のファイルだけ実行
flutter test test/features/auth/domain/usecases/sign_in_with_email_test.dart

# 特定のディレクトリ以下を実行
flutter test test/features/auth/

# カバレッジ付きで実行
flutter test --coverage
```

### テスト結果の見方

```
00:02 +57: All tests passed!
         ↑
         合計テスト数（全通過）

00:02 +56 -1: Some tests failed.
             ↑
             失敗数（-1 = 1件失敗）
```

### 失敗したときの出力例

```
✖ LoginScreen バリデーション: 空のまま送信するとエラーメッセージが表示される

  Expected: exactly one matching node in the widget tree
  Actual: no matching nodes

  Which: means none were found but one was expected

  package:flutter_test/src/matchers.dart 426:7  fail
  test/features/auth/presentation/screens/login_screen_test.dart 52:7  main.<fn>.<fn>
```

**読み方：**
1. どのテストが失敗したか（テスト名）
2. 何を期待したか（Expected）
3. 実際に何が起きたか（Actual）
4. どのファイルの何行目か（最後の行）

---

## 3. カバレッジの確認方法

### カバレッジとは

テストが実行したコードの割合。100行のうち70行がテストで通ったなら 70%。

```bash
# カバレッジ付きでテストを実行（coverage/lcov.info が生成される）
flutter test --coverage

# ファイルごとのカバレッジを確認（lcov がインストール済みの場合）
lcov --summary coverage/lcov.info

# インストールされていない場合は以下のコマンドで確認
grep -E "^DA:" coverage/lcov.info | awk '
  BEGIN { hit=0; total=0 }
  { split($0, a, ","); total++; if (a[2] > 0) hit++ }
  END { printf "Lines: %d/%d (%.1f%%)\n", hit, total, hit/total*100 }'
```

### カバレッジの数字をどう読むか

| カバレッジ | 意味 |
|---|---|
| 0% | そのファイルはテストで一切触れていない |
| 70% 以上 | 実用的な品質の目安（本プロジェクトの目標値） |
| 100% | 全行を実行したが、**ロジックが正しいことは保証しない** |

> **注意：** カバレッジが高くても、アサーション（`expect`）が正しくなければ意味がない。
> `expect(1 + 1, anything)` はカバレッジを上げるが、バグを検知しない。

### どこを優先して上げるか

```
優先度 高 ← UseCase・Repository（ビジネスロジック）
           ↓
           Notifier（状態遷移）
           ↓
           Widget（UI の振る舞い）
優先度 低 ← 生成コード（*.g.dart, *.freezed.dart）・Firebase SDK を直接呼ぶ箇所
```

Firebase や外部 SDK に直接触れるコードはモックなしではテストできないため、
`FakeDataSource` で代替する（後述）。

---

## 4. テスト戦略（4層）

```
Layer 1: Domain UseCase テスト
  ┌──────────────────────────────────┐
  │ 依存: MockAuthRepository のみ    │
  │ ツール: mocktail                 │
  │ Firebase: 不要                   │
  │ Widget: 不要                     │
  └──────────────────────────────────┘
           ↑ 最も純粋・最速・最も多く書く

Layer 2: Data Repository テスト
  ┌──────────────────────────────────┐
  │ 依存: FakeAuthRemoteDataSource   │
  │ ツール: flutter_test             │
  │ Firebase: 不要（Fake で代替）    │
  └──────────────────────────────────┘

Layer 3: Presentation Notifier テスト
  ┌──────────────────────────────────┐
  │ 依存: ProviderContainer          │
  │ ツール: hooks_riverpod           │
  │ Widget: 不要                     │
  └──────────────────────────────────┘

Layer 4: Widget テスト
  ┌──────────────────────────────────┐
  │ 依存: FakeAuthStateNotifier      │
  │ ツール: flutter_test + pump      │
  │ Firebase: 不要                   │
  └──────────────────────────────────┘
```

---

## 5. Layer 1: UseCase Unit テスト

### 何をテストするか

UseCase は「ビジネスルール」の塊。入力に対して正しい出力が返るかだけを確認する。

```
入力: email + password
  ↓
UseCase（SignInWithEmail）
  ↓
出力: Right(AppUser) または Left(Failure)
```

### コード（sign_in_with_email_test.dart）

```dart
void main() {
  late MockAuthRepository mockRepository;
  late SignInWithEmail useCase;

  // 各テスト前に実行（前準備）
  setUp(() {
    mockRepository = MockAuthRepository();
    useCase = SignInWithEmail(mockRepository);
  });

  group('SignInWithEmail', () {
    test('サインイン成功時に AppUser を返す', () async {
      // ① Arrange（準備）: リポジトリが返す値を設定
      when(
        () => mockRepository.signInWithEmail(
          email: tEmail,
          password: tPassword,
        ),
      ).thenAnswer((_) async => const Right(tUser));

      // ② Act（実行）: UseCase を呼ぶ
      final result = await useCase(email: tEmail, password: tPassword);

      // ③ Assert（検証）: 期待した値が返っているか
      expect(result, const Right(tUser));

      // ④ Verify（検証）: リポジトリが正しく呼ばれたか
      verify(() => mockRepository.signInWithEmail(
        email: tEmail,
        password: tPassword,
      )).called(1);
      verifyNoMoreInteractions(mockRepository);
    });
  });
}
```

### テストの構造: AAA パターン

| ステップ | 意味 | コード |
|---|---|---|
| **Arrange（準備）** | テストに必要な前提条件を整える | `when(...).thenAnswer(...)` |
| **Act（実行）** | テスト対象を実際に呼ぶ | `final result = await useCase(...)` |
| **Assert（検証）** | 結果が期待通りか確認する | `expect(result, ...)` |

### `when` / `thenAnswer` の読み方

```dart
// 「mockRepository の signInWithEmail が呼ばれたとき（when）、
//  非同期で Right(tUser) を返すように設定する（thenAnswer）」
when(
  () => mockRepository.signInWithEmail(
    email: any(named: 'email'),   // どんな email でも
    password: any(named: 'password'), // どんな password でも
  ),
).thenAnswer((_) async => const Right(tUser));
```

| mocktail API | 意味 |
|---|---|
| `when(() => ...).thenAnswer(...)` | 呼ばれたとき何を返すか設定 |
| `thenReturn(value)` | 同期的に値を返す |
| `thenAnswer((_) async => value)` | 非同期で値を返す |
| `thenThrow(exception)` | 例外を投げる |
| `any(named: 'x')` | `x` 引数がどんな値でもマッチ |
| `verify(() => ...).called(1)` | 1回だけ呼ばれたことを確認 |
| `verifyNoMoreInteractions(mock)` | 他に呼ばれていないことを確認 |

### なぜ Firebase を使わずにテストできるか

```dart
// ① AuthRepository は abstract class（インターフェース）
abstract class AuthRepository {
  Future<Either<Failure, AppUser>> signInWithEmail({...});
}

// ② MockAuthRepository は "振る舞いを設定できる偽物"
class MockAuthRepository extends Mock implements AuthRepository {}

// ③ UseCase はインターフェースしか知らない
class SignInWithEmail {
  final AuthRepository _repository; // 本物か偽物かを知らない
  Future<Either<Failure, AppUser>> call({...}) =>
      _repository.signInWithEmail(...);
}

// → テストでは偽物（Mock）を注入して Firebase なしでテスト可能
```

---

## 6. Layer 2: Repository テスト（FakeDataSource）

### Mock と Fake の違い

| | Mock | Fake |
|---|---|---|
| 作り方 | `extends Mock` でコード生成不要 | 実際に動くシンプルな代替実装を書く |
| 動き | `when` で振る舞いを都度設定 | インメモリで実際に動く |
| 使う場面 | 呼ばれたことの検証が必要なとき | 実装の振る舞い（CRUD）を通して確認したいとき |

### FakeAuthRemoteDataSource

```dart
// test/helpers/fakes/fake_auth_remote_data_source.dart

class FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  final Map<String, String> _users = {}; // email → password（インメモリ）
  UserModel? _currentUser;

  @override
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (!_users.containsKey(email)) {
      throw FirebaseAuthException(code: 'user-not-found', ...);
    }
    if (_users[email] != password) {
      throw FirebaseAuthException(code: 'wrong-password', ...);
    }
    final user = UserModel(id: 'uid-$email', email: email);
    _currentUser = user;
    return user;
  }

  // テスト用ヘルパー: 事前にユーザーを登録
  void seedUser({required String email, required String password}) {
    _users[email] = password;
  }
}
```

### テストコード（auth_repository_impl_test.dart）

```dart
setUp(() {
  fakeDataSource = FakeAuthRemoteDataSource();
  repository = AuthRepositoryImpl(fakeDataSource); // Fake を注入
});

test('登録済みユーザーでサインイン成功 → Right(AppUser) を返す', () async {
  // 事前にユーザーをインメモリに登録
  fakeDataSource.seedUser(email: tEmail, password: tPassword);

  final result = await repository.signInWithEmail(
    email: tEmail,
    password: tPassword,
  );

  expect(result.isRight(), isTrue);
  result.fold(
    (_) => fail('失敗が返るはずがない'),
    (user) => expect(user.email, tEmail),
  );
});
```

### `fold` の読み方

```dart
result.fold(
  (failure) => /* Left（失敗）の場合の処理 */,
  (user)    => /* Right（成功）の場合の処理 */,
);

// isLeft() / isRight() でざっくり確認してから中身を検証するパターン
expect(result.isRight(), isTrue);
result.fold(
  (_) => fail('ここには来ないはず'),  // 来たらテスト失敗
  (user) => expect(user.email, tEmail),
);
```

---

## 7. Layer 3: Notifier テスト（ProviderContainer）

### Widget なしで状態遷移をテストできる理由

Riverpod の `ProviderContainer` は Widget ツリーなしで動く DI コンテナ。
サーバーのユニットテストのような感覚で、状態遷移だけを純粋にテストできる。

```dart
// ✅ Widget が不要: ProviderContainer だけでテスト可能
final container = ProviderContainer(
  overrides: [
    authRepositoryProvider.overrideWithValue(mockRepository), // Mock を注入
  ],
);
addTearDown(container.dispose); // テスト後にリソース解放
```

### 状態遷移の順序をテスト

```dart
test('signInWithEmail 成功: loading → authenticated の順に遷移する', () async {
  when(
    () => mockRepository.signInWithEmail(
      email: any(named: 'email'),
      password: any(named: 'password'),
    ),
  ).thenAnswer((_) async => const Right(tUser));

  final container = makeContainer();
  final states = <AuthState>[]; // 状態の変化を全部記録

  // listen: 状態が変わるたびに states に追加
  container.listen(
    authStateNotifierProvider,
    (_, next) => states.add(next),
    fireImmediately: false, // 初期値は記録しない
  );

  // signInWithEmail を実行
  await container.read(authStateNotifierProvider.notifier)
      .signInWithEmail('test@example.com', 'password123');

  // loading → authenticated の順で遷移したことを確認
  expect(states, [
    const AuthState.loading(),
    AuthState.authenticated(tUser),
  ]);
});
```

### `addTearDown` の重要性

```dart
ProviderContainer makeContainer() {
  final c = ProviderContainer(overrides: [...]);
  addTearDown(c.dispose); // ← これを忘れるとメモリリーク
  return c;
}
```

`addTearDown` はテスト終了後に自動で呼ばれる。
`ProviderContainer` を `dispose` しないとリスナーやストリームがGCされない。

### StreamController でストリームを制御する

```dart
late StreamController<dynamic> authStreamController;

setUp(() {
  authStreamController = StreamController.broadcast();
  when(() => mockRepository.authStateChanges)
      .thenAnswer((_) => authStreamController.stream.cast());
});

tearDown(() => authStreamController.close());

test('ストリームが AppUser を流したとき authenticated になる', () async {
  final container = makeContainer();
  final states = <AuthState>[];
  container.listen(authStateNotifierProvider, (_, next) => states.add(next));

  // ストリームに値を流す（Firebase のサインインをシミュレート）
  authStreamController.add(tUser);
  await Future<void>.delayed(Duration.zero); // 非同期処理を待つ

  expect(states.last, AuthState.authenticated(tUser));
});
```

**なぜ `Stream.value(null)` を使わないのか：**

```dart
// ❌ 避けるべき: 即座に emit して Notifier の状態を上書きしてしまう
when(() => mockRepository.authStateChanges)
    .thenAnswer((_) => Stream.value(null));

// ✅ 推奨: StreamController でタイミングを制御する
authStreamController = StreamController.broadcast();
// テストの好きなタイミングで emit できる
authStreamController.add(tUser);
```

---

## 8. Layer 4: Widget テスト

### Widget テストとは

実際のデバイスなしで UI の振る舞いをテストする。
「ボタンをタップしたらこのテキストが表示される」という検証が可能。

### FakeAuthStateNotifier パターン

```dart
// Widget テスト専用の Fake Notifier
class FakeAuthStateNotifier extends AuthStateNotifier {
  FakeAuthStateNotifier(this._initialState);
  final AuthState _initialState;

  // 固定の初期状態を返す（Firebase なし）
  @override
  AuthState build() => _initialState;

  // Firebase を呼ばないようにオーバーライド
  @override
  Future<void> signInWithEmail(String email, String password) async {}

  @override
  Future<void> signInWithGoogle() async {}
}

// ProviderScope でラップしてテスト用 Notifier を注入
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

### 代表的な finder と matcher

```dart
// Widget を見つける
find.text('ログイン')                        // テキストで検索
find.byType(FilledButton)                   // Widget の型で検索
find.widgetWithText(TextFormField, 'パスワード') // 特定テキストを持つ Widget
find.byIcon(Icons.logout)                   // アイコンで検索

// 見つけた結果を検証
expect(find.text('ログイン'), findsOneWidget);     // 1個だけある
expect(find.text('ログイン'), findsWidgets);       // 1個以上ある
expect(find.text('エラー'), findsNothing);         // 存在しない
expect(find.byType(SnackBar), findsOneWidget);   // SnackBar が1個ある
```

### Widget を操作する

```dart
// テキストを入力
await tester.enterText(
  find.widgetWithText(TextFormField, 'メールアドレス'),
  'test@example.com',
);

// ボタンをタップ
await tester.tap(find.widgetWithText(FilledButton, 'ログイン'));

// UIを更新（タップ後に必要）
await tester.pump();         // 1フレーム進める
await tester.pumpAndSettle(); // アニメーションが終わるまで進める
```

### `pump()` vs `pumpAndSettle()`

| メソッド | 動作 | 使う場面 |
|---|---|---|
| `pump()` | 1フレーム進める | バリデーション・同期処理 |
| `pump(Duration)` | 指定時間分フレームを進める | アニメーション途中 |
| `pumpAndSettle()` | アニメーションが終わるまで | SnackBar の完全な表示など |

### ref.listen のテスト（状態変化を起こす）

```dart
// ref.listen は「変化」を検知する
// 初期状態が error でも変化がないと SnackBar は表示されない
// → 別の状態から error に遷移させる必要がある

test('error 状態のとき SnackBar が表示される', (tester) async {
  await tester.pumpWidget(
    buildLoginScreen(const AuthState.unauthenticated()),
  );

  // ProviderContainer を取得して状態を直接変更
  final container = ProviderScope.containerOf(
    tester.element(find.byType(LoginScreen)),
  );

  // unauthenticated → error に「変化」させる
  container.read(authStateNotifierProvider.notifier)
      // ignore: invalid_use_of_protected_member
      .state = const AuthState.error(
    Failure.auth(message: 'パスワードが間違っています', code: 'wrong-password'),
  );
  await tester.pump(); // UIを更新

  expect(find.byType(SnackBar), findsOneWidget);
  expect(find.text('パスワードが間違っています'), findsOneWidget);
});
```

---

## 9. テストを読むときに注目するポイント

### ① テスト名が仕様書になっているか

```dart
// ❌ 悪いテスト名: 何をテストするか分からない
test('テスト1', ...);
test('signIn', ...);

// ✅ 良いテスト名: 「〜のとき〜する」の形
test('パスワードが間違っているとき AuthFailure を返す', ...);
test('loading 状態のとき ボタンが無効になる', ...);
test('error 状態のとき SnackBar が表示される', ...);
```

### ② 成功ケースと失敗ケースの両方があるか

```
signInWithEmail のテスト例:
  ✅ 成功: Right(AppUser) を返す
  ✅ 失敗: パスワード誤り → AuthFailure を返す
  ✅ 失敗: ユーザー未存在 → AuthFailure を返す
  ✅ 失敗: ネットワークエラー → NetworkFailure を返す
```

### ③ `group` でテスト対象ごとに整理されているか

```dart
group('LoginScreen', () {
  group('バリデーション', () {
    test('空のまま送信するとエラーメッセージが表示される', ...);
    test('不正なメールアドレスでエラーメッセージが表示される', ...);
    test('パスワードが6文字未満のときエラーメッセージが表示される', ...);
  });

  group('状態別表示', () {
    test('loading 状態のとき ボタンが無効になる', ...);
    test('error 状態のとき SnackBar が表示される', ...);
  });
});
```

### ④ `setUp` / `tearDown` が正しく使われているか

```dart
setUp(() {
  // テスト開始前に呼ばれる: Mock の初期化など
  mockRepository = MockAuthRepository();
});

tearDown(() {
  // テスト終了後に呼ばれる: リソースの解放
  authStreamController.close();
});
```

---

## 10. テストファイル一覧と役割

```
test/
├── helpers/
│   ├── test_helpers.dart                    # 共通: MockAuthRepository・tUser
│   └── fakes/
│       └── fake_auth_remote_data_source.dart # Layer 2用: Firebase なし DataSource
│
└── features/auth/
    ├── domain/usecases/                     # Layer 1: UseCase テスト
    │   ├── sign_in_with_email_test.dart     #   - 成功・失敗・ネットワークエラー
    │   ├── sign_in_with_google_test.dart    #   - 成功・失敗
    │   ├── sign_up_with_email_test.dart     #   - 成功・失敗
    │   ├── sign_out_test.dart               #   - 成功・失敗
    │   └── get_current_user_test.dart       #   - ログイン中・未ログイン
    │
    ├── data/
    │   ├── models/
    │   │   └── user_model_test.dart         # UserModel.toEntity() のテスト
    │   └── repositories/
    │       └── auth_repository_impl_test.dart # Layer 2: FakeDataSource を使用
    │
    └── presentation/
        ├── providers/
        │   └── auth_state_notifier_test.dart # Layer 3: ProviderContainer を使用
        └── screens/
            ├── login_screen_test.dart        # Layer 4: Widget テスト
            ├── register_screen_test.dart     # Layer 4: Widget テスト
            └── home_screen_test.dart         # Layer 4: Widget テスト
```

---

## 11. つまずきポイントと解決策

### 問題: `state` が protected でアクセスできない

```dart
// テストで Notifier の state を直接書き換えたい
container.read(authStateNotifierProvider.notifier).state = ...;
// ↑ Warning: invalid_use_of_protected_member
```

**解決：** コメントで警告を抑制する（テスト専用の正当な使い方）

```dart
container
    .read(authStateNotifierProvider.notifier)
    // ignore: invalid_use_of_protected_member
    .state = const AuthState.error(...);
```

### 問題: ref.listen のテストで SnackBar が出ない

`ref.listen` は状態の「変化」を検知するため、初期状態のままでは発火しない。

```dart
// ❌: 初期状態が error でも変化がないので SnackBar は出ない
await tester.pumpWidget(buildLoginScreen(const AuthState.error(...)));

// ✅: 別の状態から error に「変化」させる
container.read(...notifier).state = const AuthState.unauthenticated();
await tester.pump();
container.read(...notifier).state = const AuthState.error(...);
await tester.pump();
```

### 問題: StreamController 使用後に `tearDown` を忘れる

```dart
// ❌: close しないとリソースリーク
setUp(() {
  authStreamController = StreamController.broadcast();
});
// tearDown がない → テスト間でストリームが混在

// ✅: 必ず tearDown で close
tearDown(() => authStreamController.close());
```

### 問題: `pumpAndSettle()` でタイムアウト

アニメーションが終わらない Widget がある場合、`pumpAndSettle()` がタイムアウトする。

```dart
// ❌ タイムアウトする可能性
await tester.pumpAndSettle();

// ✅ pump() で明示的にフレームを進める
await tester.pump();
await tester.pump(const Duration(seconds: 1)); // 必要なら時間指定
```

---

## 12. 完了チェックリスト

- [ ] `flutter test` で全テストが通過する
- [ ] `flutter test --coverage` でカバレッジ 70% 以上
- [ ] UseCase の Unit テスト（成功・失敗ケース）がある
- [ ] RepositoryImpl のテストが FakeDataSource で通る
- [ ] AuthStateNotifier の状態遷移テストがある
- [ ] 各 Screen の Widget テストがある
- [ ] テスト名が「〜のとき〜する」の形で仕様書として読める
