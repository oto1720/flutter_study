# Phase 3: Data 層 — UserModel / DataSource / RepositoryImpl

## 概要

Firebase SDK を直接使う唯一の層。**`try/catch` はこの層にのみ存在**し、
上位層（Domain・Presentation）に例外は届かない。

---

## 1. Data 層の責務

```
Data 層の3つの責務:

1. 外部データを Domain の型に変換する（UserModel → AppUser）
2. Firebase SDK を呼び出す（AuthRemoteDataSourceImpl）
3. 例外を Either<Failure, T> に変換する（AuthRepositoryImpl）
```

**なぜ3つのクラスに分けるか：**

```
AuthRemoteDataSourceImpl
  → 「Firebase をどう呼ぶか」のみに集中
  → テスト時: FakeAuthRemoteDataSource に差し替え

AuthRepositoryImpl
  → 「例外をどう変換するか」のみに集中
  → DataSource を呼んで結果を Domain 型に変換

UserModel
  → 「Firebase の型を Domain の型に変換する」のみに集中
  → fromFirebaseUser() / toEntity() の変換ロジックを隔離
```

---

## 2. UserModel — 型変換の橋渡し役

### コード

```dart
// lib/features/auth/data/models/user_model.dart

class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;

  // ① Firebase User → UserModel（Data 層への入口）
  factory UserModel.fromFirebaseUser(User firebaseUser) {
    return UserModel(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName,
      photoUrl: firebaseUser.photoURL,
    );
  }

  // ② UserModel → AppUser（Domain 層への出口）
  AppUser toEntity() {
    return AppUser(
      id: id,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
    );
  }
}
```

### なぜ `AppUser` を継承しないのか

```dart
// ❌ 継承しようとするとコンパイルエラー
class UserModel extends AppUser { ... }
// Error: The class 'UserModel' can't extend 'AppUser' because
// 'AppUser' only has factory constructors (no generative constructors)
```

**理由：** Freezed が生成するクラスは **factory constructor のみ** を持つ。
Dart の継承ルール上、サブクラスは親クラスのジェネレーティブコンストラクタを呼ぶ必要があるが、
Freezed クラスにはそれが存在しない。

**解決策：継承ではなく変換（Composition over Inheritance）**

```dart
// ✅ toEntity() で変換する設計
class UserModel {
  AppUser toEntity() => AppUser(id: id, email: email, ...);
}

// 使い方（RepositoryImpl）
final model = await _dataSource.signInWithEmail(...);
return Right(model.toEntity()); // ← UserModel を AppUser に変換して Domain へ
```

**この設計の利点：**
- `UserModel` は Data 層の型。Domain 層の `AppUser` は Domain 層の型。完全に分離
- `UserModel` に Firebase 固有のフィールド（`refreshToken` 等）を追加しても `AppUser` に影響しない

---

## 3. AuthRemoteDataSource — Firebase の隔離

### コード（インターフェース + 実装）

```dart
// インターフェース（テスト時に差し替えられる）
abstract interface class AuthRemoteDataSource {
  Stream<UserModel?> get authStateChanges;
  Future<UserModel> signInWithEmail({required String email, required String password});
  Future<UserModel> signInWithGoogle();
  Future<UserModel> signUpWithEmail({required String email, required String password});
  Future<void> signOut();
  Future<UserModel?> getCurrentUser();
}

// 実装（Firebase SDK を直接呼ぶ）
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  const AuthRemoteDataSourceImpl(this._firebaseAuth, this._googleSignIn);

  @override
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return UserModel.fromFirebaseUser(credential.user!);
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      // ユーザーがキャンセルした場合は FirebaseAuthException と���て扱う
      throw FirebaseAuthException(
        code: 'google-sign-in-cancelled',
        message: 'Google sign in was cancelled by the user.',
      );
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCredential = await _firebaseAuth.signInWithCredential(credential);
    return UserModel.fromFirebaseUser(userCredential.user!);
  }
}
```

### DataSource に例外があってよい理由

DataSource は「Firebase を呼ぶだけ」の層。例外はここで投げたまま RepositoryImpl に伝え、
RepositoryImpl が `catch` して `Either` に変換する。

```
DataSource  →  例外を投げる  →  RepositoryImpl が catch → Either に変換
```

DataSource 自体は例外処理を知らなくていい。責務の分離。

---

## 4. AuthRepositoryImpl — 例外を Either に変換

### コード

```dart
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _dataSource;

  const AuthRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, AppUser>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final model = await _dataSource.signInWithEmail(
        email: email,
        password: password,
      );
      return Right(model.toEntity()); // 成功 → Right に包んで返す
    } on FirebaseAuthException catch (e) {
      // Firebase の認証エラー → AuthFailure に変換
      return Left(Failure.auth(message: e.message ?? '', code: e.code));
    } on Exception {
      // その他の例外 → UnexpectedFailure
      return const Left(Failure.unexpected());
    }
  }
}
```

### FirebaseAuthException のエラーコード一覧

| コード | 意味 | 対応する Failure |
|---|---|---|
| `user-not-found` | 該当メールのユーザーが存在しない | `AuthFailure(code: 'user-not-found')` |
| `wrong-password` | パスワードが間違っている | `AuthFailure(code: 'wrong-password')` |
| `email-already-in-use` | メールアドレスが既に使われている | `AuthFailure(code: 'email-already-in-use')` |
| `weak-password` | パスワードが脆弱 | `AuthFailure(code: 'weak-password')` |
| `invalid-email` | メール形式が不正 | `AuthFailure(code: 'invalid-email')` |
| `network-request-failed` | ネットワークエラー | `AuthFailure(code: '...')` |
| `too-many-requests` | レート制限 | `AuthFailure(code: 'too-many-requests')` |

### `on Exception` vs `catch (e)`

```dart
// ❌ catch は Error（メモリ不足など）も捕まえてしまう
} catch (e) {
  return const Left(Failure.unexpected());
}

// ✅ on Exception は例外のみ。Error は上に伝播させる
} on Exception {
  return const Left(Failure.unexpected());
}
```

---

## 5. テスト戦略 — FakeDataSource vs Mock

### Mock と Fake の違い

| | Mock | Fake |
|---|---|---|
| 定義 | 呼び出し記録・検証のためのダブル | 実際に動くシンプルな代替実装 |
| 状態 | 持たない | 持つ（インメモリ Map 等） |
| 使用場面 | 「メソッドが呼ばれたか」を検証したい | 「メソッドの振る舞い」を再現したい |

**RepositoryImpl のテストには Fake が適切な理由：**

Repository のテストでは「サインインしてからそのユーザーを getCurrentUser で取得できるか」など、
**状態を持つ振る舞い**を検証したい。Mock は状態を持たないため、このようなシナリオに不向き。

### FakeAuthRemoteDataSource のコード

```dart
class FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  // インメモリストア: email → password
  final Map<String, String> _users = {};
  UserModel? _currentUser;

  @override
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    // 登録済みユーザーか確認
    if (!_users.containsKey(email)) {
      throw FirebaseAuthException(code: 'user-not-found', message: '...');
    }
    if (_users[email] != password) {
      throw FirebaseAuthException(code: 'wrong-password', message: '...');
    }
    final user = UserModel(id: 'uid-$email', email: email);
    _currentUser = user;
    return user;
  }

  // テスト準備用: 事前にユーザーを登録するヘルパー
  void seedUser({required String email, required String password}) {
    _users[email] = password;
  }
}
```

### テストコードの読み方

```dart
test('登録済みユーザーでサインイン成功 → Right(AppUser) を返す', () async {
  // 1. テストデータを準備（シード）
  fakeDataSource.seedUser(email: tEmail, password: tPassword);

  // 2. テスト対象（Repository）を実行
  final result = await repository.signInWithEmail(
    email: tEmail,
    password: tPassword,
  );

  // 3. 結果を検証
  expect(result.isRight(), isTrue);      // Either が Right か
  result.fold(
    (_) => fail('失敗が返るはずがない'),  // Left なら強制失敗
    (user) => expect(user.email, tEmail), // Right の値を検証
  );
});
```

---

## 6. Google Sign-In のフロー詳細

```
ユーザーが「Google でログイン」ボタンをタップ
    ↓
GoogleSignIn().signIn()
    → Google のネイティブ認証 UI が表示される
    → ユーザーが Google アカウントを選択
    ↓
GoogleSignInAccount を取得
    ↓
googleAccount.authentication
    → accessToken / idToken を取得
    ↓
GoogleAuthProvider.credential(accessToken, idToken)
    → Firebase 用の Credential を作成
    ↓
FirebaseAuth.signInWithCredential(credential)
    → Firebase にサインイン
    ↓
UserCredential.user → UserModel.fromFirebaseUser()
```

**キャンセル時の処理：**

```dart
final googleUser = await _googleSignIn.signIn();
if (googleUser == null) {
  // ユーザーがキャンセル → null が返ってくる
  // Firebase の例外として扱い、RepositoryImpl で catch させる
  throw FirebaseAuthException(
    code: 'google-sign-in-cancelled',
    message: 'Google sign in was cancelled by the user.',
  );
}
```

---

## 7. つまずきポイントと解決策

### 問題: `UserModel extends AppUser` でコンパイルエラー

```
Error: The class 'UserModel' can't extend 'AppUser' because 'AppUser' only
has factory constructors (no generative constructors)
```

**解決：** 継承を諦めて `toEntity()` パターンに切り替える（詳細は Section 2 参照）

### 問題: `credential.user!` の `!` は安全か

```dart
final credential = await _firebaseAuth.signInWithEmailAndPassword(...);
return UserModel.fromFirebaseUser(credential.user!);
```

`signInWithEmailAndPassword` が成功した場合、`credential.user` が `null` になることは
Firebase の仕様上ありえない。成功したのに user が null なら Firebase のバグ。
→ `!` は許容。ただし本番では `??` でフォール��ックを設けることも検討する。

---

## 8. 完了チェックリスト

- [ ] `UserModel.fromFirebaseUser()` で全フィール���が変換されている
- [ ] `UserModel.toEntity()` が `AppUser` を返す
- [ ] `AuthRemoteDataSourceImpl` が全メソッドを実装している
- [ ] `AuthRepositoryImpl` の全メソッドが `try/catch` を持つ
- [ ] `FirebaseAuthException` が `AuthFailure` に変換されている
- [ ] `FakeAuthRemoteDataSource` が `seedUser()` ヘルパーを持つ
- [ ] Data 層のテストが全通過

---

## 9. 次のフェーズへの接続

Phase 3 で実装した `AuthRepositoryImpl` を、
Phase 4 の Riverpod Provider が DI グラフの一部として組み込む。

```dart
// Phase 4 (auth_providers.dart)
@riverpod
AuthRepository authRepository(Ref ref) =>
    AuthRepositoryImpl(ref.watch(authRemoteDataSourceProvider));
    // ↑ Phase 3 の DataSource を注入して RepositoryImpl を作る
```
