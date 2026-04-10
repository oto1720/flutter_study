import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dio_provider.g.dart';

/// Dio インスタンスを提供する Provider
///
/// タイムアウト・リトライなどの設定を一元管理する。
/// テスト時はこの Provider を override して MockDio を注入できる。
@riverpod
Dio dio(Ref ref) {
  final dio = Dio(
    BaseOptions(
      // 接続確立のタイムアウト
      connectTimeout: const Duration(seconds: 5),
      // レスポンス受信のタイムアウト
      receiveTimeout: const Duration(seconds: 10),
      // リクエスト送信のタイムアウト
      sendTimeout: const Duration(seconds: 5),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // ✅ LogInterceptor: デバッグ時にリクエスト・レスポンスをコンソール出力
  // リリースビルドでは kDebugMode で制御する
  dio.interceptors.add(
    LogInterceptor(
      requestBody: true,
      responseBody: true,
    ),
  );

  return dio;
}
