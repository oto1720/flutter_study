# Phase 11: バックエンド API 連携 — dio・retrofit・キャッシュ・エラーハンドリング

## 概要

Firebase 以外の REST API との連携を実装する。
「どう API を叩くか」より「**どう設計するか**」が重要で、
Clean Architecture の層に適切に責務を割り当てることで、
テスタブルで変更に強いコードができる。

この Phase では [JSONPlaceholder](https://jsonplaceholder.typicode.com) を
モック API として使い、ユーザープロフィールを取得する。

---

## 1. パッケージ: dio と retrofit

### dio — 高機能 HTTP クライアント

```dart
// 素の http パッケージより機能が豊富
Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 5),  // 接続タイムアウト
  receiveTimeout: const Duration(seconds: 10), // レスポンスタイムアウト
))..interceptors.add(LogInterceptor());         // ログ出力
```

| 機能 | 説明 |
|---|---|
| `BaseOptions` | ベース URL・タイムアウト・ヘッダーを一元設定 |
| `Interceptor` | リクエスト/レスポンスを横断的に処理（ログ・認証トークン付与など） |
| `DioException` | ネットワークエラーを細かく分類 |

### retrofit — 型安全な API クライアント生成

```dart
// アノテーションで HTTP 定義を書く
@RestApi(baseUrl: 'https://jsonplaceholder.typicode.com')
abstract class UserApiClient {
  factory UserApiClient(Dio dio) = _UserApiClient; // コード生成

  @GET('/users/{id}')
  Future<UserProfileDto> getUser(@Path('id') int userId);
}
```

`dart run build_runner build` でリクエストコードを自動生成する。
URLのスペルミスやレスポンス型の不整合をコンパイル時に検知できる。

---

## 2. Clean Architecture への統合

### 層ごとの責務

```
DataSource 層  → retrofit の UserApiClient を呼ぶ
                 HTTP エンドポイントを知っているのはここだけ

RepositoryImpl → DioException を Failure に変換
                 Domain 層は DioException を知らない

UseCase        → Repository インターフェースを呼ぶだけ
                 HTTP を知らない純粋な Dart

Provider       → UseCase を呼び、AsyncValue として UI に渡す
                 キャッシュ戦略もここで設定

UI             → AsyncValue.when で loading/error/data を安全にハンドリング
```

### ファイル構成

```
lib/
├── core/network/
│   └── dio_provider.dart          # Dio インスタンス（タイムアウト・ログ設定）
└── features/user_profile/
    ├── domain/
    │   ├── entities/user_profile.dart         # 純粋 Dart エンティティ
    │   ├── repositories/user_profile_repository.dart
    │   └── usecases/get_user_profile.dart
    ├── data/
    │   ├── models/user_profile_dto.dart        # JSON DTO（json_serializable）
    │   ├── datasources/user_api_client.dart    # retrofit @RestApi
    │   └── repositories/user_profile_repository_impl.dart
    └── presentation/
        └── providers/user_profile_providers.dart
```

---

## 3. DTO パターン — Data 層と Domain 層の型を分離する

### なぜ分けるか

```dart
// ❌ Entity に直接 fromJson を書く（Domain が JSON を知ってしまう）
class UserProfile {
  factory UserProfile.fromJson(Map<String, dynamic> json) { ... }
}

// ✅ DTO を介して変換（Domain は JSON を知らない）
class UserProfileDto {                    // ← Data 層の型
  factory UserProfileDto.fromJson(...)   // ← JSON を知っている
  UserProfile toEntity() { ... }         // ← Domain の型に変換
}
```

### json_serializable で自動生成

```dart
@JsonSerializable()
class UserProfileDto {
  final int id;
  final String name;
  final String email;

  // アノテーションを付けると fromJson / toJson が自動生成される
  factory UserProfileDto.fromJson(Map<String, dynamic> json) =>
      _$UserProfileDtoFromJson(json);
}
```

---

## 4. DioException → Failure の変換

DioException にはエラーの種類を表す `type` フィールドがある。

```dart
Failure _mapDioException(DioException e) {
  return switch (e.type) {
    // タイムアウト（接続・送信・受信）
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => const Failure.network(),

    // HTTP 4xx / 5xx レスポンス
    DioExceptionType.badResponse =>
      Failure.server(statusCode: e.response?.statusCode ?? 0),

    // Wi-Fi オフなど接続自体が失敗
    DioExceptionType.connectionError => const Failure.network(),

    // その他
    _ => const Failure.unexpected(),
  };
}
```

### Failure.server を追加した理由

```dart
// failure.dart に追加
const factory Failure.server({required int statusCode}) = ServerFailure;
```

auth 系のエラー（`Failure.auth`）と HTTP エラー（`Failure.server`）を
型で区別することで、UI 側でメッセージを適切に出し分けられる。

Sealed class（freezed）なので追加後はコンパイルエラーが出て、
既存の switch 文への追加漏れを防げる。

---

## 5. キャッシュ戦略 — `keepAlive: true`

```dart
// keepAlive: true をつけると…
@Riverpod(keepAlive: true)
Future<UserProfile> userProfile(Ref ref, int userId) async { ... }
```

```
最初に userProfileProvider(1) を watch したとき
  → HTTP リクエストを送信して UserProfile をキャッシュ

別の画面に遷移して HomeScreen が破棄されたとき
  → keepAlive: true なのでプロバイダーは破棄されない

HomeScreen に戻ってきたとき
  → キャッシュから即座に UserProfile を返す（HTTP なし）
```

| オプション | 動作 |
|---|---|
| `keepAlive: false`（デフォルト） | ウィジェット破棄時にプロバイダーも破棄・再フェッチ |
| `keepAlive: true` | プロバイダーをアプリ終了まで保持・再フェッチなし |

---

## 6. UI での表示 — AsyncValue.when

```dart
final profileAsync = ref.watch(userProfileProvider(1));

profileAsync.when(
  loading: () => const CircularProgressIndicator(),
  error: (e, _) => Card(/* エラー表示 */),
  data: (profile) => Column(
    children: [
      _InfoTile(label: '名前', value: profile.name),
      _InfoTile(label: '会社名', value: profile.companyName),
    ],
  ),
),
```

`when` を使うと loading / error / data の全ケースを書かないとコンパイルエラーになる。
`maybeWhen` は一部だけ書いて残りを `orElse` でまとめる場合に使う。

---

## 7. テスト戦略

### UseCase テスト（MockRepository）

```dart
class MockUserProfileRepository extends Mock
    implements UserProfileRepository {}

when(() => mockRepository.getUserProfile(1))
    .thenAnswer((_) async => const Right(tProfile));
```

### Repository テスト（MockApiClient）

```dart
class MockUserApiClient extends Mock implements UserApiClient {}

// タイムアウトシナリオ
when(() => mockApiClient.getUser(any())).thenThrow(
  DioException(type: DioExceptionType.connectionTimeout, ...),
);
final result = await repository.getUserProfile(1);
expect(result, const Left(Failure.network()));
```

### Widget テスト（Provider オーバーライド）

```dart
ProviderScope(
  overrides: [
    // HTTP を呼ばず、テスト用データを直接返す
    userProfileProvider(1).overrideWith((ref) async => tProfile),
  ],
  child: const MaterialApp(home: HomeScreen()),
)
```

---

## 8. インターセプター — 横断的な処理

```dart
// 認証トークンを全リクエストに自動付与する例
class AuthInterceptor extends Interceptor {
  final String token;
  AuthInterceptor(this.token);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }
}

dio.interceptors.add(AuthInterceptor(token));
```

インターセプターを使うと、個々の API 呼び出しに認証コードを書かなくて済む。

---

## 9. 完了チェックリスト

- [x] dio でタイムアウト・ログが設定されている
- [x] retrofit で型安全な API クライアントが生成されている
- [x] DTO → Entity 変換が Data 層に閉じ込められている
- [x] DioException → Failure の変換が RepositoryImpl にある
- [x] `keepAlive: true` でキャッシュが効いている
- [x] HomeScreen に API プロフィールが表示される
- [x] UseCase / Repository のテストが通っている
- [x] Widget テストが Provider オーバーライドで HTTP を呼ばない
