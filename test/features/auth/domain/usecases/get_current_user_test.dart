import 'package:flutter_learn/core/error/failure.dart';
import 'package:flutter_learn/features/auth/domain/usecases/get_current_user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_helpers.dart';

void main() {
  late MockAuthRepository mockRepository;
  late GetCurrentUser useCase;

  setUp(() {
    mockRepository = MockAuthRepository();
    useCase = GetCurrentUser(mockRepository);
  });

  group('GetCurrentUser', () {
    test('ログイン中のとき AppUser を返す', () async {
      when(() => mockRepository.getCurrentUser())
          .thenAnswer((_) async => const Right(tUser));

      final result = await useCase();

      expect(result, const Right(tUser));
      verify(() => mockRepository.getCurrentUser()).called(1);
    });

    test('未ログインのとき AuthFailure を返す', () async {
      const tFailure = Failure.auth(
        message: 'ユーザーが見つかりません',
        code: 'user-not-found',
      );
      when(() => mockRepository.getCurrentUser())
          .thenAnswer((_) async => const Left(tFailure));

      final result = await useCase();

      expect(result, const Left(tFailure));
    });
  });
}
