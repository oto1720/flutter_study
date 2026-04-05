import 'package:fpdart/fpdart.dart';
import 'package:flutter_learn/core/error/failure.dart';
import 'package:flutter_learn/features/auth/domain/entities/app_user.dart';
import 'package:flutter_learn/features/auth/domain/repositories/auth_repository.dart';

/// Google アカウントでサインインする UseCase
class SignInWithGoogle {
  final AuthRepository _repository;

  const SignInWithGoogle(this._repository);

  Future<Either<Failure, AppUser>> call() => _repository.signInWithGoogle();
}
