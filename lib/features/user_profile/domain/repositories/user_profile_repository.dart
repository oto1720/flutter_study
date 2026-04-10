import 'package:fpdart/fpdart.dart';
import 'package:flutter_learn/core/error/failure.dart';
import 'package:flutter_learn/features/user_profile/domain/entities/user_profile.dart';

/// ユーザープロフィールリポジトリの契約（インターフェース）
///
/// Domain 層はこの抽象インターフェースのみを知っている。
/// 実際の dio / HTTP 実装は Data 層の UserProfileRepositoryImpl が担う。
abstract interface class UserProfileRepository {
  /// 指定した ID のユーザープロフィールを取得する
  Future<Either<Failure, UserProfile>> getUserProfile(int userId);
}
