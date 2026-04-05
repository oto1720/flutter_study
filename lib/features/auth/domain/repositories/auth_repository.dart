import 'package:fpdart/fpdart.dart';
import 'package:flutter_learn/core/error/failure.dart';
import 'package:flutter_learn/features/auth/domain/entities/app_user.dart';

/// 認証リポジトリの契約（インターフェース）
///
/// Domain 層はこの抽象インターフェースのみを知っている。
/// 実際の Firebase 実装は Data 層の AuthRepositoryImpl が担う。
/// テスト時は MockAuthRepository や FakeAuthRepository に差し替える。
abstract interface class AuthRepository {
  /// Firebase の認証状態ストリーム
  /// ログイン → AppUser, ログアウト → null
  Stream<AppUser?> get authStateChanges;

  /// メールアドレス + パスワードでサインイン
  Future<Either<Failure, AppUser>> signInWithEmail({
    required String email,
    required String password,
  });

  /// Google アカウントでサインイン
  Future<Either<Failure, AppUser>> signInWithGoogle();

  /// メールアドレス + パスワードで新規登録
  Future<Either<Failure, AppUser>> signUpWithEmail({
    required String email,
    required String password,
  });

  /// サインアウト
  Future<Either<Failure, Unit>> signOut();

  /// 現在ログイン中のユーザーを取得（非同期）
  Future<Either<Failure, AppUser>> getCurrentUser();
}
