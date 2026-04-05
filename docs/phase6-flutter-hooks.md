# Phase 6: Flutter Hooks — HookConsumerWidget でボイラープレートを削減

## 概要

`ConsumerStatefulWidget` を `HookConsumerWidget` に置き換え、
`TextEditingController` のライフサイクル管理を Flutter Hooks に委ねる。
`initState` / `dispose` / `setState` を書く必要がなくなり、
コードの見通しが大幅に向上する。

---

## 1. パッケージ変更

### `flutter_riverpod` → `hooks_riverpod` + `flutter_hooks`

```yaml
# Before (Phase 5)
dependencies:
  flutter_riverpod: ^2.5.1

# After (Phase 6)
dependencies:
  hooks_riverpod: ^2.5.1   # flutter_riverpod + flutter_hooks を統合したパッケージ
  flutter_hooks: ^0.20.5   # Hook 本体（useState, useTextEditingController など）
```

**`hooks_riverpod` とは：**

```
flutter_riverpod  →  ConsumerWidget / ConsumerStatefulWidget / WidgetRef
flutter_hooks     →  HookWidget / useState / useTextEditingController など
hooks_riverpod    →  HookConsumerWidget（両方を統合）
                      ProviderScope など riverpod の機能もそのまま使える
```

`hooks_riverpod` は `flutter_riverpod` の上位互換なので、
`ConsumerWidget` や `ProviderScope` はそのまま動作する。
import を `flutter_riverpod` → `hooks_riverpod` に差し替えるだけでよい。

---

## 2. `HookConsumerWidget` への移行

### Before: `ConsumerStatefulWidget`（Phase 5 の実装）

```dart
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // ① フィールド宣言
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // ② 手動 dispose（書き忘れ → メモリリーク）
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ... build の中で ref.listen や ref.watch を使う
  }

  // ③ メソッド分離（_onSignIn などをクラスに定義）
  Future<void> _onSignIn() async { ... }
}
```

**問題点：**
- `_LoginScreenState` というクラスを余分に作らなければならない
- `dispose()` を書き忘れるとメモリリーク
- フォームのロジックが `build` と別メソッドに散らばる

### After: `HookConsumerWidget`（Phase 6 の実装）

```dart
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ① Hook でコントローラを取得（dispose は自動）
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final formKey = useState(GlobalKey<FormState>());

    // ② ref.listen / ref.watch はそのまま使える
    ref.listen<AuthState>(authStateNotifierProvider, (previous, next) { ... });
    final isLoading = ref.watch(...);

    // ③ ローカル関数として build 内に定義
    Future<void> onSignIn() async {
      if (!formKey.value.currentState!.validate()) return;
      await ref.read(authStateNotifierProvider.notifier)
          .signInWithEmail(emailController.text.trim(), passwordController.text);
    }

    return Scaffold( ... );
  }
}
```

**改善点：**
- `State` クラスが不要 → ファイルがフラットになる
- `dispose()` が不要 → Hook が自動で解放
- ロジックを `build` 内のローカル関数に書けるので凝集度が上がる

---

## 3. 主要 Hook の解説

### `useTextEditingController()`

```dart
// StatefulWidget の書き方
class _State extends State<MyWidget> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose(); // ← 忘れると MemoryLeak
    super.dispose();
  }
}

// Hook の書き方
class MyWidget extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final ctrl = useTextEditingController(); // initState + dispose が内包されている
    // ...
  }
}
```

`useTextEditingController` は Widget がツリーから外れるときに `dispose()` を自動で呼ぶ。
初期値を与えたい場合は `useTextEditingController(text: 'initial')` と書く。

### `useState<T>(T initialValue)`

```dart
// StatefulWidget の書き方
bool _isVisible = false;
// 変更するときは setState が必要
setState(() { _isVisible = !_isVisible; });

// Hook の書き方
final isVisible = useState(false);
// 変更するときは .value に代入するだけ（setState 不要）
isVisible.value = !isVisible.value;
```

`useState` は `ValueNotifier<T>` のラッパー。
`.value` に代入すると自動的にリビルドが起きる。

`GlobalKey<FormState>` を管理するときも `useState` を使う：

```dart
final formKey = useState(GlobalKey<FormState>());

// 使うときは .value を経由する
Form(
  key: formKey.value,
  child: ...,
)

// バリデーションも .value を経由
formKey.value.currentState!.validate();
```

### その他の代表的な Hook

| Hook | 対応する StatefulWidget の処理 |
|---|---|
| `useTextEditingController()` | `TextEditingController` の init + dispose |
| `useFocusNode()` | `FocusNode` の init + dispose |
| `useState<T>()` | `setState` + フィールド変数 |
| `useEffect(fn, [keys])` | `initState` / `didUpdateWidget` のような副作用 |
| `useAnimationController()` | `AnimationController` の init + dispose + vsync |
| `useMemoized(fn, [keys])` | `keys` が変わるまで同じインスタンスを返す |

---

## 4. Hook のルール

Flutter Hooks は React Hooks と同じルールに従う。

### ルール 1: `build` メソッドのトップレベルで呼ぶ

```dart
// ✅ OK: build の先頭で呼ぶ
Widget build(BuildContext context, WidgetRef ref) {
  final ctrl = useTextEditingController();
  final isVisible = useState(false);
  ...
}

// ❌ NG: if / for / ローカル関数の中で呼ぶ
Widget build(BuildContext context, WidgetRef ref) {
  if (someCondition) {
    final ctrl = useTextEditingController(); // 実行順が変わる → クラッシュ
  }
}
```

**なぜか：**

Hook は内部で「何番目に呼ばれたか」でステートを管理している。
条件分岐でスキップすると番号がずれ、前回と今回で異なるステートが紐付けられてしまう。

### ルール 2: `HookWidget` / `HookConsumerWidget` の中でしか呼べない

```dart
// ❌ NG: 普通の StatelessWidget では使えない
class MyWidget extends StatelessWidget {
  Widget build(BuildContext context) {
    final ctrl = useTextEditingController(); // 実行時エラー
  }
}

// ✅ OK: HookWidget か HookConsumerWidget を継承する
class MyWidget extends HookConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = useTextEditingController(); // OK
  }
}
```

---

## 5. テストへの影響

`HookConsumerWidget` は `ProviderScope` でラップするだけで普通にテストできる。
Phase 5 から変更不要。

```dart
// HookConsumerWidget でも同じテストコードが動く
Widget buildLoginScreen(AuthState initialState) {
  return ProviderScope(
    overrides: [
      authStateNotifierProvider.overrideWith(
        () => FakeAuthStateNotifier(initialState),
      ),
    ],
    child: const MaterialApp(home: LoginScreen()), // HookConsumerWidget
  );
}
```

`flutter_hooks` は内部的に `HookElement` という仕組みで動くが、
テスト用の `WidgetTester` はこれに対応しているため特別な設定は不要。

---

## 6. `ConsumerWidget` / `HookConsumerWidget` の使い分け

| 状況 | 使うクラス |
|---|---|
| ローカル状態が不要（表示専用） | `ConsumerWidget` |
| `TextEditingController` / `FocusNode` などが必要 | `HookConsumerWidget` |
| アニメーションが必要 | `HookConsumerWidget`（`useAnimationController`） |
| Riverpod を使わないがローカル状態が必要 | `HookWidget` |

**原則：** `ConsumerStatefulWidget` を使いたくなったら `HookConsumerWidget` を検討する。
ほとんどの場合は Hook の方がコードが短くなる。

---

## 7. つまずきポイントと解決策

### 問題: `useState` の値が `formKey.currentState` で null になる

```dart
// ❌ 誤り: useState の中身を直接渡している
final formKey = useState(GlobalKey<FormState>());
Form(key: formKey, ...) // formKey は ValueNotifier<GlobalKey> であり GlobalKey ではない
```

```dart
// ✅ 正解: .value を経由する
Form(key: formKey.value, ...)
formKey.value.currentState!.validate();
```

### 問題: `import 'package:flutter_riverpod/flutter_riverpod.dart'` のままでビルドエラー

`hooks_riverpod` に移行したら全ファイルの import を揃える。

```dart
// ❌ Before
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ✅ After
import 'package:hooks_riverpod/hooks_riverpod.dart';
```

`hooks_riverpod` は `flutter_riverpod` の全 API を再エクスポートしているので、
import を差し替えるだけで既存のコードは動く。

### 問題: Hook を条件分岐の中で呼んでしまう

```
Bad state: Hooks were called in a different order than expected.
```

このエラーが出たら Hook を `build` の先頭に移動する（ルール 1 参照）。

---

## 8. 完了チェックリスト

- [ ] `pubspec.yaml` が `hooks_riverpod` + `flutter_hooks` に更新されている
- [ ] 全ファイルの import が `hooks_riverpod` に変更されている
- [ ] `LoginScreen` が `HookConsumerWidget` に変換されている
- [ ] `RegisterScreen` が `HookConsumerWidget` に変換されている
- [ ] `dispose()` が削除されている（Hook が自動管理）
- [ ] 全 Widget テストが通過している
