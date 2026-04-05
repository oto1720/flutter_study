import 'dart:async';

import 'package:flutter_learn/core/error/failure.dart';
import 'package:flutter_learn/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter_learn/features/auth/presentation/providers/auth_state_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_helpers.dart';

void main() {
  late MockAuthRepository mockRepository;
  // StreamController でストリームの発火タイミングを完全制御する
  // Stream.value(null) を使うと即座に emit して状態を上書きしてしまうため
  late StreamController<dynamic> authStreamController;

  setUp(() {
    mockRepository = MockAuthRepository();
    authStreamController = StreamController.broadcast();

    when(() => mockRepository.authStateChanges)
        .thenAnswer((_) => authStreamController.stream.cast());
  });

  tearDown(() => authStreamController.close());

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('AuthStateNotifier', () {
    test('初期状態は initial', () {
      final container = makeContainer();
      expect(container.read(authStateNotifierProvider), const AuthState.initial());
    });

    group('signInWithEmail', () {
      test('成功: loading → authenticated の順に遷移する', () async {
        when(
          () => mockRepository.signInWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => const Right(tUser));

        final container = makeContainer();
        final states = <AuthState>[];
        container.listen(
          authStateNotifierProvider,
          (_, next) => states.add(next),
          fireImmediately: false,
        );

        await container
            .read(authStateNotifierProvider.notifier)
            .signInWithEmail('test@example.com', 'password123');

        expect(states, [
          const AuthState.loading(),
          AuthState.authenticated(tUser),
        ]);
      });

      test('失敗: loading → error の順に遷移する', () async {
        const tFailure = Failure.auth(
          message: 'wrong-password',
          code: 'wrong-password',
        );
        when(
          () => mockRepository.signInWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => const Left(tFailure));

        final container = makeContainer();
        final states = <AuthState>[];
        container.listen(
          authStateNotifierProvider,
          (_, next) => states.add(next),
          fireImmediately: false,
        );

        await container
            .read(authStateNotifierProvider.notifier)
            .signInWithEmail('test@example.com', 'wrong');

        expect(states, [
          const AuthState.loading(),
          const AuthState.error(tFailure),
        ]);
      });
    });

    group('signUpWithEmail', () {
      test('成功: loading → authenticated の順に遷移する', () async {
        when(
          () => mockRepository.signUpWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => const Right(tUser));

        final container = makeContainer();
        final states = <AuthState>[];
        container.listen(
          authStateNotifierProvider,
          (_, next) => states.add(next),
          fireImmediately: false,
        );

        await container
            .read(authStateNotifierProvider.notifier)
            .signUpWithEmail('new@example.com', 'password123');

        expect(states, [
          const AuthState.loading(),
          AuthState.authenticated(tUser),
        ]);
      });
    });

    group('signOut', () {
      test('成功: loading → unauthenticated の順に遷移する', () async {
        when(() => mockRepository.signOut())
            .thenAnswer((_) async => const Right(unit));

        final container = makeContainer();
        final states = <AuthState>[];
        container.listen(
          authStateNotifierProvider,
          (_, next) => states.add(next),
          fireImmediately: false,
        );

        await container.read(authStateNotifierProvider.notifier).signOut();

        expect(states, [
          const AuthState.loading(),
          const AuthState.unauthenticated(),
        ]);
      });
    });

    group('authStateChanges ストリーム連動', () {
      test('ストリームが AppUser を流したとき authenticated になる', () async {
        final container = makeContainer();
        final states = <AuthState>[];
        container.listen(
          authStateNotifierProvider,
          (_, next) => states.add(next),
          fireImmediately: false,
        );

        // ストリームに AppUser を流す
        authStreamController.add(tUser);
        await Future<void>.delayed(Duration.zero);

        expect(states.last, AuthState.authenticated(tUser));
      });

      test('ストリームが null を流したとき unauthenticated になる', () async {
        final container = makeContainer();
        final states = <AuthState>[];
        container.listen(
          authStateNotifierProvider,
          (_, next) => states.add(next),
          fireImmediately: false,
        );

        authStreamController.add(null);
        await Future<void>.delayed(Duration.zero);

        expect(states.last, const AuthState.unauthenticated());
      });
    });
  });
}
