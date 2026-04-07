# Phase 9 - メモリリーク対策

## このフェーズで学ぶこと

Flutter アプリでよく発生するメモリリークのパターンを、このプロジェクトのコードに即して理解する。「なぜリークするか」「どう検出するか」「どう修正するか」の3点セットで習得する。

---

## メモリリークとは

Widget やオブジェクトが画面から消えた後も、GC（ガベージコレクタ）に回収されずメモリに残り続ける現象。

```
正常:
  Widget が破棄 → 参照がなくなる → GC が回収 → メモリ解放

リーク:
  Widget が破棄 → どこかが参照を持ち続ける → GC が回収できない → メモリが増え続ける
```

長時間使うアプリでは OOM（Out of Memory）クラッシュや動作の重さに直結する。

---

## このプロジェクトで発生しやすいパターン

### パターン1: StreamSubscription の未キャンセル

**何が起きるか**

Firebase の `authStateChanges()` などのストリームを listen したまま、Widget/Notifier が破棄されると、ストリームのコールバックが破棄済みオブジェクトへの参照を持ち続ける。

**NG コード（意図的なリーク例）**

```dart
// auth_state_notifier.dart に似た構造
class LeakyAuthNotifier extends StateNotifier<AuthState> {
  LeakyAuthNotifier(this._authRepository) : super(const AuthState.initial()) {
    // キャンセルしないと、Notifier が破棄されてもコールバックが残る
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        state = AuthState.authenticated(AppUser(id: user.uid, email: user.email!));
      } else {
        state = const AuthState.unauthenticated();
      }
    });
  }

  final AuthRepository _authRepository;
  // dispose() の override がない → subscription がキャンセルされない
}
```

**OK コード（現在のプロジェクトの実装）**

`auth_providers.dart` では Riverpod の `ref.onDispose()` で確実にキャンセルしている:

```dart
// lib/features/auth/presentation/providers/auth_providers.dart
final authStateStreamProvider = StreamProvider<AppUser?>((ref) {
  // Riverpod が Provider の破棄時に Stream を自動的にクローズする
  return ref.watch(authRepositoryProvider).authStateChanges();
});
```

```dart
// StateNotifier を使う場合は onDispose で明示的にキャンセル
class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier(this._ref) : super(const AuthState.initial()) {
    final subscription = FirebaseAuth.instance
        .authStateChanges()
        .listen(_onAuthStateChanged);

    _ref.onDispose(subscription.cancel); // ← これが必須
  }
}
```

**なぜ Riverpod は安全か**

Riverpod の `StreamProvider` はフレームワーク側で subscription のライフサイクルを管理する。Provider が誰にも watch されなくなると自動的にキャンセルされる。`ref.onDispose()` は手動 subscription を持つ場合の追加の安全網。

---

### パターン2: TextEditingController / AnimationController の未 dispose

**何が起きるか**

`TextEditingController` は内部でリスナーを持つ。`StatefulWidget` で作成して `dispose()` し忘れると、Widget ツリーから外れてもリスナーが残る。Flutter はデバッグモードでこのリークを警告する。

**NG コード**

```dart
class _LoginScreenState extends State<LoginScreen> {
  // NG: dispose() を書き忘れた場合にリーク
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return TextField(controller: _emailController);
  }

  // @override void dispose() { ... } がない → リーク
}
```

**OK コード（現在のプロジェクトの実装）**

`login_screen.dart` と `register_screen.dart` では `flutter_hooks` の `useTextEditingController()` を使用。hooks がライフサイクルを自動管理するため、dispose の書き忘れが原則発生しない:

```dart
// lib/features/auth/presentation/screens/login_screen.dart
class LoginScreen extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // HookConsumerWidget のスコープを外れると hooks が自動 dispose する
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();

    return TextField(controller: emailController);
  }
}
```

**StatefulWidget で正しく書く場合**

```dart
class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _emailController;
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _animController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
  }

  @override
  void dispose() {
    _emailController.dispose();   // 必須
    _animController.dispose();    // 必須
    super.dispose();
  }
}
```

---

### パターン3: build() 外での ref.listen()

**何が起きるか**

`ref.listen()` を `build()` の外（`initState()` 相当の場所など）で呼ぶと、Widget が再構築されるたびにリスナーが追加され、古いリスナーが残り続ける。

**NG コード**

```dart
class LeakyWidget extends ConsumerStatefulWidget { ... }

class _LeakyWidgetState extends ConsumerState<LeakyWidget> {
  @override
  void initState() {
    super.initState();
    // NG: initState の中で ref.listen() → dispose されない
    ref.listen(authNotifierProvider, (prev, next) {
      // ここに処理
    });
  }
}
```

**OK コード（現在のプロジェクトの実装）**

`login_screen.dart` では `build()` 内で `ref.listen()` を呼んでいる。Riverpod がウィジェットのライフサイクルに合わせて自動的に登録・解除を行う:

```dart
// lib/features/auth/presentation/screens/login_screen.dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  // OK: build() 内の ref.listen() は Riverpod が管理
  ref.listen(authNotifierProvider, (previous, next) {
    next.whenOrNull(
      error: (message) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message))),
    );
  });

  return Scaffold(...);
}
```

---

### パターン4: BuildContext の非同期処理後の使用

**何が起きるか**

`async` 処理の完了後に Widget が破棄されていても `context` を使おうとすると、破棄済みの context への参照でクラッシュや予期しない動作が起きる。

**NG コード**

```dart
Future<void> _signIn() async {
  await ref.read(authNotifierProvider.notifier).signIn(email, password);
  // NG: await 後に Widget が破棄されている可能性がある
  Navigator.of(context).pushNamed('/home'); // context が無効かもしれない
}
```

**OK コード（現在のプロジェクトの実装）**

GoRouter による宣言的ナビゲーションを使うことで、`context` を async 処理後に使わない設計になっている:

```dart
// router/app_router.dart で auth 状態を監視して自動リダイレクト
redirect: (context, state) {
  final isAuthenticated = ref.read(authStateStreamProvider).value != null;
  if (isAuthenticated) return '/home';
  return null;
},
```

直接 `context` を async 後に使う必要がある場面では `mounted` チェックを行う:

```dart
Future<void> _signIn() async {
  await someAsyncOperation();
  if (!mounted) return; // Widget が破棄されていたら処理中断
  ScaffoldMessenger.of(context).showSnackBar(...);
}
```

---

## Flutter DevTools でリークを検出する

### セットアップ

```bash
# デバッグモードで起動
flutter run --debug

# ターミナルに表示される URL か、以下のコマンドでブラウザを開く
# flutter pub global activate devtools（初回のみ）
# flutter pub global run devtools
```

### Memory タブの使い方

```
DevTools > Memory タブ

1. [Track Allocations] ボタンを ON にする
2. アプリでリークしそうな操作を繰り返す（画面遷移など）
3. [GC] ボタンでガベージコレクションを強制実行
4. [Take Heap Snapshot] でヒープの状態を記録
5. スナップショット一覧で操作の前後を比較する
```

### リークが疑われるサイン

- 同じ操作を繰り返すたびにヒープサイズが増え続ける
- GC 後もヒープが減らない
- `TextEditingController`、`StreamSubscription`、`AnimationController` などのカウントが増え続ける

### Flutter Inspector でウィジェットツリーを確認

```
DevTools > Flutter Inspector

- ウィジェットが破棄されているか確認できる
- 予期せず残っているウィジェットを発見できる
```

---

## プロジェクトで実際に試す手順

### Step 1: 現状（安全な実装）を確認する

```bash
flutter run --debug
```

DevTools の Memory タブでヒープを観察しながら、ログイン → ホーム → ログアウト を数回繰り返す。ヒープが安定していることを確認。

### Step 2: 意図的にリークするコードを書く（別ブランチで）

```bash
git checkout -b experiment/memory-leak
```

`login_screen.dart` の `useTextEditingController()` を `TextEditingController()` に変え、dispose を書かない版に変更してみる。

### Step 3: DevTools で比較する

リークありの状態で同じ操作を繰り返し、ヒープの変化を観察する。

### Step 4: 修正して元に戻す

```bash
git checkout main
```

---

## まとめ：このプロジェクトで採用しているリーク対策

| リスク | 対策 | 採用箇所 |
|---|---|---|
| StreamSubscription の未キャンセル | `StreamProvider` で自動管理、手動時は `ref.onDispose()` | `auth_providers.dart` |
| TextEditingController の未 dispose | `useTextEditingController()`（flutter_hooks） | `login_screen.dart`, `register_screen.dart` |
| ref.listen() の多重登録 | `build()` 内でのみ呼ぶ | `login_screen.dart` |
| 非同期後の context 使用 | GoRouter による宣言的ナビゲーション、`mounted` チェック | `app_router.dart` |

**根本的な方針**: リソースのライフサイクルをフレームワーク（Riverpod・flutter_hooks・GoRouter）に委ねることで、手動管理のミスによるリークを構造的に防いでいる。

---

## 参考

- [Flutter DevTools Memory](https://docs.flutter.dev/tools/devtools/memory)
- [Riverpod: State Lifecycle](https://riverpod.dev/docs/concepts/provider_lifecycle)
- [flutter_hooks: useEffect](https://pub.dev/packages/flutter_hooks#useeffect)
