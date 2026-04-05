import 'package:fpdart/fpdart.dart';
import 'package:flutter_learn/core/error/failure.dart';
import 'package:flutter_learn/features/auth/domain/entities/app_user.dart';
import 'package:flutter_learn/features/auth/domain/repositories/auth_repository.dart';

/// 現在ログイン中のユーザーを取得する UseCase
class GetCurrentUser {
  final AuthRepository _repository;

  const GetCurrentUser(this._repository);

  Future<Either<Failure, AppUser>> call() => _repository.getCurrentUser();
}
