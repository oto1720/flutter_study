# Phase 10: MethodChannel — Flutter とネイティブの橋渡し

## 概要

Flutter は Dart で書かれており、標準では iOS / Android のネイティブ API に直接アクセスできない。
`MethodChannel` は **Flutter（Dart）側** と **ネイティブ（Swift / Kotlin）側** をつなぐ仕組みで、
ネイティブにしかできない処理（デバイス情報取得、カメラ、センサーなど）を呼び出せるようにする。

この Phase では `getDeviceModel` メソッドを通じて MethodChannel の基本的な使い方を学ぶ。

---

## 1. MethodChannel とは何か

```
Flutter (Dart)                     ネイティブ (Swift / Kotlin)
┌─────────────────┐                ┌─────────────────────────┐
│                 │  invokeMethod  │                         │
│  DataSource     │ ─────────────► │  MethodChannel Handler  │
│ (Dart)          │ ◄───────────── │  (Swift / Kotlin)       │
│                 │  result        │                         │
└─────────────────┘                └─────────────────────────┘
        ↑ チャンネル名で識別
        "com.example.flutter_study/device"
```

### 通信の流れ

```
1. Flutter 側: channel.invokeMethod('getDeviceModel')
2. ネイティブ側: setMethodCallHandler でハンドラが呼ばれる
3. ネイティブ側: result.success("iPhone") で返す
4. Flutter 側: Future が完了し、"iPhone" が得られる
```

### なぜチャンネル名に逆ドメインを使うか

```
"com.example.flutter_study/device"
  ^^^^^^^^^^^^^^^^^^^^^^^^^  ^^^^
  アプリ識別子（衝突防止）    チャンネル識別子

プラグインが増えると同じ名前のチャンネルが衝突する可能性がある。
逆ドメイン記法でグローバルに一意性を担保する。
```

---

## 2. MethodChannel を Clean Architecture に統合する

### 問題: MethodChannel をどこに書くか

```dart
// ❌ ViewModel / Notifier に直接書く
class AuthStateNotifier extends ... {
  static const _channel = MethodChannel('...');
  Future<void> someMethod() async {
    await _channel.invokeMethod('getDeviceModel'); // ← Notifier がチャンネルを知ってしまう
  }
}
```

**Notifier がネイティブの詳細を知る必要はない。** Domain 層も同様。

### 解決: DataSource 層に閉じ込める

```
DataSource（MethodChannel 呼び出し）
    ↑ 依存
RepositoryImpl（PlatformException → Failure 変換）
    ↑ 依存
UseCase（純粋な Dart、ネイティブを知らない）
    ↑ 依存
Provider → UI
```

このプロジェクトの実装:

```
lib/features/device/
├── domain/
│   ├── entities/device_info.dart              # ネイティブ不要
│   ├── repositories/device_info_repository.dart
│   └── usecases/get_device_model.dart
├── data/
│   ├── datasources/device_info_data_source.dart   ← MethodChannel はここだけ
│   └── repositories/device_info_repository_impl.dart  ← PlatformException 変換
└── presentation/
    └── providers/device_info_providers.dart
```

---

## 3. Flutter 側の実装

### DataSource（MethodChannel の唯一の使用箇所）

```dart
class DeviceInfoDataSourceImpl implements DeviceInfoDataSource {
  // チャンネル名はネイティブ側と完全に一致させる（大文字小文字も含む）
  static const _channel = MethodChannel('com.example.flutter_study/device');

  @override
  Future<String> getDeviceModel() async {
    // invokeMethod は Future を返す
    // ネイティブが result.notImplemented() を返すと MissingPluginException
    // ネイティブが result.error() を返すと PlatformException
    final model = await _channel.invokeMethod<String>('getDeviceModel');
    return model ?? 'Unknown';
  }
}
```

### RepositoryImpl（例外変換）

```dart
class DeviceInfoRepositoryImpl implements DeviceInfoRepository {
  @override
  Future<Either<Failure, DeviceInfo>> getDeviceInfo() async {
    try {
      final model = await _dataSource.getDeviceModel();
      return Right(DeviceInfo(model: model));
    } on PlatformException {
      // PlatformException は ネイティブ側のエラー
      // Domain 層は PlatformException を知らないので、ここで Failure に変換
      return const Left(Failure.unexpected());
    }
  }
}
```

### UI（AsyncValue で安全に表示）

```dart
final deviceInfoAsync = ref.watch(deviceInfoProvider);

_InfoTile(
  label: 'デバイス',
  value: deviceInfoAsync.when(
    data: (info) => info.model,
    loading: () => '取得中...',
    error: (_, __) => '取得失敗',
  ),
),
```

---

## 4. Android 実装（Kotlin）

`android/app/src/main/kotlin/.../MainActivity.kt`:

```kotlin
class MainActivity : FlutterActivity() {
    private val channel = "com.example.flutter_study/device"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDeviceModel" -> {
                        // Build クラスで端末情報を取得
                        // 例: "Google Pixel 8" / "samsung SM-G991B"
                        result.success("${Build.MANUFACTURER} ${Build.MODEL}")
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
```

### result の種類

| 呼び出し | 意味 | Dart 側 |
|---|---|---|
| `result.success(value)` | 成功 | `Future` が完了（value を返す） |
| `result.error(code, message, detail)` | エラー | `PlatformException` が throw される |
| `result.notImplemented()` | 未実装 | `MissingPluginException` が throw される |

---

## 5. iOS 実装（Swift）

`ios/Runner/AppDelegate.swift`:

```swift
override func application(...) -> Bool {
  let controller = window?.rootViewController as! FlutterViewController
  let deviceChannel = FlutterMethodChannel(
    name: "com.example.flutter_study/device",
    binaryMessenger: controller.binaryMessenger
  )
  deviceChannel.setMethodCallHandler { call, result in
    switch call.method {
    case "getDeviceModel":
      // UIDevice.current.model は "iPhone" / "iPad" を返す
      result(UIDevice.current.model)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  GeneratedPluginRegistrant.register(with: self)
  return super.application(...)
}
```

### iOS の注意点

```
UIDevice.current.model → "iPhone" または "iPad"
  ※ "iPhone 16 Pro" のような詳細なモデル名は返さない

詳細なモデル名が必要な場合は sysctlbyname を使う:
  var size = 0
  sysctlbyname("hw.machine", nil, &size, nil, 0)
  var machine = [CChar](repeating: 0, count: size)
  sysctlbyname("hw.machine", &machine, &size, nil, 0)
  // → "iPhone16,1" などのハードウェア識別子
```

---

## 6. テスト戦略

### MethodChannel のモック方法

ネイティブコードはテスト環境では動かないため、`TestDefaultBinaryMessengerBinding` でモックする:

```dart
TestWidgetsFlutterBinding.ensureInitialized(); // バインディング初期化が必要

TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    .setMockMethodCallHandler(
  const MethodChannel('com.example.flutter_study/device'),
  (call) async {
    if (call.method == 'getDeviceModel') return 'Test iPhone';
    return null; // null を返すと Dart 側で 'Unknown' になる
  },
);
```

### UseCase のテスト

```
Domain UseCase テスト
  MockDeviceInfoRepository を使う
  → MethodChannel を知らない純粋な Dart テスト
```

### レイヤーごとのテスト範囲

| テスト | ファイル | モック対象 |
|---|---|---|
| UseCase | `get_device_model_test.dart` | MockDeviceInfoRepository |
| DataSource | `device_info_data_source_test.dart` | TestDefaultBinaryMessengerBinding |

---

## 7. よくあるエラーと対処法

### `MissingPluginException`

```
MissingPluginException(No implementation found for method getDeviceModel
on channel com.example.flutter_study/device)
```

原因:
- チャンネル名のスペルミス（Flutter 側 ≠ ネイティブ側）
- ネイティブ側でハンドラを登録していない

対処:
- Flutter 側とネイティブ側のチャンネル名を一致させる
- iOS: `GeneratedPluginRegistrant.register` の**前**に `setMethodCallHandler` を呼ぶ

### `PlatformException`

```
PlatformException(UNAVAILABLE, ...)
```

原因: ネイティブ側が `result.error(...)` を呼んだ

対処: RepositoryImpl で catch して `Failure` に変換する（実装済み）

---

## 8. 完了チェックリスト

- [x] `DeviceInfoDataSourceImpl` が MethodChannel 経由でデバイス情報を取得する
- [x] `DeviceInfoRepositoryImpl` が PlatformException → Failure に変換する
- [x] Android: `MainActivity.kt` に MethodChannel ハンドラが登録されている
- [x] iOS: `AppDelegate.swift` に MethodChannel ハンドラが登録されている
- [x] HomeScreen にデバイスモデルが表示される
- [x] UseCase テストが通っている（MockRepository 使用）
- [x] DataSource テストが通っている（TestDefaultBinaryMessengerBinding 使用）
