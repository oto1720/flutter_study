import 'package:flutter_learn/core/error/failure.dart';
import 'package:flutter_learn/features/auth/domain/usecases/sign_up_with_email.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_helpers.dart';

void main() {
  late MockAuthRepository mockRepository;
  late SignUpWithEmail useCase;

  setUp(() {
    mockRepository = MockAuthRepository();
    useCase = SignUpWithEmail(mockRepository);
  });

  const tEmail = 'newuser@example.com';
  const tPassword = 'password123';

  group('SignUpWithEmail', () {
    test('新規登録成功時に AppUser を返す', () async {
      when(
        () => mockRepository.signUpWithEmail(
          email: tEmail,
          password: tPassword,
        ),
      ).thenAnswer((_) async => const Right(tUser));

      final result = await useCase(email: tEmail, password: tPassword);

      expect(result, const Right(tUser));
      verify(
        () => mockRepository.signUpWithEmail(
          email: tEmail,
          password: tPassword,
        ),
      ).called(1);
    });

    test('メールアドレスがすでに使用されているとき AuthFailure を返す', () async {
      when(
        () => mockRepository.signUpWithEmail(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async => const Left(
          Failure.auth(
            message: 'email-already-in-use',
            code: 'email-already-in-use',
          ),
        ),
      );

      final result = await useCase(email: tEmail, password: tPassword);

      expect(result.isLeft(), isTrue);
    });
  });
}
