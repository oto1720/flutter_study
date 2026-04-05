import 'package:fpdart/fpdart.dart';
import 'package:flutter_learn/core/error/failure.dart';
import 'package:flutter_learn/features/auth/domain/repositories/auth_repository.dart';

/// サインアウトする UseCase
class SignOut {
  final AuthRepository _repository;

  const SignOut(this._repository);

  Future<Either<Failure, Unit>> call() => _repository.signOut();
}
