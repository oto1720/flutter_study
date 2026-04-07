import 'package:fpdart/fpdart.dart';
import 'package:flutter_learn/core/error/failure.dart';
import 'package:flutter_learn/features/device/domain/entities/device_info.dart';
import 'package:flutter_learn/features/device/domain/repositories/device_info_repository.dart';

/// デバイスモデル名取得 UseCase
///
/// Repository インターフェースを通じてデバイス情報を取得する。
/// MethodChannel の存在を知らない — それは Data 層の責務。
class GetDeviceModel {
  const GetDeviceModel(this._repository);

  final DeviceInfoRepository _repository;

  Future<Either<Failure, DeviceInfo>> call() => _repository.getDeviceInfo();
}
