import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_learn/core/error/failure.dart';
import 'package:flutter_learn/features/user_profile/data/datasources/user_api_client.dart';
import 'package:flutter_learn/features/user_profile/domain/entities/user_profile.dart';
import 'package:flutter_learn/features/user_profile/domain/repositories/user_profile_repository.dart';

/// UserProfileRepository の HTTP 実装
///
/// DioException を Failure に変換する。
/// Domain 層は DioException を知らないため、ここで変換する。
class UserProfileRepositoryImpl implements UserProfileRepository {
  const UserProfileRepositoryImpl(this._apiClient);

  final UserApiClient _apiClient;

  @override
  Future<Either<Failure, UserProfile>> getUserProfile(int userId) async {
    try {
      final dto = await _apiClient.getUser(userId);
      return Right(dto.toEntity());
    } on DioException catch (e) {
      return Left(_mapDioException(e));
    }
  }

  /// DioException の種類に応じて Failure に変換する
  Failure _mapDioException(DioException e) {
    return switch (e.type) {
      // タイムアウト系
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        const Failure.network(),
      // サーバーからのエラーレスポンス（4xx / 5xx）
      DioExceptionType.badResponse =>
        Failure.server(statusCode: e.response?.statusCode ?? 0),
      // 接続自体が確立できない（Wi-Fi オフなど）
      DioExceptionType.connectionError => const Failure.network(),
      // その他
      _ => const Failure.unexpected(),
    };
  }
}
