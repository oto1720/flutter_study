import 'package:flutter_learn/core/error/failure.dart';
import 'package:flutter_learn/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../helpers/fakes/fake_auth_remote_data_source.dart';

void main() {
  late FakeAuthRemoteDataSource fakeDataSource;
  late AuthRepositoryImpl repository;

  setUp(() {
    fakeDataSource = FakeAuthRemoteDataSource();
    repository = AuthRepositoryImpl(fakeDataSource);
  });

  const tEmail = 'test@example.com';
  const tPassword = 'password123';

  group('signInWithEmail', () {
    test('登録済みユーザーでサインイン成功 → Right(AppUser) を返す', () async {
      // 事前にユーザーを登録
      fakeDataSource.seedUser(email: tEmail, password: tPassword);

      final result = await repository.signInWithEmail(
        email: tEmail,
        password: tPassword,
      );

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('失敗が返るはずがない'),
        (user) {
          expect(user.email, tEmail);
        },
      );
    });

    test('存在しないユーザーでサインイン → AuthFailure(user-not-found) を返す', () async {
      final result = await repository.signInWithEmail(
        email: 'nobody@example.com',
        password: tPassword,
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
          final authFailure = failure as AuthFailure;
          expect(authFailure.code, 'user-not-found');
        },
        (_) => fail('成功が返るはずがない'),
      );
    });

    test('パスワード誤り → AuthFailure(wrong-password) を返す', () async {
      fakeDataSource.seedUser(email: tEmail, password: tPassword);

      final result = await repository.signInWithEmail(
        email: tEmail,
        password: 'wrong-password',
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
          final authFailure = failure as AuthFailure;
          expect(authFailure.code, 'wrong-password');
        },
        (_) => fail('成功が返るはずがない'),
      );
    });
  });

  group('signUpWithEmail', () {
    test('新規メールアドレスで登録成功 → Right(AppUser) を返す', () async {
      final result = await repository.signUpWithEmail(
        email: tEmail,
        password: tPassword,
      );

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('失敗が返るはずがない'),
        (user) => expect(user.email, tEmail),
      );
    });

    test('すでに使われているメールアドレスで登録 → AuthFailure(email-already-in-use) を返す', () async {
      fakeDataSource.seedUser(email: tEmail, password: tPassword);

      final result = await repository.signUpWithEmail(
        email: tEmail,
        password: 'newpassword',
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
          final authFailure = failure as AuthFailure;
          expect(authFailure.code, 'email-already-in-use');
        },
        (_) => fail('成功が返るはずがない'),
      );
    });
  });

  group('signInWithGoogle', () {
    test('Google サインイン成功 → Right(AppUser) を返す', () async {
      final result = await repository.signInWithGoogle();

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('失敗が返るはずがない'),
        (user) => expect(user.email, isNotEmpty),
      );
    });
  });

  group('signOut', () {
    test('サインアウト成功 → Right(unit) を返す', () async {
      final result = await repository.signOut();
      expect(result, const Right(unit));
    });
  });

  group('getCurrentUser', () {
    test('サインイン後に getCurrentUser → AppUser を返す', () async {
      fakeDataSource.seedUser(email: tEmail, password: tPassword);
      await repository.signInWithEmail(email: tEmail, password: tPassword);

      final result = await repository.getCurrentUser();

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('失敗が返るはずがない'),
        (user) => expect(user.email, tEmail),
      );
    });

    test('未サインイン時に getCurrentUser → AuthFailure を返す', () async {
      final result = await repository.getCurrentUser();

      expect(result.isLeft(), isTrue);
    });
  });

  group('authStateChanges', () {
    test('サインイン後に authStateChanges が AppUser を emit する', () async {
      fakeDataSource.seedUser(email: tEmail, password: tPassword);
      await repository.signInWithEmail(email: tEmail, password: tPassword);

      final stream = repository.authStateChanges;
      final user = await stream.first;

      expect(user, isNotNull);
      expect(user!.email, tEmail);
    });
  });
}
