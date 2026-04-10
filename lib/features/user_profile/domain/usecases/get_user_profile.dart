import 'package:fpdart/fpdart.dart';
import 'package:flutter_learn/core/error/failure.dart';
import 'package:flutter_learn/features/user_profile/domain/entities/user_profile.dart';
import 'package:flutter_learn/features/user_profile/domain/repositories/user_profile_repository.dart';

/// ユーザープロフィール取得 UseCase
///
/// Repository インターフェースを通じて取得するだけ。
/// dio の存在を知らない — それは Data 層の責務。
class GetUserProfile {
  const GetUserProfile(this._repository);

  final UserProfileRepository _repository;

  Future<Either<Failure, UserProfile>> call(int userId) =>
      _repository.getUserProfile(userId);
}
