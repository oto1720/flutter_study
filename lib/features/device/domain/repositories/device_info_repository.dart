import 'package:fpdart/fpdart.dart';
import 'package:flutter_learn/core/error/failure.dart';
import 'package:flutter_learn/features/device/domain/entities/device_info.dart';

/// デバイス情報リポジトリの契約（インターフェース）
///
/// Domain 層はこの抽象インターフェースのみを知っている。
/// 実際の MethodChannel 実装は Data 層の DeviceInfoRepositoryImpl が担う。
/// テスト時は Mock / Fake に差し替える。
abstract interface class DeviceInfoRepository {
  /// デバイス情報を取得する
  Future<Either<Failure, DeviceInfo>> getDeviceInfo();
}
