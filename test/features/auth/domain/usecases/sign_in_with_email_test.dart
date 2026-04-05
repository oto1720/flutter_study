import 'package:flutter_learn/core/error/failure.dart';
import 'package:flutter_learn/features/auth/domain/usecases/sign_in_with_email.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_helpers.dart';

void main() {
  late MockAuthRepository mockRepository;
  late SignInWithEmail useCase;

  setUp(() {
    mockRepository = MockAuthRepository();
    useCase = SignInWithEmail(mockRepository);
  });

  const tEmail = 'test@example.com';
  const tPassword = 'password123';

  group('SignInWithEmail', () {
    test('サインイン成功時に AppUser を返す', () async {
      // Arrange: リポジトリが成功を返すように設定
      when(
        () => mockRepository.signInWithEmail(
          email: tEmail,
          password: tPassword,
        ),
      ).thenAnswer((_) async => const Right(tUser));

      // Act: UseCase を実行
      final result = await useCase(email: tEmail, password: tPassword);

      // Assert: Right(tUser) が返る
      expect(result, const Right(tUser));
      // リポジトリが正しい引数で1回呼ばれたことを確認
      verify(
        () => mockRepository.signInWithEmail(
          email: tEmail,
          password: tPassword,
        ),
      ).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('パスワードが間違っているとき AuthFailure を返す', () async {
      // Arrange: リポジトリが失敗を返すように設定
      when(
        () => mockRepository.signInWithEmail(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async => const Left(
          Failure.auth(message: 'wrong-password', code: 'wrong-password'),
        ),
      );

      // Act
      final result = await useCase(email: tEmail, password: 'wrong');

      // Assert: Left（失敗）が返る
      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(
          failure,
          const Failure.auth(
            message: 'wrong-password',
            code: 'wrong-password',
          ),
        ),
        (_) => fail('成功が返るはずがない'),
      );
    });

    test('ネットワークエラーのとき NetworkFailure を返す', () async {
      // Arrange
      when(
        () => mockRepository.signInWithEmail(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => const Left(Failure.network()));

      // Act
      final result = await useCase(email: tEmail, password: tPassword);

      // Assert
      expect(result, const Left(Failure.network()));
    });
  });
}
