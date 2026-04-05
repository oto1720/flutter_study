import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';

/// アプリ内のユーザーを表すエンティティ
///
/// Firebase を一切 import しない純粋な Dart クラス。
/// Firebase を別サービスに変えても、このファイルは変更不要。
@freezed
class AppUser with _$AppUser {
  const factory AppUser({
    required String id,
    required String email,
    String? displayName,
    String? photoUrl,
  }) = _AppUser;
}
