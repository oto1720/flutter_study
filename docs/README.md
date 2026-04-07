# Flutter Clean Architecture + Firebase Auth 学習ドキュメント

## このドキュメントについて

このリポジトリでは **Firebase Authentication** と **Clean Architecture** を組み合わせた Flutter アプリを段階的に実装しました。各フェーズの「なぜそう設計するか」を理解することが目的です。

---

## アーキテクチャ全体図

```
┌─────────────────────────────────────────────┐
│              Presentation 層                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │ Screen   │  │ Notifier │  │ Provider │  │
│  │ (Widget) │  │(AuthState│  │  (DI)    │  │
│  └──────────┘  └──────────┘  └──────────┘  │
└──────────────────┬──────────────────────────┘
                   │ ref.read / watch
┌──────────────────▼──────────────────────────┐
│               Domain 層                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │  Entity  │  │UseCase   │  │Repository│  │
│  │(AppUser) │  │(SignIn..)│  │Interface │  │
│  └──────────┘  └──────────┘  └──────────┘  │
└──────────────────▲──────────────────────────┘
                   │ implements
┌──────────────────┴──────────────────────────┐
│               Data 層                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │UserModel │  │DataSource│  │Repository│  │
│  │toEntity()│  │(Firebase)│  │Impl      │  │
│  └──────────┘  └──────────┘  └──────────┘  │
└─────────────────────────────────────────────┘

依存の向き: Presentation → Domain ← Data
Domain は Firebase も Flutter も知らない
```

---

## 依存関係ルール（最重要）

**内側の層は外側の層を知らない**

| 層 | 知っていること | 知らないこと |
|---|---|---|
| Domain | Dart 標準ライブラリ、fpdart | Firebase、Flutter、Riverpod |
| Data | Firebase SDK、Domain の型 | Presentation、Riverpod |
| Presentation | Riverpod、Flutter、Domain の型 | Firebase SDK |

この制約があるから、Firebase を別サービスに変えても Domain 層は無変更で済む。

---

## フェーズ一覧

| フェーズ | 内容 | ドキュメント |
|---|---|---|
| Phase 1 | Foundation（Firebase初期化・パッケージ・Failure Sealed class） | [phase1-foundation.md](./phase1-foundation.md) |
| Phase 2 | Domain層（Entity・Repository Interface・UseCase） | [phase2-domain-layer.md](./phase2-domain-layer.md) |
| Phase 3 | Data層（UserModel・DataSource・RepositoryImpl） | [phase3-data-layer.md](./phase3-data-layer.md) |
| Phase 4 | Presentation Providers（DI・AuthState・Notifier） | [phase4-presentation-providers.md](./phase4-presentation-providers.md) |
| Phase 5 | UI 画面（GoRouter・3画面・Widgetテスト） | [phase5-ui-screens.md](./phase5-ui-screens.md) |
| Phase 6 | Flutter Hooks（HookConsumerWidget・useTextEditingController・useState） | [phase6-flutter-hooks.md](./phase6-flutter-hooks.md) |
| Phase 7 | テスト戦略（4層テスト・mocktail・ProviderContainer・カバレッジ70%） | [phase7-testing.md](./phase7-testing.md) |
| Phase 8 | パフォーマンス最適化（DevTools・select・RepaintBoundary・const） | [phase8-performance.md](./phase8-performance.md) |
| Phase 9 | メモリリーク対策（StreamSubscription・Controller dispose・ref.listen・DevTools） | [phase9-memory-leak.md](./phase9-memory-leak.md) |
| Phase 10 | MethodChannel（Flutter↔ネイティブ連携・デバイス情報取得・PlatformException処理） | [phase10-method-channel.md](./phase10-method-channel.md) |

---

## テスト戦略の全体像

```
Layer 1: Domain UseCase テスト
  依存: MockAuthRepository のみ
  ツール: mocktail
  特徴: Firebase 不要・最速・最も純粋

Layer 2: Data Repository テスト
  依存: FakeAuthRemoteDataSource（インメモリ実装）
  ツール: flutter_test
  特徴: Firebase 不要・実装の振る舞いを検証

Layer 3: Presentation Notifier テスト
  依存: ProviderContainer + overrides
  ツール: flutter_riverpod test utilities
  特徴: Widget 不要・状態遷移の順序を検証

Layer 4: Widget テスト
  依存: FakeAuthStateNotifier
  ツール: flutter_test + pumpWidget
  特徴: UI の振る舞いを検証
```

---

## 使用パッケージと選定理由

| パッケージ | 役割 | 選定理由 |
|---|---|---|
| `hooks_riverpod` | 状態管理・DI・Hooks 統合 | `flutter_riverpod` + `flutter_hooks` を一つにまとめたパッケージ |
| `flutter_hooks` | ローカル状態の Hook 管理 | `initState`/`dispose` のボイラープレートを排除 |
| `go_router` | ルーティング | 宣言的 redirect ガード |
| `freezed` | イミュータブルクラス | sealed class でコンパイル時に全ケース網羅を強制 |
| `fpdart` | Either 型 | エラーを型に出す（見落とし不可） |
| `mocktail` | テスト用モック | コード生成不要 |

---

## ディレクトリ構成

```
lib/
├── main.dart
├── firebase_options.dart
├── core/
│   ├── error/
│   │   └── failure.dart           # Sealed class: 全エラー型
│   └── router/
│       └── app_router.dart        # GoRouter + 認証ガード
└── features/
    └── auth/
        ├── domain/                # ← 純粋 Dart。外部依存ゼロ
        │   ├── entities/app_user.dart
        │   ├── repositories/auth_repository.dart
        │   └── usecases/
        ├── data/                  # ← Firebase SDK を使う唯一の場所
        │   ├── datasources/
        │   ├── models/
        │   └── repositories/
        └── presentation/          # ← Riverpod + Widget
            ├── providers/
            ├── screens/
            └── widgets/

test/
├── helpers/
│   ├── test_helpers.dart          # MockAuthRepository
│   └── fakes/
│       └── fake_auth_remote_data_source.dart
└── features/auth/
    ├── domain/usecases/
    ├── data/repositories/
    └── presentation/
        ├── providers/
        └── screens/
```
