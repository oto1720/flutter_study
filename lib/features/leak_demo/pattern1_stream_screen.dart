import 'dart:async';
import 'package:flutter/material.dart';

/// パターン1: StreamSubscription の未キャンセル
///
/// このファイルには「リークあり版」と「修正版」の2つの Widget がある。
/// どちらも 1秒ごとにカウントアップするストリームを購読する。
///
/// 違いを観察する手順:
///   1. DevTools > Memory を開く
///   2. LeakyStreamScreen に遷移 → 戻る を 10回繰り返す
///   3. GC を押す → カウンターが止まらずコンソールに出力が続くことを確認
///      （Widget は破棄されたが listener が生き続けている証拠）
///   4. FixedStreamScreen で同じ操作 → 戻ると出力が止まることを確認

// ============================================================
// NG: StreamSubscription をキャンセルしないバージョン
// ============================================================

class LeakyStreamScreen extends StatefulWidget {
  const LeakyStreamScreen({super.key});

  @override
  State<LeakyStreamScreen> createState() => _LeakyStreamScreenState();
}

class _LeakyStreamScreenState extends State<LeakyStreamScreen> {
  int _count = 0;

  @override
  void initState() {
    super.initState();

    // ❌ subscription を保持せずキャンセルできない
    // この Widget が破棄されても 1秒ごとのコールバックが残り続ける
    Stream.periodic(const Duration(seconds: 1), (i) => i).listen((value) {
      debugPrint('[LEAK] LeakyStreamScreen: count=$value (Widget は生きているか?)');
      // mounted チェックもないため、破棄済みの setState を呼ぶ可能性がある
      if (mounted) setState(() => _count = value);
    });
  }

  // ❌ dispose() の override がない → subscription がキャンセルされない

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('❌ リークあり: Stream'),
        backgroundColor: Colors.red.shade100,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('カウント: $_count',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '← 戻る を押してからターミナルを確認\n'
                'コンソールに [LEAK] の出力が続いていたらリーク中',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// OK: StreamSubscription を正しくキャンセルするバージョン
// ============================================================

class FixedStreamScreen extends StatefulWidget {
  const FixedStreamScreen({super.key});

  @override
  State<FixedStreamScreen> createState() => _FixedStreamScreenState();
}

class _FixedStreamScreenState extends State<FixedStreamScreen> {
  int _count = 0;
  // ✅ subscription を保持してキャンセルできるようにする
  late StreamSubscription<int> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = Stream.periodic(
      const Duration(seconds: 1),
      (i) => i,
    ).listen((value) {
      debugPrint('[FIXED] FixedStreamScreen: count=$value');
      setState(() => _count = value);
    });
  }

  @override
  void dispose() {
    // ✅ Widget が破棄されるときに必ずキャンセル
    _subscription.cancel();
    debugPrint('[FIXED] subscription.cancel() called → リークなし');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('✅ 修正版: Stream'),
        backgroundColor: Colors.green.shade100,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 16),
            Text('カウント: $_count',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '← 戻る を押してからターミナルを確認\n'
                '[FIXED] subscription.cancel() が出力され\n'
                'その後 [FIXED] の出力が止まればOK',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.green),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 比較画面: リークあり / 修正版 の選択
// ============================================================

class Pattern1CompareScreen extends StatelessWidget {
  const Pattern1CompareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('パターン1: Stream')),
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
                      '• Stream.listen() の戻り値 StreamSubscription を保持しないとキャンセルできない\n'
                      '• dispose() で subscription.cancel() を呼ぶことが必須\n'
                      '• Riverpod の StreamProvider は自動管理するため手動不要',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('どちらかを起動してターミナルのログを確認してください'),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              icon: const Icon(Icons.warning),
              label: const Text('リークあり版を起動'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const LeakyStreamScreen()),
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
                    builder: (_) => const FixedStreamScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
