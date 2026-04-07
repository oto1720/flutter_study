import 'package:flutter/services.dart';
import 'package:flutter_learn/features/device/data/datasources/device_info_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // MethodChannel をテストするには TestWidgetsFlutterBinding が必要
  TestWidgetsFlutterBinding.ensureInitialized();

  late DeviceInfoDataSourceImpl dataSource;
  const channel = MethodChannel('com.example.flutter_study/device');

  setUp(() {
    dataSource = DeviceInfoDataSourceImpl();
  });

  tearDown(() {
    // テスト後にモックハンドラをクリア
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('DeviceInfoDataSource', () {
    test('getDeviceModel: ネイティブが文字列を返すとき、その値を返す', () async {
      // Arrange: MethodChannel をモックする
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getDeviceModel') return 'Test iPhone';
        return null;
      });

      // Act
      final result = await dataSource.getDeviceModel();

      // Assert
      expect(result, 'Test iPhone');
    });

    test('getDeviceModel: ネイティブが null を返すとき "Unknown" を返す', () async {
      // Arrange
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);

      // Act
      final result = await dataSource.getDeviceModel();

      // Assert
      expect(result, 'Unknown');
    });

    test('getDeviceModel: ネイティブが PlatformException を投げるとき例外が伝播する', () async {
      // Arrange
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'UNAVAILABLE', message: 'Device info unavailable');
      });

      // Act & Assert
      expect(
        () => dataSource.getDeviceModel(),
        throwsA(isA<PlatformException>()),
      );
    });
  });
}
