import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_learn/core/network/dio_provider.dart';
import 'package:flutter_learn/features/user_profile/data/datasources/user_api_client.dart';
import 'package:flutter_learn/features/user_profile/data/repositories/user_profile_repository_impl.dart';
import 'package:flutter_learn/features/user_profile/domain/entities/user_profile.dart';
import 'package:flutter_learn/features/user_profile/domain/repositories/user_profile_repository.dart';
import 'package:flutter_learn/features/user_profile/domain/usecases/get_user_profile.dart';

part 'user_profile_providers.g.dart';

// ---------------------------------------------------------------------------
// Data 層
// ---------------------------------------------------------------------------

@riverpod
UserApiClient userApiClient(Ref ref) =>
    UserApiClient(ref.watch(dioProvider));

@riverpod
UserProfileRepository userProfileRepository(Ref ref) =>
    UserProfileRepositoryImpl(ref.watch(userApiClientProvider));

// ---------------------------------------------------------------------------
// UseCase
// ---------------------------------------------------------------------------

@riverpod
GetUserProfile getUserProfileUseCase(Ref ref) =>
    GetUserProfile(ref.watch(userProfileRepositoryProvider));

// ---------------------------------------------------------------------------
// ✅ keepAlive: キャッシュ戦略
//
// keepAlive: true にすると Provider が最初に読み込まれた後、
// ウィジェットが破棄されても値をメモリに保持し続ける。
// 同じ userId で再リクエストが来ても HTTP を送信しない。
// ---------------------------------------------------------------------------

@Riverpod(keepAlive: true)
Future<UserProfile> userProfile(Ref ref, int userId) async {
  final useCase = ref.watch(getUserProfileUseCaseProvider);
  final result = await useCase(userId);
  return result.fold(
    // Failure は例外として投げる → AsyncValue.error として UI に届く
    (failure) => throw failure,
    (profile) => profile,
  );
}
