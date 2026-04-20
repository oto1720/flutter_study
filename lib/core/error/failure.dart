import 'package:freezed_annotation/freezed_annotation.dart';

part 'failure.freezed.dart';

/// アプリ全体で使用するエラーの型定義
///
/// Sealed class にすることで、UI 側で switch 文による
/// 全ケース網羅チェックをコンパイル時に強制できる。
@freezed
sealed class Failure with _$Failure {
  /// Firebase Auth のエラー（wrong-password, user-not-found など）
  const factory Failure.auth({
    required String message,
    required String code,
  }) = AuthFailure;

  /// ネットワーク接続エラー
  const factory Failure.network() = NetworkFailure;

  /// サーバーエラー（HTTP 4xx / 5xx）
  const factory Failure.server({required int statusCode}) = ServerFailure;

  /// 予期しないエラー（上記以外の例外）
  const factory Failure.unexpected() = UnexpectedFailure;
}
