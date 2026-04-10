import 'package:flutter_learn/core/error/failure.dart';
import 'package:flutter_learn/features/user_profile/domain/entities/user_profile.dart';
import 'package:flutter_learn/features/user_profile/domain/repositories/user_profile_repository.dart';
import 'package:flutter_learn/features/user_profile/domain/usecases/get_user_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockUserProfileRepository extends Mock
    implements UserProfileRepository {}

void main() {
  late MockUserProfileRepository mockRepository;
  late GetUserProfile useCase;

  setUp(() {
    mockRepository = MockUserProfileRepository();
    useCase = GetUserProfile(mockRepository);
  });

  const tProfile = UserProfile(
    id: 1,
    name: 'Leanne Graham',
    email: 'Sincere@april.biz',
    phone: '1-770-736-8031',
    website: 'hildegard.org',
    companyName: 'Romaguera-Crona',
  );

  group('GetUserProfile', () {
    test('成功: Repository が Right を返すとき UserProfile を返す', () async {
      // Arrange
      when(() => mockRepository.getUserProfile(1))
          .thenAnswer((_) async => const Right(tProfile));

      // Act
      final result = await useCase(1);

      // Assert
      expect(result, const Right(tProfile));
      verify(() => mockRepository.getUserProfile(1)).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('失敗: ネットワークエラーのとき NetworkFailure を返す', () async {
      // Arrange
      when(() => mockRepository.getUserProfile(any()))
          .thenAnswer((_) async => const Left(Failure.network()));

      // Act
      final result = await useCase(1);

      // Assert
      expect(result, const Left(Failure.network()));
    });

    test('失敗: サーバーエラーのとき ServerFailure を返す', () async {
      // Arrange
      when(() => mockRepository.getUserProfile(any()))
          .thenAnswer(
              (_) async => const Left(Failure.server(statusCode: 404)));

      // Act
      final result = await useCase(1);

      // Assert
      expect(result, const Left(Failure.server(statusCode: 404)));
    });
  });
}
