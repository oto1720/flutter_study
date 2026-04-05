import 'package:flutter/material.dart';
import 'package:flutter_learn/core/error/failure.dart';
import 'package:flutter_learn/features/auth/presentation/providers/auth_state_notifier.dart';
import 'package:flutter_learn/features/auth/presentation/screens/login_screen.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// テスト用に任意の初期状態を注入できる Notifier
class FakeAuthStateNotifier extends AuthStateNotifier {
  FakeAuthStateNotifier(this._initialState);
  final AuthState _initialState;

  @override
  AuthState build() => _initialState;
}

/// LoginScreen を ProviderScope でラップして pump するヘルパー
Widget buildLoginScreen(AuthState initialState) {
  return ProviderScope(
    overrides: [
      authStateNotifierProvider.overrideWith(() =>
          FakeAuthStateNotifier(initialState)),
    ],
    child: const MaterialApp(home: LoginScreen()),
  );
}

void main() {
  group('LoginScreen', () {
    testWidgets('初期表示: フォームとボタンが表示される', (tester) async {
      await tester.pumpWidget(
        buildLoginScreen(const AuthState.unauthenticated()),
      );

      expect(find.text('ログイン'), findsWidgets);
      expect(find.text('メールアドレス'), findsOneWidget);
      expect(find.text('パスワード'), findsOneWidget);
      expect(find.text('Google でログイン'), findsOneWidget);
      expect(find.text('アカウントを作成する'), findsOneWidget);
    });

    testWidgets('バリデーション: 空のまま送信するとエラーメッセージが表示される', (tester) async {
      await tester.pumpWidget(
        buildLoginScreen(const AuthState.unauthenticated()),
      );

      // ログインボタンをタップ（フォームは空）
      await tester.tap(find.widgetWithText(FilledButton, 'ログイン'));
      await tester.pump();

      expect(find.text('メールアドレスを入力してください'), findsOneWidget);
      expect(find.text('パスワードを入力してください'), findsOneWidget);
    });

    testWidgets('バリデーション: 不正なメールアドレスでエラーメッセージが表示される', (tester) async {
      await tester.pumpWidget(
        buildLoginScreen(const AuthState.unauthenticated()),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'メールアドレス'),
        'not-an-email',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'ログイン'));
      await tester.pump();

      expect(find.text('正しいメールアドレスを入力してください'), findsOneWidget);
    });

    testWidgets('loading 状態のとき ボタンが無効になる', (tester) async {
      await tester.pumpWidget(
        buildLoginScreen(const AuthState.loading()),
      );

      // FilledButton が disabled（onPressed == null）になっているか確認
      final button = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('error 状態のとき SnackBar が表示される', (tester) async {
      await tester.pumpWidget(
        buildLoginScreen(
          const AuthState.error(
            Failure.auth(message: 'パスワードが間違っています', code: 'wrong-password'),
          ),
        ),
      );

      // ref.listen は状態「変化」を検知するため、
      // 初期状態が error でも変化がないと SnackBar は出ない。
      // → 別の状態から error に遷移させる
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LoginScreen)),
      );
      container
          .read(authStateNotifierProvider.notifier)
          // ignore: invalid_use_of_protected_member
          .state = const AuthState.unauthenticated();
      await tester.pump();
      container
          .read(authStateNotifierProvider.notifier)
          // ignore: invalid_use_of_protected_member
          .state = const AuthState.error(
        Failure.auth(message: 'パスワードが間違っています', code: 'wrong-password'),
      );
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('パスワードが間違っています'), findsOneWidget);
    });
  });
}
