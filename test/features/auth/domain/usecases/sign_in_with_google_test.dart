import 'package:flutter_learn/core/error/failure.dart';
import 'package:flutter_learn/features/auth/domain/usecases/sign_in_with_google.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_helpers.dart';

void main() {
  late MockAuthRepository mockRepository;
  late SignInWithGoogle useCase;

  setUp(() {
    mockRepository = MockAuthRepository();
    useCase = SignInWithGoogle(mockRepository);
  });

  group('SignInWithGoogle', () {
    test('サインイン成功時に AppUser を返す', () async {
      when(() => mockRepository.signInWithGoogle())
          .thenAnswer((_) async => const Right(tUser));

      final result = await useCase();

      expect(result, const Right(tUser));
      verify(() => mockRepository.signInWithGoogle()).called(1);
    });

    test('キャンセルまたは失敗時に Failure を返す', () async {
      when(() => mockRepository.signInWithGoogle()).thenAnswer(
        (_) async => const Left(
          Failure.auth(
            message: 'Google sign in cancelled',
            code: 'cancelled',
          ),
        ),
      );

      final result = await useCase();

      expect(result.isLeft(), isTrue);
    });
  });
}
