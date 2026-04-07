import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_learn/features/device/data/datasources/device_info_data_source.dart';
import 'package:flutter_learn/features/device/data/repositories/device_info_repository_impl.dart';
import 'package:flutter_learn/features/device/domain/entities/device_info.dart';
import 'package:flutter_learn/features/device/domain/repositories/device_info_repository.dart';
import 'package:flutter_learn/features/device/domain/usecases/get_device_model.dart';

part 'device_info_providers.g.dart';

// ---------------------------------------------------------------------------
// Data 層
// ---------------------------------------------------------------------------

@riverpod
DeviceInfoDataSource deviceInfoDataSource(Ref ref) =>
    DeviceInfoDataSourceImpl();

@riverpod
DeviceInfoRepository deviceInfoRepository(Ref ref) =>
    DeviceInfoRepositoryImpl(ref.watch(deviceInfoDataSourceProvider));

// ---------------------------------------------------------------------------
// UseCase
// ---------------------------------------------------------------------------

@riverpod
GetDeviceModel getDeviceModelUseCase(Ref ref) =>
    GetDeviceModel(ref.watch(deviceInfoRepositoryProvider));

// ---------------------------------------------------------------------------
// 非同期 Provider: UI から直接 watch する
// ---------------------------------------------------------------------------

@riverpod
Future<DeviceInfo> deviceInfo(Ref ref) async {
  final useCase = ref.watch(getDeviceModelUseCaseProvider);
  final result = await useCase();
  return result.fold(
    // Failure は例外として投げる → AsyncValue.error として UI に届く
    (failure) => throw failure,
    (info) => info,
  );
}
