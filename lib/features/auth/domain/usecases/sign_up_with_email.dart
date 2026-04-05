import 'package:fpdart/fpdart.dart';
import 'package:flutter_learn/core/error/failure.dart';
import 'package:flutter_learn/features/auth/domain/entities/app_user.dart';
import 'package:flutter_learn/features/auth/domain/repositories/auth_repository.dart';

/// メールアドレス + パスワードで新規登録する UseCase
class SignUpWithEmail {
  final AuthRepository _repository;

  const SignUpWithEmail(this._repository);

  Future<Either<Failure, AppUser>> call({
    required String email,
    required String password,
  }) =>
      _repository.signUpWithEmail(email: email, password: password);
}
