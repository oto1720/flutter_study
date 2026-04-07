import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_learn/core/router/app_router.dart';

/// メモリリーク学習デモのメニュー画面
///
/// 各パターンに対して「リークあり版」と「修正版」の2つの画面を用意している。
/// DevTools の Memory タブを開きながら操作すると違いが観察できる。
///
/// 観察手順:
///   1. flutter run --debug で起動
///   2. DevTools > Memory タブを開く
///   3. 「リークあり版」を開いて戻る操作を繰り返す
///   4. [GC] ボタンを押してもヒープが減らないことを確認
///   5. 「修正版」で同じ操作を行いヒープが安定することを確認
class LeakDemoMenuScreen extends StatelessWidget {
  const LeakDemoMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('メモリリーク学習デモ'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader(context, 'DevTools の開き方'),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '1. ターミナルで flutter run --debug を実行\n'
                '2. 表示される URL または VSCode の DevTools ボタンから開く\n'
                '3. Memory タブ → [GC] で強制 GC → Heap スナップショットで比較',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionHeader(context, 'パターン一覧'),
          _PatternTile(
            number: 1,
            title: 'StreamSubscription の未キャンセル',
            description: '定期的なストリームを listen したまま dispose しない',
            route: Routes.leakPattern1,
          ),
          _PatternTile(
            number: 2,
            title: 'Controller の未 dispose',
            description:
                'TextEditingController / AnimationController を dispose しない',
            route: Routes.leakPattern2,
          ),
          _PatternTile(
            number: 3,
            title: 'ChangeNotifier リスナーの未解除',
            description: 'addListener したまま removeListener を呼ばない',
            route: Routes.leakPattern3,
          ),
          _PatternTile(
            number: 4,
            title: 'async 後の BuildContext 使用',
            description: 'await 後に Widget が破棄されているのに context を使う',
            route: Routes.leakPattern4,
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _PatternTile extends StatelessWidget {
  const _PatternTile({
    required this.number,
    required this.title,
    required this.description,
    required this.route,
  });

  final int number;
  final String title;
  final String description;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Text('$number')),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(route),
      ),
    );
  }
}
