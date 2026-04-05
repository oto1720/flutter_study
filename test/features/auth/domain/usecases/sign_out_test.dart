import 'package:flutter_learn/core/error/failure.dart';
import 'package:flutter_learn/features/auth/domain/usecases/sign_out.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_helpers.dart';

void main() {
  late MockAuthRepository mockRepository;
  late SignOut useCase;

  setUp(() {
    mockRepository = MockAuthRepository();
    useCase = SignOut(mockRepository);
  });

  group('SignOut', () {
    test('サインアウト成功時に Unit を返す', () async {
      when(() => mockRepository.signOut())
          .thenAnswer((_) async => const Right(unit));

      final result = await useCase();

      expect(result, const Right(unit));
      verify(() => mockRepository.signOut()).called(1);
    });

    test('サインアウト失敗時に Failure を返す', () async {
      when(() => mockRepository.signOut())
          .thenAnswer((_) async => const Left(Failure.unexpected()));

      final result = await useCase();

      expect(result, const Left(Failure.unexpected()));
    });
  });
}
