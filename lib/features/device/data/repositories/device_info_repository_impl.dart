import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_learn/core/error/failure.dart';
import 'package:flutter_learn/features/device/data/datasources/device_info_data_source.dart';
import 'package:flutter_learn/features/device/domain/entities/device_info.dart';
import 'package:flutter_learn/features/device/domain/repositories/device_info_repository.dart';

/// DeviceInfoRepository の MethodChannel 実装
///
/// PlatformException（ネイティブ側のエラー）を Failure に変換する。
/// Domain 層は PlatformException を知らないため、ここで変換する。
class DeviceInfoRepositoryImpl implements DeviceInfoRepository {
  const DeviceInfoRepositoryImpl(this._dataSource);

  final DeviceInfoDataSource _dataSource;

  @override
  Future<Either<Failure, DeviceInfo>> getDeviceInfo() async {
    try {
      final model = await _dataSource.getDeviceModel();
      return Right(DeviceInfo(model: model));
    } on PlatformException {
      return const Left(Failure.unexpected());
    }
  }
}
