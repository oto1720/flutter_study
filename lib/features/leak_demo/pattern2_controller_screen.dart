import 'package:flutter/material.dart';

/// パターン2: TextEditingController / AnimationController の未 dispose
///
/// Controller 系は内部でリスナーを保持している。
/// StatefulWidget で作成して dispose() を呼ばないと Flutter が警告を出す。
///
/// 違いを観察する手順:
///   1. LeakyControllerScreen に遷移して戻る
///   2. デバッグコンソールに「A TextEditingController was disposed...」のような
///      Flutter の警告が出ることを確認（実際にはリリースビルドでは出ない）
///   3. DevTools Memory タブで TextEditingController のインスタンス数を確認

// ============================================================
// NG: Controller を dispose しないバージョン
// ============================================================

class LeakyControllerScreen extends StatefulWidget {
  const LeakyControllerScreen({super.key});

  @override
  State<LeakyControllerScreen> createState() => _LeakyControllerScreenState();
}

class _LeakyControllerScreenState extends State<LeakyControllerScreen>
    with SingleTickerProviderStateMixin {
  // ❌ これらの Controller は dispose() で解放されない
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(); // ループアニメーション開始
  }

  // ❌ dispose() の override がない
  // → Widget 破棄後も AnimationController が tick し続ける
  // → TextEditingController のリスナーも解放されない
  // → Flutter はデバッグモードでこれを検知して警告を出す

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('❌ リークあり: Controller'),
        backgroundColor: Colors.red.shade100,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.warning, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            // アニメーション（破棄後も動き続ける）
            AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return LinearProgressIndicator(
                  value: _animController.value,
                  color: Colors.red,
                );
              },
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'メール（リーク中）'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'パスワード（リーク中）'),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            const Text(
              '← 戻る を押してコンソールを確認\n'
              'Flutter が Controller のリークを警告する',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// OK: Controller を正しく dispose するバージョン
// ============================================================

class FixedControllerScreen extends StatefulWidget {
  const FixedControllerScreen({super.key});

  @override
  State<FixedControllerScreen> createState() => _FixedControllerScreenState();
}

class _FixedControllerScreenState extends State<FixedControllerScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    // ✅ 作成したものは必ず dispose する（作成順の逆順で呼ぶのが慣例）
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    debugPrint('[FIXED] 全 Controller を dispose しました');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('✅ 修正版: Controller'),
        backgroundColor: Colors.green.shade100,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return LinearProgressIndicator(
                  value: _animController.value,
                  color: Colors.green,
                );
              },
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'メール（正常）'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'パスワード（正常）'),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            const Text(
              '← 戻る を押してコンソールを確認\n'
              '[FIXED] dispose のログが出て警告なし',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.green),
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

class Pattern2CompareScreen extends StatelessWidget {
  const Pattern2CompareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('パターン2: Controller')),
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
                      '• TextEditingController / AnimationController は内部リスナーを持つ\n'
                      '• StatefulWidget で作成したら dispose() で必ず解放する\n'
                      '• flutter_hooks の useTextEditingController() は自動管理\n'
                      '• Flutter はデバッグモードでリークを警告してくれる',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('どちらかを起動してコンソールとコードを比較してください'),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              icon: const Icon(Icons.warning),
              label: const Text('リークあり版を起動'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const LeakyControllerScreen()),
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
                    builder: (_) => const FixedControllerScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
