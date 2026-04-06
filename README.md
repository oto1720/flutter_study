# Flutter Clean Architecture + Firebase Auth 学習プロジェクト

[![Flutter CI](https://github.com/oto1720/flutter_study/actions/workflows/test.yml/badge.svg)](https://github.com/oto1720/flutter_study/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/oto1720/flutter_study/branch/main/graph/badge.svg)](https://codecov.io/gh/oto1720/flutter_study)

Firebase Authentication × Clean Architecture × Flutter Hooks を段階的に実装する学習リポジトリです。

## 学習ドキュメント

詳細な設計解説は [docs/README.md](docs/README.md) を参照してください。

## アーキテクチャ概要

```
Presentation層 (Riverpod + Flutter Hooks)
      ↓
Domain層 (Entity / UseCase / Repository Interface) ← 外部依存ゼロ
      ↑
Data層 (Firebase SDK / Repository Impl)
```

## テスト実行

```bash
# 全テスト + カバレッジ
flutter test --coverage

# 静的解析
flutter analyze
```

## CI/CD

`main` ブランチへの PR で自動実行されます。

- `flutter analyze` — 静的解析
- `flutter test --coverage` — 全テスト + カバレッジ計測
- PR へのカバレッジコメント
- Codecov へのカバレッジアップロード
