import 'package:dio/dio.dart';
import 'package:flutter_learn/core/error/failure.dart';
import 'package:flutter_learn/features/user_profile/data/datasources/user_api_client.dart';
import 'package:flutter_learn/features/user_profile/data/models/user_profile_dto.dart';
import 'package:flutter_learn/features/user_profile/data/repositories/user_profile_repository_impl.dart';
import 'package:flutter_learn/features/user_profile/domain/entities/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockUserApiClient extends Mock implements UserApiClient {}

void main() {
  late MockUserApiClient mockApiClient;
  late UserProfileRepositoryImpl repository;

  setUp(() {
    mockApiClient = MockUserApiClient();
    repository = UserProfileRepositoryImpl(mockApiClient);
  });

  const tDto = UserProfileDto(
    id: 1,
    name: 'Leanne Graham',
    email: 'Sincere@april.biz',
    phone: '1-770-736-8031',
    website: 'hildegard.org',
    company: CompanyDto(name: 'Romaguera-Crona'),
  );

  const tProfile = UserProfile(
    id: 1,
    name: 'Leanne Graham',
    email: 'Sincere@april.biz',
    phone: '1-770-736-8031',
    website: 'hildegard.org',
    companyName: 'Romaguera-Crona',
  );

  group('UserProfileRepositoryImpl', () {
    test('成功: APIクライアントが DTO を返すとき Right(UserProfile) を返す', () async {
      // Arrange
      when(() => mockApiClient.getUser(1))
          .thenAnswer((_) async => tDto);

      // Act
      final result = await repository.getUserProfile(1);

      // Assert
      expect(result, const Right(tProfile));
    });

    test('失敗: タイムアウト → Failure.network() を返す', () async {
      // Arrange: connectionTimeout で DioException を発生させる
      when(() => mockApiClient.getUser(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/users/1'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      // Act
      final result = await repository.getUserProfile(1);

      // Assert
      expect(result, const Left(Failure.network()));
    });

    test('失敗: 404 レスポンス → Failure.server(statusCode: 404) を返す', () async {
      // Arrange
      when(() => mockApiClient.getUser(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/users/999'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/users/999'),
            statusCode: 404,
          ),
        ),
      );

      // Act
      final result = await repository.getUserProfile(999);

      // Assert
      expect(result, const Left(Failure.server(statusCode: 404)));
    });

    test('失敗: 接続エラー → Failure.network() を返す', () async {
      // Arrange
      when(() => mockApiClient.getUser(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/users/1'),
          type: DioExceptionType.connectionError,
        ),
      );

      // Act
      final result = await repository.getUserProfile(1);

      // Assert
      expect(result, const Left(Failure.network()));
    });

    test('失敗: 予期しないエラー → Failure.unexpected() を返す', () async {
      // Arrange
      when(() => mockApiClient.getUser(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/users/1'),
          type: DioExceptionType.unknown,
        ),
      );

      // Act
      final result = await repository.getUserProfile(1);

      // Assert
      expect(result, const Left(Failure.unexpected()));
    });
  });
}
