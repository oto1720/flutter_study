import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:flutter_learn/features/user_profile/data/models/user_profile_dto.dart';

part 'user_api_client.g.dart';

/// JSONPlaceholder API クライアント
///
/// retrofit の @RestApi アノテーションにより、
/// HTTP リクエストコードを自動生成する。
/// このファイルだけが HTTP エンドポイントを知っている。
@RestApi(baseUrl: 'https://jsonplaceholder.typicode.com')
abstract class UserApiClient {
  factory UserApiClient(Dio dio, {String baseUrl}) = _UserApiClient;

  /// GET /users/{id} — ユーザープロフィールを取得
  @GET('/users/{id}')
  Future<UserProfileDto> getUser(@Path('id') int userId);
}
