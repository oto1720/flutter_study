import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_learn/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:flutter_learn/features/auth/data/models/user_model.dart';

/// AuthRemoteDataSource のインメモリ偽実装
///
/// Firebase SDK を一切使わずに DataSource の振る舞いを再現する。
/// Mock と Fake の違い：
///   Mock  → 呼び出しを記録・検証するためのダブル
///   Fake  → 実際に動くシンプルな代替実装（今回はこちら）
class FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  // サインイン済みユーザーのストア（email → UserModel）
  final Map<String, String> _users = {}; // email → password
  UserModel? _currentUser;

  static const _testUser = UserModel(
    id: 'test-uid-123',
    email: 'test@example.com',
    displayName: 'Test User',
  );

  @override
  Stream<UserModel?> get authStateChanges async* {
    yield _currentUser;
  }

  @override
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (!_users.containsKey(email)) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No user found for that email.',
      );
    }
    if (_users[email] != password) {
      throw FirebaseAuthException(
        code: 'wrong-password',
        message: 'Wrong password provided.',
      );
    }
    final user = UserModel(id: 'uid-$email', email: email);
    _currentUser = user;
    return user;
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    _currentUser = _testUser;
    return _testUser;
  }

  @override
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    if (_users.containsKey(email)) {
      throw FirebaseAuthException(
        code: 'email-already-in-use',
        message: 'The email address is already in use.',
      );
    }
    _users[email] = password;
    final user = UserModel(id: 'uid-$email', email: email);
    _currentUser = user;
    return user;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }

  @override
  Future<UserModel?> getCurrentUser() async => _currentUser;

  /// テスト用：事前にユーザーを登録しておくヘルパー
  void seedUser({required String email, required String password}) {
    _users[email] = password;
  }
}
