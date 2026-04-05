# Phase 1: Foundation — Firebase 初期化 + アーキテクチャ基盤

## 概要

実装の「土台」を整えるフェーズ。パッケージの追加・Firebase の接続・エラー型の定義を行う。
後続の全フェーズはここで作った基盤の上に乗る。

---

## 1. パッケージ設計の考え方

### なぜこの構成か

```yaml
dependencies:
  firebase_core: ^3.6.0       # Firebase 初期化（必須）
  firebase_auth: ^5.3.1       # 認証 SDK
  google_sign_in: ^6.2.1      # Google 認証

  flutter_riverpod: ^2.5.1    # 状態管理・DI
  riverpod_annotation: ^2.3.5 # @riverpod アノテーション（コード生成）

  go_router: ^14.3.0          # 宣言的ルーティング

  freezed_annotation: ^2.4.4  # イミュータブルクラス生成
  fpdart: ^1.1.0              # Either 型（エラー処理）

dev_dependencies:
  build_runner: ^2.4.12       # コード生成の実行エンジン
  freezed: ^2.5.7             # Freezed コード生成
  riverpod_generator: ^2.4.3  # Riverpod Provider コード生成
  mocktail: ^1.0.4            # テスト用モック
```

**なぜ `bloc` ではなく `flutter_riverpod` か？**

| | BLoC | Riverpod |
|---|---|---|
| テスト | Event/State ファイルが分離 → 冗長 | `ProviderContainer` で Widget なしテスト可 |
| DI | GetIt 等が必要 | Provider 自体が DI グラフ |
| 学習コスト | Event/State/Bloc の3ファイル | Notifier 1ファイル |

**なぜ `fpdart` の `Either` か？**

```dart
// ❌ 例外方式: エラー処理を書き忘れても型エラーにならない
Future<AppUser> signIn(String email, String password) async {
  // 例外が飛ぶかもしれないが、呼び出し元は知らない
}

// ✅ Either 方式: 戻り値の型を見るだけでエラー処理が必要とわかる
Future<Either<Failure, AppUser>> signIn(String email, String password) async {
  // Left = 失敗, Right = 成功。どちらかを必ず処理しないとコンパイルエラー
}
```

---

## 2. FlutterFire CLI によるセットアップ

### なぜ FlutterFire CLI を使うか

手動で各プラットフォームのファイルを編集する代わりに、CLI が全て自動生成する。

```bash
# CLI をインストール（1回だけ）
dart pub global activate flutterfire_cli

# Firebase プロジェクトと接続して設定ファイルを生成
flutterfire configure --project=YOUR_PROJECT_ID
```

**生成されるファイル：**

```
lib/firebase_options.dart       # 全プラットフォームの設定を一元管理
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
macos/Runner/GoogleService-Info.plist
```

### セキュリティ上の扱い

| ファイル | Git にコミットするか | 理由 |
|---|---|---|
| `firebase_options.dart` | ✅ する | Firebase API キーはクライアント公開前提の設計 |
| `google-services.json` | ❌ しない（.gitignore） | firebase_options.dart で代替可能 |
| `GoogleService-Info.plist` | ❌ しない（.gitignore） | 同上 |

**Firebase API キーが漏れても大丈夫な理由：**
Firebase のセキュリティはキーの秘密性ではなく **Firebase Security Rules** と **App Check** で守られている。
キーはプロジェクトの識別子に過ぎず、それ単体では何もできない。

---

## 3. main.dart — 初期化の順序

```dart
void main() async {
  // ① Flutter エンジンの初期化（非同期処理の前に必須）
  WidgetsFlutterBinding.ensureInitialized();

  // ② Firebase の初期化（全 Firebase サービスより先に呼ぶ）
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ③ ProviderScope でアプリをラップ（Riverpod の最上位スコープ）
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}
```

**なぜ `WidgetsFlutterBinding.ensureInitialized()` が必要か？**

`runApp()` の前に非同期処理（`await`）を呼ぶ場合、Flutter エンジンが初期化される前に
プラットフォームチャンネル（ネイティブ連携）を使おうとするとクラッシュする。
`ensureInitialized()` を呼ぶことで「Flutter エンジン準備完了」を保証する。

**なぜ `ProviderScope` が最上位に必要か？**

Riverpod のすべての Provider は `ProviderScope` の中にのみ存在できる。
`ProviderScope` はアプリ全体の Provider ストアとして機能する。
`ProviderScope` の外から `ref.watch()` を呼ぶと実行時エラ���になる。

---

## 4. Failure Sealed class — エラー型の設計

### コード

```dart
// lib/core/error/failure.dart

@freezed
sealed class Failure with _$Failure {
  const factory Failure.auth({
    required String message,
    required String code,
  }) = AuthFailure;

  const factory Failure.network() = NetworkFailure;

  const factory Failure.unexpected() = UnexpectedFailure;
}
```

### なぜ `sealed class` か

```dart
// ❌ 抽象クラス方式: UI で switch しても全ケース網羅を強制できない
abstract class Failure {}
class AuthFailure extends Failure {}
class NetworkFailure extends Failure {}

// switch で書き忘れてもコンパイルエラーにならない
switch (failure) {
  case AuthFailure f: print(f.message);
  // NetworkFailure を忘れていてもコンパイル通る → バグ
}

// ✅ sealed class 方式: switch で全ケース網羅を強制
sealed class Failure { ... }

// 漏れがあるとコンパイルエラー
final message = switch (failure) {
  AuthFailure(:final message) => message,
  NetworkFailure() => 'ネットワークエラー',
  UnexpectedFailure() => '予期しないエラー',
  // ↑ 1つでも抜けると "The type 'Failure' is not exhaustively matched" エラー
};
```

### なぜ `core/error/` に置くか

`Failure` はアプリ全体で使う横断的な型。特定のフィーチャーに置くと、
他のフィーチャーが依存する際に循環依存が生まれる可能性がある。

---

## 5. analysis_options.yaml — Lint ルールの強化

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  errors:
    missing_required_param: error   # 必須パラメータの漏れを error に
    missing_return: error           # return 漏れを error に
  exclude:
    - '**/*.g.dart'                 # 生成ファイルは解析対象外
    - '**/*.freezed.dart'           # 同上

linter:
  rules:
    - always_use_package_imports    # 相対パス import 禁止
    - prefer_single_quotes          # シン��ルクォートに統一
    - avoid_print                   # print() を警告（ログは logger を使う）
```

**`always_use_package_imports` を有効にする理由：**

```dart
// ❌ 相対パス: ファイルを移動すると全 import が壊れる
import '../../../core/error/failure.dart';

// ✅ パッケージパス: ファイル位置に依存しない
import 'package:flutter_learn/core/error/failure.dart';
```

---

## 6. build_runner — コード生成の仕組み

```bash
# 全ファイルをスキャンしてコードを生成
dart run build_runner build --delete-conflicting-outputs
```

**何が生成されるか：**

| 元ファイル | 生成ファイル | 内容 |
|---|---|---|
| `failure.dart`（@freezed） | `failure.freezed.dart` | `==`, `hashCode`, `copyWith`, `when` など |
| `auth_providers.dart`（@riverpod） | `auth_providers.g.dart` | `xxxProvider` 変数の定義 |
| `auth_state_notifier.dart`（@riverpod + @freezed） | `auth_state_notifier.g.dart`, `auth_state_notifier.freezed.dart` | Provider + Sealed class実装 |

**なぜ手書きしないのか：**

`==` や `hashCode` を手書きすると、フィールドを追加したときに書き忘れが起きやすい。
Freezed に任せれば、フィールドを追加するだけで全メソッドが自動更新される。

---

## 7. つまずきポイントと解決策

### 問題: build_runner でエラーが出た

```
E riverpod_generator on lib/main.dart:
  31:22: This requires the 'dot-shorthands' language feature to be enabled.
```

**原因：** `main.dart` が Dart 3.10 の新構文（ドットショートハンド）を使っていたが、
`build_runner` に含まれる `analyzer` パッケージが古く Dart 3.9 までしか対応し���いなかった。

**解決：** `main.dart` を書き直して古い構文に統一した。

```dart
// ❌ Dart 3.10 のドットショートハンド（build_runner が解析できない）
colorScheme: .fromSeed(seedColor: Colors.deepPurple)
mainAxisAlignment: .center

// ✅ 明示的な書き方
colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)
mainAxisAlignment: MainAxisAlignment.center
```

---

## 8. 完了チェックリスト

- [ ] `flutter pub get` が成功する
- [ ] `firebase_options.dart` が生成されている
- [ ] `flutter run` でアプリが起動し Firebase エラーがない
- [ ] `failure.dart` の `.freezed.dart` が生成されている
- [ ] `flutter analyze` でエラーが出ない
- [ ] `flutter test` が通る

---

## 9. 次のフェーズへの接続

Phase 1 で作った `Failure` sealed class は
Phase 2 の Repository インターフェースで `Either<Failure, T>` として使われる。

```
Phase 1: Failure sealed class を定義
    ↓
Phase 2: Either<Failure, AppUser> を返す Repository を定義
    ↓
Phase 3: FirebaseAuthException を Failure に変換す��� RepositoryImpl を実装
    ↓
Phase 4: Failure を受け取った Notifier が AuthState.error に遷移
    ↓
Phase 5: UI が AuthState.error を watch して SnackBar 表示
```
