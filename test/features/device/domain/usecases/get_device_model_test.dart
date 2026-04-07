import 'package:flutter_learn/core/error/failure.dart';
import 'package:flutter_learn/features/device/domain/entities/device_info.dart';
import 'package:flutter_learn/features/device/domain/repositories/device_info_repository.dart';
import 'package:flutter_learn/features/device/domain/usecases/get_device_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockDeviceInfoRepository extends Mock implements DeviceInfoRepository {}

void main() {
  late MockDeviceInfoRepository mockRepository;
  late GetDeviceModel useCase;

  setUp(() {
    mockRepository = MockDeviceInfoRepository();
    useCase = GetDeviceModel(mockRepository);
  });

  group('GetDeviceModel', () {
    const tDeviceInfo = DeviceInfo(model: 'iPhone');

    test('成功: Repository が Right を返すとき DeviceInfo を返す', () async {
      // Arrange
      when(() => mockRepository.getDeviceInfo())
          .thenAnswer((_) async => const Right(tDeviceInfo));

      // Act
      final result = await useCase();

      // Assert
      expect(result, const Right(tDeviceInfo));
      verify(() => mockRepository.getDeviceInfo()).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('失敗: Repository が Left を返すとき Failure を返す', () async {
      // Arrange
      const tFailure = Failure.unexpected();
      when(() => mockRepository.getDeviceInfo())
          .thenAnswer((_) async => const Left(tFailure));

      // Act
      final result = await useCase();

      // Assert
      expect(result, const Left(tFailure));
      verify(() => mockRepository.getDeviceInfo()).called(1);
    });
  });
}
