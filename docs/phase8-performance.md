# Phase 8: パフォーマンス最適化 — DevTools・select・RepaintBoundary

## 概要

動くコードと**良いコード**は違う。
不要なリビルドが積み重なるとフレームが落ち（ジャンクフレーム）、
ユーザーには「カクつく UI」として見える。
この Phase では Flutter DevTools で問題を可視化し、
`select` と `RepaintBoundary` で修正する方法を学ぶ。

---

## 1. なぜパフォーマンスが重要か

### 60fps の壁

```
スマートフォンの画面は 1秒間に 60回 更新される（60fps）
1フレームの予算: 1000ms ÷ 60 = 約 16ms

もし 1フレームの処理が 16ms を超えると…
  → フレームがスキップ（ジャンクフレーム）
  → ユーザーに「カクつき」として知覚される
```

### 不要なリビルドが起きる典型パターン

```dart
// ❌ 問題: AuthState 全体を監視
final authState = ref.watch(authStateNotifierProvider);
final user = authState.maybeWhen(
  authenticated: (user) => user,
  orElse: () => null,
);
```

このコードの問題点：

```
ユーザーがサインアウトボタンをタップ
  ↓
AuthState.loading() に遷移
  ↓
authStateNotifierProvider の値が変わった → HomeScreen 全体がリビルド
  ↓
AuthState.unauthenticated() に遷移
  ↓
authStateNotifierProvider の値が変わった → HomeScreen 全体がリビルド

（GoRouter が /login にリダイレクトするのに、HomeScreen が2回余計にリビルドされている）
```

---

## 2. Flutter DevTools の使い方

### 起動方法

```bash
# プロファイルモードで起動（リリースに近い速度でプロファイリング）
flutter run --profile

# または VS Code / Android Studio の "Run" から DevTools を開く
```

> **profile vs debug vs release:**
>
> | モード | 用途 | 速度 |
> |---|---|---|
> | `debug` | 開発中（Hot reload 有効） | 遅い（アサーション有効） |
> | `profile` | パフォーマンス計測 | 本番に近い |
> | `release` | 本番配布 | 最速 |
>
> パフォーマンス計測は必ず `--profile` で行う。`debug` モードは遅く、数字が正確でない。

### Widget Inspector — リビルドを可視化

```
DevTools を開く
  → Widget Inspector タブ
  → "Highlight Repaints" を ON
  → 画面上で再描画された Widget が赤く点滅する
```

点滅が多い Widget ほど無駄なリビルドが起きている。

### Performance タブ — フレームタイムを確認

```
DevTools → Performance タブ
  → 上段: フレームグラフ（棒が 16ms を超えると赤くなる）
  → 下段: どの処理に何 ms かかったか
```

赤いフレームをクリック → 何の処理が重かったか詳細が見える。

### Memory タブ — メモリリークを確認

```
DevTools → Memory タブ
  → "Take Snapshot" でヒープのスナップショットを撮る
  → 操作前後でスナップショットを比較
  → 増え続けているオブジェクトがあればリーク候補
```

---

## 3. `select` で監視範囲を絞る

### 原理

```
ref.watch(provider) は provider の値が変わるたびにリビルドを起こす

select を使うと…
  ref.watch(provider.select((s) => s.someField)) は
  someField の値が変わったときだけリビルドを起こす
```

### Before / After（HomeScreen の例）

```dart
// ❌ Before: AuthState 全体を監視
// loading/error への遷移でも HomeScreen 全体がリビルドされる
final authState = ref.watch(authStateNotifierProvider);
final user = authState.maybeWhen(
  authenticated: (user) => user,
  orElse: () => null,
);
```

```dart
// ✅ After: AppUser? だけを監視
// user の中身が変わったときだけリビルド
// loading/error 状態への遷移はリビルドを起こさない
final user = ref.watch(
  authStateNotifierProvider.select(
    (s) => s.maybeWhen(
      authenticated: (user) => user,
      orElse: () => null,
    ),
  ),
);
```

### select が差分を検知する仕組み

```
1. ref.watch(provider.select(fn)) が評価される
2. provider の値が変わる
3. Flutter が fn(旧値) と fn(新値) を == で比較する
4. 同じ → リビルドしない
   違う → リビルドする

例:
  AuthState.authenticated(user) → AuthState.loading()
  select((s) => s.maybeWhen(authenticated: ..., orElse: () => null))
  旧: AppUser(...)  新: null  → 違う → リビルド ✓

  AuthState.loading() → AuthState.unauthenticated()
  旧: null  新: null  → 同じ → リビルドしない ✓ （GoRouter がリダイレクトするだけ）
```

### isLoading のパターン（LoginScreen・RegisterScreen）

```dart
// すでに Phase 5 から select を使っていた
final isLoading = ref.watch(
  authStateNotifierProvider.select(
    (s) => s.maybeWhen(loading: () => true, orElse: () => false),
  ),
);
// bool 値だけを監視 → true/false が切り替わるときだけリビルド
```

---

## 4. `RepaintBoundary` でリペイント範囲を限定する

### リビルドとリペイントの違い

| | リビルド | リペイント |
|---|---|---|
| 意味 | `build()` メソッドが再実行される | 画面への描画命令が再実行される |
| 発生タイミング | `setState` / `ref.watch` の値変化 | リビルド後、または画像ロード完了時 |
| コスト | ウィジェットツリーの再構築 | GPU へのピクセル描画 |

リビルドを抑えれば CPU コストを削減できる。
リペイントを抑えれば GPU コストを削減できる。

### `RepaintBoundary` の使い方

```dart
// ✅ 独自にリペイントするサブツリーを囲む
RepaintBoundary(
  child: _UserAvatar(user: user), // ネットワーク画像ロード時にリペイント
),
```

`RepaintBoundary` を挿入すると Flutter はその内側と外側を**別々のレイヤー**として扱う。
一方の変化がもう一方のリペイントを引き起こさなくなる。

### いつ使うか

```
✅ 使うべき場面:
  - ネットワーク画像（NetworkImage）を表示する Widget
  - アニメーションが動いているサブツリー
  - 頻繁に更新されるカウンターなど

❌ 使いすぎに注意:
  - RepaintBoundary 自体もコスト（レイヤーの生成・合成）がある
  - 小さな静的 Widget に付けても意味がない
  - DevTools で "Highlight Repaints" を使って必要な箇所だけに絞る
```

---

## 5. Widget の抽出と `const` の活用

### 大きな `build` を小さく分割する

```dart
// ❌ Before: build が肥大化している
Widget build(BuildContext context, WidgetRef ref) {
  return Scaffold(
    body: Column(
      children: [
        CircleAvatar(
          radius: 40,
          // ... 複雑なロジック ...
        ),
        // ... さらに続く ...
      ],
    ),
  );
}

// ✅ After: 責務ごとに Widget に分割
Widget build(BuildContext context, WidgetRef ref) {
  return Scaffold(
    body: Column(
      children: [
        _UserAvatar(user: user), // ← 独立した Widget
        _InfoTile(label: '...', value: '...'),
      ],
    ),
  );
}
```

**分割のメリット：**
- `build` が読みやすくなる
- `RepaintBoundary` と組み合わせやすくなる
- 将来的に独立してテストできる

### `const` Widget が効く場所

```dart
// ✅ const がつけられる = Flutter がリビルド時に再生成しない
const SizedBox(height: 24)
const Text('ホーム')
const Icon(Icons.logout)
const EdgeInsets.all(24)
const TextStyle(fontSize: 32)

// ❌ const がつけられない = 実行時に値が決まるもの
Text(user.email)         // user が変数
TextStyle(color: color)  // color が変数
```

**`const` の効果：**

```
リビルド発生
  ↓
Flutter がウィジェットツリーを差分比較
  ↓
const Widget は「同じオブジェクト」として扱われる（identical）
  → 比較を短絡させてスキップ
const ではない Widget は毎回新しいオブジェクトが生成される
  → 比較が必要
```

---

## 6. `select` で監視するフィールドを最小化する

### 複数の値を個別に select する

```dart
// ❌ 1つの watch で複数の値を取得
// user の何か（email・displayName など）が変わると全部リビルド
final user = ref.watch(
  authStateNotifierProvider.select((s) => s.maybeWhen(...)),
);
final email = user?.email ?? '-';
final displayName = user?.displayName ?? '未設定';
```

```dart
// ✅ 必要な値だけを個別に select（さらに絞りたい場合）
// email だけ表示する Widget なら email だけ監視する
final email = ref.watch(
  authStateNotifierProvider.select(
    (s) => s.maybeWhen(
      authenticated: (u) => u.email,
      orElse: () => '-',
    ),
  ),
);
```

> **いつ個別 select が有効か：**
>
> ユーザー情報の一部だけを表示する Widget が多数ある場合に有効。
> 今回の HomeScreen のように画面全体で user を使う場合は
> `AppUser?` 単位の select で十分。

---

## 7. メモリリークの防止

### 本プロジェクトで発生しうるリーク

```dart
// ❌ ProviderContainer を dispose しないと StreamSubscription が残り続ける
final container = ProviderContainer();
// container.dispose() を呼ばないとリーク
```

```dart
// ✅ addTearDown で確実に解放
final container = ProviderContainer();
addTearDown(container.dispose); // テスト終了時に自動解放
```

```dart
// ✅ HookConsumerWidget の useTextEditingController は自動 dispose
// → StatefulWidget の手動 dispose が不要でリーク防止になる
final emailController = useTextEditingController();
// dispose を忘れる心配がない
```

### DevTools の Memory タブでの確認方法

```
1. アプリを起動
2. DevTools → Memory タブ
3. "Take Snapshot" を押す（スナップショット A）
4. 問題の操作を繰り返す（例: ログイン → ログアウト を10回）
5. "Take Snapshot" を押す（スナップショット B）
6. A と B を比較して増え続けているクラスを探す
   → TextEditingController が増えていればリーク
   → ProviderContainer が増えていればリーク
```

---

## 8. 実施した最適化のまとめ

### HomeScreen の変更点

| 最適化 | Before | After | 効果 |
|---|---|---|---|
| `select` | `ref.watch(全体)` | `ref.watch(select(user))` | loading/error 遷移でのリビルドを排除 |
| Widget 分割 | build 内に直書き | `_UserAvatar` を抽出 | 責務の分離・RepaintBoundary と組み合わせやすい |
| `RepaintBoundary` | なし | アバター・情報欄を分離 | 独立したリペイント境界を設ける |

### LoginScreen / RegisterScreen（Phase 5 から対応済み）

| 最適化 | コード | 効果 |
|---|---|---|
| `select` で isLoading を絞る | `.select((s) => s.maybeWhen(loading: ...))` | 全 AuthState 変化でなく loading 切り替え時のみリビルド |
| `const` Widget | `const SizedBox` `const Text` など | リビルド時の差分比較コストを削減 |

---

## 9. つまずきポイントと解決策

### 問題: `select` を使ったのにリビルドが減らない

`select` が返す値が毎回違うオブジェクトになっている可能性がある。

```dart
// ❌ 毎回新しい List を返す → 常にリビルドされる
ref.watch(provider.select((s) => [s.a, s.b])); // [] は毎回新しいオブジェクト

// ✅ プリミティブ型 or == をオーバーライド済みの型を返す
ref.watch(provider.select((s) => s.a)); // String, bool, int などは == が効く
```

Freezed クラス（AppUser など）は `==` が自動生成されるので select で正しく差分検知できる。

### 問題: `RepaintBoundary` を付けすぎてかえって遅くなる

```dart
// ❌ 全ての Widget に RepaintBoundary を付けるのは逆効果
// レイヤーの生成・合成コストが積み重なる

// ✅ DevTools の "Highlight Repaints" で実際に赤くなる箇所だけに付ける
```

### 問題: `--profile` モードで Firebase が動かない

```bash
# Firebase は --profile でも動作する
# ただし google-services.json / GoogleService-Info.plist が必要
flutter run --profile
```

シミュレーター（iOS）でも `--profile` は使えるが、実機の方が正確な数値が得られる。

---

## 10. 完了チェックリスト

- [ ] `HomeScreen` が `select` で `AppUser?` だけを監視している
- [ ] `_UserAvatar` が独立した Widget に抽出されている
- [ ] `RepaintBoundary` がアバターと情報タイル群に設置されている
- [ ] DevTools の Widget Inspector で不要なリビルドがないことを確認
- [ ] `flutter test` が全通過している
- [ ] DevTools の Memory タブでリークがないことを確認
