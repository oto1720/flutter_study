import 'package:fpdart/fpdart.dart';
import 'package:flutter_learn/core/error/failure.dart';
import 'package:flutter_learn/features/auth/domain/entities/app_user.dart';
import 'package:flutter_learn/features/auth/domain/repositories/auth_repository.dart';

/// メールアドレス + パスワードでサインインする UseCase
///
/// UseCase は1クラス1メソッド（単一責任原則）。
/// call() を定義することで useCase(email: ...) のように関数として呼べる。
class SignInWithEmail {
  final AuthRepository _repository;

  const SignInWithEmail(this._repository);

  Future<Either<Failure, AppUser>> call({
    required String email,
    required String password,
  }) =>
      _repository.signInWithEmail(email: email, password: password);
}
