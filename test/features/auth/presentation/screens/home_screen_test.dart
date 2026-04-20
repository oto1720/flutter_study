import 'package:flutter/material.dart';
import 'package:flutter_learn/features/auth/domain/entities/app_user.dart';
import 'package:flutter_learn/features/auth/presentation/providers/auth_state_notifier.dart';
import 'package:flutter_learn/features/auth/presentation/screens/home_screen.dart';
import 'package:flutter_learn/features/device/domain/entities/device_info.dart';
import 'package:flutter_learn/features/device/presentation/providers/device_info_providers.dart';
import 'package:flutter_learn/features/user_profile/domain/entities/user_profile.dart';
import 'package:flutter_learn/features/user_profile/presentation/providers/user_profile_providers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthStateNotifier extends AuthStateNotifier {
  FakeAuthStateNotifier(this._initialState);
  final AuthState _initialState;

  @override
  AuthState build() => _initialState;
}

// テスト用のダミープロフィール
const tProfile = UserProfile(
  id: 1,
  name: 'Test Name',
  email: 'test@api.com',
  phone: '000-0000',
  website: 'test.com',
  companyName: 'Test Corp',
);

Widget buildHomeScreen(AuthState initialState) {
  return ProviderScope(
    overrides: [
      authStateNotifierProvider.overrideWith(
        () => FakeAuthStateNotifier(initialState),
      ),
      // deviceInfoProvider をモックして MethodChannel を呼ばない
      deviceInfoProvider.overrideWith(
        (ref) async => const DeviceInfo(model: 'Test Device'),
      ),
      // userProfileProvider をモックして HTTP を呼ばない
      userProfileProvider(1).overrideWith(
        (ref) async => tProfile,
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
      await tester.pump();

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
      await tester.pump();

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
      await tester.pump();

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
      await tester.pump();

      expect(find.text('未設定'), findsOneWidget);
    });

    testWidgets('ログアウトボタンが表示される', (tester) async {
      await tester.pumpWidget(
        buildHomeScreen(const AuthState.authenticated(tUser)),
      );
      await tester.pump();

      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets('API プロフィールセクションが表示される', (tester) async {
      await tester.pumpWidget(
        buildHomeScreen(const AuthState.authenticated(tUser)),
      );
      // FutureProvider の完了を待つ
      await tester.pumpAndSettle();

      expect(find.text('API プロフィール (JSONPlaceholder)'), findsOneWidget);
      expect(find.text('Test Name'), findsOneWidget);
      expect(find.text('Test Corp'), findsOneWidget);
    });
  });
}
