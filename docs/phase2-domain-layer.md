# Phase 2: Domain 層 — Entity / Repository Interface / UseCase

## 概要

Clean Architecture の「核心」。**Firebase にも Flutter にも依存しない純粋な Dart コード**で構成される。
この層が正しく設計できているかどうかが、アーキテクチャの品質を決める。

---

## 1. Domain 層とは何か

```
┌─────────────────────────────────┐
│           Domain 層              │
│                                  │
│  import できるもの：              │
│    - dart:core, dart:async       │
│    - package:fpdart (Either)     │
│    - package:freezed_annotation  │
│                                  │
│  import できないもの：            │
│    - package:firebase_auth  ❌   │
│    - package:flutter        ❌   │
│    - package:flutter_riverpod ❌ │
└─────────────────────────────────┘
```

**なぜ Firebase を知らないのか：**

Domain 層が Firebase を直接知っていると、Firebase を別サービス（Supabase, 自前API）に
変えるときに Domain 層まで修正が必要になる。依存を断ち切ることで変更コストを最小化する。

---

## 2. Entity — AppUser

### コード

```dart
// lib/features/auth/domain/entities/app_user.dart

@freezed
class AppUser with _$AppUser {
  const factory AppUser({
    required String id,
    required String email,
    String? displayName,
    String? photoUrl,
  }) = _AppUser;
}
```

### なぜ Freezed を使うか

```dart
// ❌ 通常のクラス: == を手書きすると漏れが出やすい
class AppUser {
  final String id;
  final String email;

  // == を手書き → フィールドを追加したときに書き忘れる
  @override
  bool operator ==(Object other) =>
    other is AppUser && other.id == id; // email を忘れてもコンパイル通る！
}

// ✅ Freezed: 全フィールドを考慮した == が自動生成
@freezed
class AppUser with _$AppUser {
  const factory AppUser({
    required String id,
    required String email,
  }) = _AppUser;
  // == / hashCode / copyWith / toString が自動生成
  // フィールド追加時も自動で追従
}
```

**Freezed が生成するもの（確認方法：`app_user.freezed.dart` を開く）：**

| メソッド | 用途 |
|---|---|
| `==` / `hashCode` | テストの `expect(result, Right(tUser))` で使われる |
| `copyWith(email: 'new@mail.com')` | 特定フィールドだけ変えた新インスタンスを作る |
| `toString()` | デバッグ出力をわかりやすくする |

---

## 3. Repository Interface — AuthRepository

### コード

```dart
// lib/features/auth/domain/repositories/auth_repository.dart

abstract interface class AuthRepository {
  Stream<AppUser?> get authStateChanges;

  Future<Either<Failure, AppUser>> signInWithEmail({
    required String email,
    required String password,
  });

  Future<Either<Failure, AppUser>> signInWithGoogle();

  Future<Either<Failure, AppUser>> signUpWithEmail({
    required String email,
    required String password,
  });

  Future<Either<Failure, Unit>> signOut();

  Future<Either<Failure, AppUser>> getCurrentUser();
}
```

### `abstract interface class` vs `abstract class`

Dart 3.0 で導入された `interface` キーワードの違い：

```dart
// abstract class: 部分実装（shared state）を持てる
abstract class AuthRepository {
  final someSharedState = ...; // OK
  void someMethod() { ... }   // デフォルト実装 OK
}

// abstract interface class: 実装のみ。状態・デフォルト実装を持てない
abstract interface class AuthRepository {
  // フィールドや実装は書けない → 純粋な「契約」のみ
}
```

`interface` を使うことで「これは契約であり、実装ではない」という意図がより明確になる。

### なぜ `Either<Failure, T>` を返すか

```dart
// ❌ 例外方式
Future<AppUser> signInWithEmail(...) async {
  // FirebaseAuthException を投げる可能性があるが、
  // 呼び出し元の型シグネチャを見ても気づけない
}

// 呼び出し元（UseCase）
final user = await repository.signInWithEmail(...);
// → エラー処理を書かなくてもコンパイルエラーにならない

// ✅ Either 方式
Future<Either<Failure, AppUser>> signInWithEmail(...);

// 呼び出し元（UseCase）
final result = await repository.signInWithEmail(...);
result.fold(
  (failure) => ..., // Left: エラー処理（書かないと fold が呼べない）
  (user) => ...,    // Right: 成功処理
);
```

### `Stream<AppUser?>` はなぜ `Either` を返さないか

Stream は「継続的に値が流れる」もの。エラーは `onError` で別途処理する設計になっている。
認証状態の変化（ログイン/ログアウト）は継続監視する必要があるため、Stream を採用。

---

## 4. UseCase — SignInWithEmail

### コード

```dart
// lib/features/auth/domain/usecases/sign_in_with_email.dart

class SignInWithEmail {
  final AuthRepository _repository;
  const SignInWithEmail(this._repository);

  Future<Either<Failure, AppUser>> call({
    required String email,
    required String password,
  }) =>
      _repository.signInWithEmail(email: email, password: password);
}
```

### なぜ UseCase を作るか

**「なぜ Repository を直接呼ばないのか？」** はよく出る疑問。

```
Repository を直接 Presentation 層から呼ぶ問題点:

1. ビジネスロジックが散らばる
   複数の Repository を組み合わせる処理（例: ログイン後にユーザープロフィールも取得）を
   どこに書くか迷う → UseCase に集約することで場所が一意になる

2. テストの粒度が粗くなる
   Repository のテスト = 外部I/O のテスト
   UseCase のテスト = ビジネスルールのテスト
   →分離することで「今何をテストしているか」が明確になる

3. Presentation 層と Domain 層の結合が強くなる
   Repository のインターフェースを直接 Presentation が知ると、
   Repository の変更が Presentation に影響しやすい
```

### `call()` メソッドを使う理由

```dart
class SignInWithEmail {
  Future<Either<Failure, AppUser>> call({...}) => ...;
}

// call() があると関数のように呼び出せる
final useCase = SignInWithEmail(repository);
final result = await useCase(email: 'a@b.com', password: 'pass'); // useCase.call() と同等
```

### UseCase ファイル一覧と責務

| ファイル | メソッド | 入力 | 出力 |
|---|---|---|---|
| `sign_in_with_email.dart` | `call(email, password)` | メール・パスワード | `Either<Failure, AppUser>` |
| `sign_in_with_google.dart` | `call()` | なし | `Either<Failure, AppUser>` |
| `sign_up_with_email.dart` | `call(email, password)` | メール・パスワード | `Either<Failure, AppUser>` |
| `sign_out.dart` | `call()` | なし | `Either<Failure, Unit>` |
| `get_current_user.dart` | `call()` | なし | `Either<Failure, AppUser>` |

---

## 5. テスト戦略

### Domain 層テストの特徴

```dart
void main() {
  late MockAuthRepository mockRepository;
  late SignInWithEmail useCase;

  setUp(() {
    // Firebase もネットワークも不要。Mock だけ
    mockRepository = MockAuthRepository();
    useCase = SignInWithEmail(mockRepository);
  });

  test('成功時に AppUser を返す', () async {
    // Arrange: Mock の振る舞いを定義
    when(() => mockRepository.signInWithEmail(
      email: any(named: 'email'),
      password: any(named: 'password'),
    )).thenAnswer((_) async => const Right(tUser));

    // Act: UseCase を実行
    final result = await useCase(email: 'a@b.com', password: 'pass');

    // Assert: 期待する結果を検証
    expect(result, const Right(tUser));
    // Mock が正しい引数で呼ばれたことを確認
    verify(() => mockRepository.signInWithEmail(
      email: 'a@b.com',
      password: 'pass',
    )).called(1);
  });
}
```

**これが「速い」理由：**
- Firebase への HTTP 通信なし
- ネットワーク待ち時間なし
- セットアップのオーバーヘッドなし
- テスト1件が数ミリ秒で完了

### `MockAuthRepository` の作り方（mocktail）

```dart
// test/helpers/test_helpers.dart

// モッククラスの定義（コード生成不要）
class MockAuthRepository extends Mock implements AuthRepository {}

// テストデータ
const tUser = AppUser(
  id: 'test-uid-123',
  email: 'test@example.com',
  displayName: 'Test User',
);
```

**`mockito` ではなく `mocktail` を使う理由：**

| | mockito | mocktail |
|---|---|---|
| セットアップ | `@GenerateMocks` + build_runner が必要 | クラスを extends するだけ |
| null-safety | 対応が複雑 | 完全対応 |
| `any()` | `any()` の前に型が必要 | `any(named: 'xxx')` でシンプル |

---

## 6. つまずきポイントと解決策

### 問題: `Either` の使い方がわからない

```dart
// Right = 成功値を取り出す
final result = await useCase(...);

// 方法1: fold（推奨）
result.fold(
  (failure) => print('失敗: $failure'),  // Left の処理
  (user)    => print('成功: $user'),     // Right の処理
);

// 方法2: isRight / isLeft で確認
if (result.isRight()) {
  final user = result.getOrElse((_) => throw Error());
}

// 方法3: getRight() で Option<T> に変換
final user = result.getRight(); // Option<AppUser>
```

### 問題: `Unit` 型とは何か

```dart
// void の代わりに使う Dart の型
// 「意味のある戻り値はないが、Either の Right に包みたい」場合に使う

Future<Either<Failure, Unit>> signOut();

// 使い方
final result = await useCase();
result.fold(
  (failure) => handleError(failure),
  (unit)    => print('サインアウト成功'), // unit は無視してよい
);

// Right(unit) で成功を表現
return const Right(unit);
```

---

## 7. 完了チェックリスト

- [ ] `app_user.dart` に `firebase_auth` の import がない
- [ ] `auth_repository.dart` に `firebase_auth` の import がない
- [ ] 全 UseCase が `call()` メソッドを持つ
- [ ] 全 UseCase が `Either<Failure, T>` を返す
- [ ] UseCase の Unit テストが全て通る
- [ ] `flutter analyze` でエラーが出ない

---

## 8. 次のフェーズへの接続

Domain 層で定義した `AuthRepository` インターフェースを、
Phase 3 の Data 層が `AuthRepositoryImpl` として実装する。

```
// Domain 層（Phase 2）
abstract interface class AuthRepository {
  Future<Either<Failure, AppUser>> signInWithEmail({...});
}

// Data 層（Phase 3）
class AuthRepositoryImpl implements AuthRepository {
  @override
  Future<Either<Failure, AppUser>> signInWithEmail({...}) async {
    try {
      final user = await _dataSource.signInWithEmail(...);
      return Right(user.toEntity());
    } on FirebaseAuthException catch (e) {
      return Left(Failure.auth(message: e.message ?? '', code: e.code));
    }
  }
}
```
