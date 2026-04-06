import 'package:flutter/material.dart';
import 'package:flutter_learn/features/auth/domain/entities/app_user.dart';
import 'package:flutter_learn/features/auth/presentation/providers/auth_state_notifier.dart';
import 'package:flutter_learn/features/auth/presentation/screens/home_screen.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthStateNotifier extends AuthStateNotifier {
  FakeAuthStateNotifier(this._initialState);
  final AuthState _initialState;

  @override
  AuthState build() => _initialState;
}

Widget buildHomeScreen(AuthState initialState) {
  return ProviderScope(
    overrides: [
      authStateNotifierProvider.overrideWith(
        () => FakeAuthStateNotifier(initialState),
      ),
    ],
    child: const MaterialApp(home: HomeScreen()),
  );
}

void main() {
  const tUser = AppUser(
    id: 'uid-001',
    email: 'test@example.com',
    displayName: 'Test User',
  );

  group('HomeScreen', () {
    testWidgets('authenticated 状態のとき ユーザー情報が表示される', (tester) async {
      await tester.pumpWidget(
        buildHomeScreen(const AuthState.authenticated(tUser)),
      );

      expect(find.text('ホーム'), findsOneWidget);
      expect(find.text('メールアドレス'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);
      expect(find.text('表示名'), findsOneWidget);
      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('ユーザーID'), findsOneWidget);
    });

    testWidgets('authenticated 状態のとき アバターにイニシャルが表示される', (tester) async {
      await tester.pumpWidget(
        buildHomeScreen(const AuthState.authenticated(tUser)),
      );

      // displayName の先頭文字が大文字で表示される
      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('displayName が null のとき アバターに ? が表示される', (tester) async {
      const userWithoutName = AppUser(
        id: 'uid-002',
        email: 'noname@example.com',
      );
      await tester.pumpWidget(
        buildHomeScreen(const AuthState.authenticated(userWithoutName)),
      );

      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('displayName が未設定のとき 「未設定」と表示される', (tester) async {
      const userWithoutName = AppUser(
        id: 'uid-002',
        email: 'noname@example.com',
      );
      await tester.pumpWidget(
        buildHomeScreen(const AuthState.authenticated(userWithoutName)),
      );

      expect(find.text('未設定'), findsOneWidget);
    });

    testWidgets('ログアウトボタンが表示される', (tester) async {
      await tester.pumpWidget(
        buildHomeScreen(const AuthState.authenticated(tUser)),
      );

      expect(find.byIcon(Icons.logout), findsOneWidget);
    });
  });
}
