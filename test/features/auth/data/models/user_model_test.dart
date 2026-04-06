import 'package:flutter_learn/features/auth/data/models/user_model.dart';
import 'package:flutter_learn/features/auth/domain/entities/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserModel', () {
    group('toEntity()', () {
      test('全フィールドが揃っているとき AppUser に変換される', () {
        const model = UserModel(
          id: 'uid-001',
          email: 'test@example.com',
          displayName: 'Test User',
          photoUrl: 'https://example.com/photo.jpg',
        );

        final entity = model.toEntity();

        expect(entity, isA<AppUser>());
        expect(entity.id, 'uid-001');
        expect(entity.email, 'test@example.com');
        expect(entity.displayName, 'Test User');
        expect(entity.photoUrl, 'https://example.com/photo.jpg');
      });

      test('オプションフィールドが null のとき AppUser に null が引き継がれる', () {
        const model = UserModel(
          id: 'uid-002',
          email: 'noname@example.com',
        );

        final entity = model.toEntity();

        expect(entity.id, 'uid-002');
        expect(entity.email, 'noname@example.com');
        expect(entity.displayName, isNull);
        expect(entity.photoUrl, isNull);
      });
    });
  });
}
