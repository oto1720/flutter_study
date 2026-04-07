import 'package:flutter/services.dart';

/// デバイス情報データソースのインターフェース
///
/// MethodChannel を直接呼び出す責務を持つ層。
/// テスト時は FakeDeviceInfoDataSource に差し替えられる。
abstract interface class DeviceInfoDataSource {
  Future<String> getDeviceModel();
}

/// DeviceInfoDataSource の MethodChannel 実装
///
/// このクラスだけが MethodChannel を知っている。
/// PlatformException はそのまま上位（RepositoryImpl）に伝える。
class DeviceInfoDataSourceImpl implements DeviceInfoDataSource {
  // チャンネル名はネイティブ側（iOS/Android）と一致させる
  static const _channel = MethodChannel('com.example.flutter_study/device');

  @override
  Future<String> getDeviceModel() async {
    final model = await _channel.invokeMethod<String>('getDeviceModel');
    return model ?? 'Unknown';
  }
}
