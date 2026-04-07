import 'package:flutter/material.dart';

/// パターン3: ChangeNotifier リスナーの未解除
///
/// ChangeNotifier.addListener() したリスナーを removeListener() で
/// 解除しないと、ChangeNotifier がリスナーへの参照を持ち続けリークする。
///
/// Riverpod の ref.watch / ref.listen は Provider のライフサイクルで
/// 自動管理されるが、生の ChangeNotifier を使う場合は手動管理が必要。
///
/// 違いを観察する手順:
///   1. LeakyListenerScreen に遷移 → 戻る を 5回繰り返す
///   2. ボタンを押すたびにコンソールに [LEAK] のログが増えることを確認
///      （ 1回遷移するたびにリスナーが1つ追加される）
///   3. FixedListenerScreen では戻るとリスナーが解除されることを確認

// ============================================================
// 共有の ChangeNotifier（カウンター）
// ============================================================

class CounterNotifier extends ChangeNotifier {
  int _count = 0;
  int get count => _count;

  void increment() {
    _count++;
    notifyListeners();
  }
}

// アプリ全体で1つのインスタンスを共有（グローバルに保持してリークを観察しやすくする）
final globalCounterNotifier = CounterNotifier();

// ============================================================
// NG: リスナーを解除しないバージョン
// ============================================================

class LeakyListenerScreen extends StatefulWidget {
  const LeakyListenerScreen({super.key});

  @override
  State<LeakyListenerScreen> createState() => _LeakyListenerScreenState();
}

class _LeakyListenerScreenState extends State<LeakyListenerScreen> {
  @override
  void initState() {
    super.initState();
    // ❌ addListener はするが removeListener しない
    // このScreen を何度も開閉するとリスナーが蓄積する
    globalCounterNotifier.addListener(_onCounterChanged);
    debugPrint('[LEAK] リスナー追加。現在のリスナー数は Flutter 内部で管理されている');
  }

  void _onCounterChanged() {
    debugPrint(
        '[LEAK] _onCounterChanged: count=${globalCounterNotifier.count} '
        '(このWidgetは生きているか? mounted=$mounted)');
    // mounted チェックなしで setState → 破棄済みの場合エラーになる
    setState(() {});
  }

  // ❌ dispose() で removeListener していない

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('❌ リークあり: Listener'),
        backgroundColor: Colors.red.shade100,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'カウント: ${globalCounterNotifier.count}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: globalCounterNotifier.increment,
              child: const Text('カウントアップ'),
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '← 戻る を繰り返してから\nカウントアップを押すと\n[LEAK] ログが複数出力される',
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
// OK: リスナーを正しく解除するバージョン
// ============================================================

class FixedListenerScreen extends StatefulWidget {
  const FixedListenerScreen({super.key});

  @override
  State<FixedListenerScreen> createState() => _FixedListenerScreenState();
}

class _FixedListenerScreenState extends State<FixedListenerScreen> {
  @override
  void initState() {
    super.initState();
    // ✅ addListener と対になる removeListener を dispose() に書く
    globalCounterNotifier.addListener(_onCounterChanged);
    debugPrint('[FIXED] リスナー追加');
  }

  void _onCounterChanged() {
    debugPrint('[FIXED] _onCounterChanged: count=${globalCounterNotifier.count}');
    if (mounted) setState(() {}); // ✅ mounted チェックも追加
  }

  @override
  void dispose() {
    // ✅ addListener と対になる removeListener
    globalCounterNotifier.removeListener(_onCounterChanged);
    debugPrint('[FIXED] リスナー解除 → リークなし');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('✅ 修正版: Listener'),
        backgroundColor: Colors.green.shade100,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 16),
            Text(
              'カウント: ${globalCounterNotifier.count}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: globalCounterNotifier.increment,
              child: const Text('カウントアップ'),
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '← 戻ると [FIXED] リスナー解除 が出力される\n'
                'その後カウントアップしても [FIXED] は出ない',
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
// 比較画面
// ============================================================

class Pattern3CompareScreen extends StatelessWidget {
  const Pattern3CompareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('パターン3: ChangeNotifier')),
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
                      '• addListener() した関数は removeListener() で必ず解除する\n'
                      '• 解除しないと画面を開閉するたびにリスナーが蓄積する\n'
                      '• Riverpod の ref.watch / ref.listen は自動管理なので安全\n'
                      '• disposed 後の setState は例外になるため mounted チェックも重要',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('リークあり版を複数回開閉してからカウントアップして比較してください'),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              icon: const Icon(Icons.warning),
              label: const Text('リークあり版を起動'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const LeakyListenerScreen()),
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
                    builder: (_) => const FixedListenerScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
