import 'package:flutter/material.dart';

/// パターン4: async 処理後の BuildContext 使用
///
/// await の後に Widget が破棄されている場合、context を使うと
/// "Looking up a deactivated widget's ancestor is unsafe" という
/// Flutter の警告または例外が発生する。
///
/// 違いを観察する手順:
///   1. LeakyAsyncScreen でボタンを押す
///   2. 3秒の処理が終わる前に ← 戻る を押す
///   3. コンソールに Flutter の警告が出ることを確認
///   4. FixedAsyncScreen で同じ操作 → mounted チェックで安全に処理が止まることを確認

// ============================================================
// NG: async 後に mounted チェックなし
// ============================================================

class LeakyAsyncScreen extends StatefulWidget {
  const LeakyAsyncScreen({super.key});

  @override
  State<LeakyAsyncScreen> createState() => _LeakyAsyncScreenState();
}

class _LeakyAsyncScreenState extends State<LeakyAsyncScreen> {
  bool _isLoading = false;

  Future<void> _onButtonPressed() async {
    setState(() => _isLoading = true);

    // 重い処理をシミュレート（3秒待機）
    await Future.delayed(const Duration(seconds: 3));

    debugPrint('[LEAK] await 完了。Widget は生きているか? mounted=$mounted');

    // ❌ mounted チェックなし
    // この行の実行時に Widget が破棄されていると警告/例外が発生する
    setState(() => _isLoading = false);

    // ❌ context が無効になっている可能性がある
    // ignore: use_build_context_synchronously  ← 学習用に意図的にリークさせているため抑制
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('処理完了（リスクあり）')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('❌ リークあり: async context'),
        backgroundColor: Colors.red.shade100,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning, color: Colors.red, size: 48),
            const SizedBox(height: 24),
            if (_isLoading) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('3秒後に完了...'),
              const SizedBox(height: 8),
              const Text(
                '← 今すぐ戻るとコンソールに警告が出る',
                style: TextStyle(color: Colors.red),
              ),
            ] else
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: _onButtonPressed,
                child: const Text('非同期処理を開始（3秒）'),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// OK: mounted チェックを入れるバージョン
// ============================================================

class FixedAsyncScreen extends StatefulWidget {
  const FixedAsyncScreen({super.key});

  @override
  State<FixedAsyncScreen> createState() => _FixedAsyncScreenState();
}

class _FixedAsyncScreenState extends State<FixedAsyncScreen> {
  bool _isLoading = false;

  Future<void> _onButtonPressed() async {
    setState(() => _isLoading = true);

    await Future.delayed(const Duration(seconds: 3));

    debugPrint('[FIXED] await 完了。mounted=$mounted');

    // ✅ await 後は必ず mounted を確認
    // Widget が破棄されていたら context の操作をスキップ
    if (!mounted) {
      debugPrint('[FIXED] Widget は破棄済み。context の操作をスキップ');
      return;
    }

    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('処理完了（安全）')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('✅ 修正版: async context'),
        backgroundColor: Colors.green.shade100,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 24),
            if (_isLoading) ...[
              const CircularProgressIndicator(color: Colors.green),
              const SizedBox(height: 16),
              const Text('3秒後に完了...'),
              const SizedBox(height: 8),
              const Text(
                '← 今すぐ戻っても警告は出ない',
                style: TextStyle(color: Colors.green),
              ),
            ] else
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.green),
                onPressed: _onButtonPressed,
                child: const Text('非同期処理を開始（3秒）'),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 参考: Riverpod でのベストプラクティス
// ============================================================
//
// このプロジェクトでは GoRouter による宣言的ナビゲーションを使うことで
// async 後に context を使わない設計になっている。
//
// // app_router.dart の redirect
// redirect: (context, state) {
//   final isAuthenticated = ref.read(authStateStreamProvider).value != null;
//   if (isAuthenticated) return '/home'; // context 不要
//   return null;
// },
//
// Notifier 側で state を更新すれば GoRouter が自動でリダイレクトするため
// SnackBar などの表示だけに context が必要になる。
// その場合は ref.listen() を build() 内で使い、Riverpod に管理させる。

// ============================================================
// 比較画面
// ============================================================

class Pattern4CompareScreen extends StatelessWidget {
  const Pattern4CompareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('パターン4: async context')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('何を学ぶか',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text(
                      '• await の後は Widget が破棄されている可能性がある\n'
                      '• if (!mounted) return; で安全に早期リターン\n'
                      '• GoRouter + Riverpod の宣言的設計で context 操作を最小化\n'
                      '• SnackBar 等は ref.listen() を build() 内で使い Riverpod に委ねる',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('ボタンを押してから3秒以内に ← 戻る を押して比較してください'),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              icon: const Icon(Icons.warning),
              label: const Text('リークあり版を起動'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const LeakyAsyncScreen()),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
              icon: const Icon(Icons.check_circle),
              label: const Text('修正版を起動'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const FixedAsyncScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
