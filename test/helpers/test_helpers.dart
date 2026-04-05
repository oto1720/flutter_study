import 'package:flutter_learn/features/auth/domain/entities/app_user.dart';
import 'package:flutter_learn/features/auth/domain/repositories/auth_repository.dart';
import 'package:mocktail/mocktail.dart';

/// AuthRepository のモック
/// mocktail を使うことでコード生成不要で作成できる
class MockAuthRepository extends Mock implements AuthRepository {}

/// テスト用のサンプルユーザー
const tUser = AppUser(
  id: 'test-uid-123',
  email: 'test@example.com',
  displayName: 'Test User',
);
