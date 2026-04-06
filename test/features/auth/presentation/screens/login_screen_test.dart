import 'package:flutter/material.dart';
import 'package:flutter_learn/core/error/failure.dart';
import 'package:flutter_learn/features/auth/presentation/providers/auth_state_notifier.dart';
import 'package:flutter_learn/features/auth/presentation/screens/login_screen.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// テスト用に任意の初期状態を注入できる Notifier
/// signInWithEmail / signInWithGoogle をオーバーライドして
/// 実際のプロバイダーチェーン（Firebase）を呼び出さないようにする
class FakeAuthStateNotifier extends AuthStateNotifier {
  FakeAuthStateNotifier(this._initialState);
  final AuthState _initialState;

  @override
  AuthState build() => _initialState;

  @override
  Future<void> signInWithEmail(String email, String password) async {
    // テスト内では何もしない（実プロバイダーを呼ばない）
  }

  @override
  Future<void> signInWithGoogle() async {
    // テスト内では何もしない
  }
}

/// LoginScreen を ProviderScope でラップして pump するヘルパー
Widget buildLoginScreen(AuthState initialState) {
  return ProviderScope(
    overrides: [
      authStateNotifierProvider.overrideWith(
        () => FakeAuthStateNotifier(initialState),
      ),
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

    testWidgets('バリデーション: パスワードが6文字未満のときエラーメッセージが表示される', (tester) async {
      await tester.pumpWidget(
        buildLoginScreen(const AuthState.unauthenticated()),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'メールアドレス'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'パスワード'),
        '123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'ログイン'));
      await tester.pump();

      expect(find.text('パスワードは6文字以上で入力してください'), findsOneWidget);
    });

    testWidgets('バリデーション通過後にサインインが実行される', (tester) async {
      await tester.pumpWidget(
        buildLoginScreen(const AuthState.unauthenticated()),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'メールアドレス'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'パスワード'),
        'password123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'ログイン'));
      await tester.pump();

      // FakeAuthStateNotifier では signInWithEmail が何もしないため、エラーは出ない
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('Google でログインボタンをタップできる', (tester) async {
      await tester.pumpWidget(
        buildLoginScreen(const AuthState.unauthenticated()),
      );

      await tester.tap(find.text('Google でログイン'));
      await tester.pump();

      // FakeAuthStateNotifier では signInWithGoogle が何もしないため、エラーは出ない
      expect(find.byType(SnackBar), findsNothing);
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

    testWidgets('error(AuthFailure) 状態のとき SnackBar にエラーメッセージが表示される',
        (tester) async {
      await tester.pumpWidget(
        buildLoginScreen(const AuthState.unauthenticated()),
      );

      // ref.listen は状態「変化」を検知するため、別の状態から error に遷移させる
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LoginScreen)),
      );
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

    testWidgets('error(NetworkFailure) 状態のとき SnackBar にネットワークエラーが表示される',
        (tester) async {
      await tester.pumpWidget(
        buildLoginScreen(const AuthState.unauthenticated()),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(LoginScreen)),
      );
      container
          .read(authStateNotifierProvider.notifier)
          // ignore: invalid_use_of_protected_member
          .state = const AuthState.error(Failure.network());
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('ネットワークエラーが発生しました'), findsOneWidget);
    });

    testWidgets('error(UnexpectedFailure) 状態のとき SnackBar に予期しないエラーが表示される',
        (tester) async {
      await tester.pumpWidget(
        buildLoginScreen(const AuthState.unauthenticated()),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(LoginScreen)),
      );
      container
          .read(authStateNotifierProvider.notifier)
          // ignore: invalid_use_of_protected_member
          .state = const AuthState.error(Failure.unexpected());
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('予期しないエラーが発生しました'), findsOneWidget);
    });
  });
}
