import 'package:flutter/material.dart';
import 'package:flutter_learn/core/error/failure.dart';
import 'package:flutter_learn/features/auth/presentation/providers/auth_state_notifier.dart';
import 'package:flutter_learn/features/auth/presentation/screens/register_screen.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthStateNotifier extends AuthStateNotifier {
  FakeAuthStateNotifier(this._initialState);
  final AuthState _initialState;

  @override
  AuthState build() => _initialState;
}

Widget buildRegisterScreen(AuthState initialState) {
  return ProviderScope(
    overrides: [
      authStateNotifierProvider.overrideWith(
        () => FakeAuthStateNotifier(initialState),
      ),
    ],
    child: const MaterialApp(home: RegisterScreen()),
  );
}

void main() {
  group('RegisterScreen', () {
    testWidgets('初期表示: フォームとボタンが表示される', (tester) async {
      await tester.pumpWidget(
        buildRegisterScreen(const AuthState.unauthenticated()),
      );

      expect(find.text('アカウント作成'), findsOneWidget);
      expect(find.text('メールアドレス'), findsOneWidget);
      expect(find.text('パスワード'), findsOneWidget);
      expect(find.text('パスワード（確認）'), findsOneWidget);
      expect(find.text('アカウントを作成する'), findsOneWidget);
    });

    testWidgets('バリデーション: 空のまま送信するとエラーメッセージが表示される', (tester) async {
      await tester.pumpWidget(
        buildRegisterScreen(const AuthState.unauthenticated()),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'アカウントを作成する'));
      await tester.pump();

      expect(find.text('メールアドレスを入力してください'), findsOneWidget);
      expect(find.text('パスワードを入力してください'), findsOneWidget);
    });

    testWidgets('バリデーション: パスワードが6文字未満のときエラーメッセージが表示される', (tester) async {
      await tester.pumpWidget(
        buildRegisterScreen(const AuthState.unauthenticated()),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'メールアドレス'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'パスワード'),
        '123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'アカウントを作成する'));
      await tester.pump();

      expect(find.text('パスワードは6文字以上で入力してください'), findsOneWidget);
    });

    testWidgets('バリデーション: パスワードが一致しないときエラーメッセージが表示される', (tester) async {
      await tester.pumpWidget(
        buildRegisterScreen(const AuthState.unauthenticated()),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'メールアドレス'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'パスワード'),
        'password123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'パスワード（確認）'),
        'different',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'アカウントを作成する'));
      await tester.pump();

      expect(find.text('パスワードが一致しません'), findsOneWidget);
    });

    testWidgets('loading 状態のとき ボタンが無効になる', (tester) async {
      await tester.pumpWidget(
        buildRegisterScreen(const AuthState.loading()),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('error 状態のとき SnackBar が表示される', (tester) async {
      await tester.pumpWidget(
        buildRegisterScreen(const AuthState.unauthenticated()),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(RegisterScreen)),
      );
      container
          .read(authStateNotifierProvider.notifier)
          // ignore: invalid_use_of_protected_member
          .state = const AuthState.error(
        Failure.auth(message: 'このメールアドレスはすでに使用されています', code: 'email-already-in-use'),
      );
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('このメールアドレスはすでに使用されています'), findsOneWidget);
    });
  });
}
