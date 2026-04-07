/// デバイス情報エンティティ
///
/// ネイティブ層から取得したデバイス情報を表すシンプルなクラス。
/// Domain 層に属するため、Flutter / Firebase を一切知らない。
class DeviceInfo {
  const DeviceInfo({required this.model});

  final String model;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DeviceInfo && other.model == model;

  @override
  int get hashCode => model.hashCode;

  @override
  String toString() => 'DeviceInfo(model: $model)';
}
