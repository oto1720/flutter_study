import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_learn/features/auth/domain/entities/app_user.dart';
import 'package:flutter_learn/features/auth/presentation/providers/auth_state_notifier.dart';
import 'package:flutter_learn/features/device/presentation/providers/device_info_providers.dart';
import 'package:flutter_learn/features/user_profile/presentation/providers/user_profile_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ select で AppUser? だけを監視する
    // Before: ref.watch(authStateNotifierProvider) → AuthState 全体を監視
    //   → loading / error への遷移でも HomeScreen 全体がリビルドされていた
    // After: select で AppUser? に絞る
    //   → user の中身が変わったときだけリビルド（サインアウト中の loading は無視）
    final user = ref.watch(
      authStateNotifierProvider.select(
        (s) => s.maybeWhen(authenticated: (user) => user, orElse: () => null),
      ),
    );

    // ✅ deviceInfoProvider は AsyncNotifierProvider — AsyncValue で取得
    final deviceInfoAsync = ref.watch(deviceInfoProvider);

    // ✅ userProfileProvider(1): keepAlive: true でキャッシュ
    // 同じ userId の場合は HTTP を再送信しない
    // JSONPlaceholder の userId=1 のプロフィールを表示
    final profileAsync = ref.watch(userProfileProvider(1));

    return Scaffold(
      appBar: AppBar(
        title: const Text('ホーム'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'サインアウト',
            onPressed: () =>
                ref.read(authStateNotifierProvider.notifier).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              // ✅ RepaintBoundary: アバターはネットワーク画像ロードなど
              // 独自のリペイントが起きやすいため境界を設ける
              Center(
                child: RepaintBoundary(
                  child: _UserAvatar(user: user),
                ),
              ),
              const SizedBox(height: 24),
              // ✅ RepaintBoundary: ユーザー情報タイルは独立して描画
              // 他のUI変化（アバターのロードなど）に連動してリペイントしない
              RepaintBoundary(
                child: Column(
                  children: [
                    _InfoTile(label: 'メールアドレス', value: user?.email ?? '-'),
                    const SizedBox(height: 8),
                    _InfoTile(
                      label: '表示名',
                      value: user?.displayName ?? '未設定',
                    ),
                    const SizedBox(height: 8),
                    _InfoTile(label: 'ユーザーID', value: user?.id ?? '-'),
                    const SizedBox(height: 8),
                    // ✅ MethodChannel 経由で取得したデバイス情報を表示
                    // AsyncValue.when で loading / error / data を安全にハンドリング
                    _InfoTile(
                      label: 'デバイス',
                      value: deviceInfoAsync.when(
                        data: (info) => info.model,
                        loading: () => '取得中...',
                        error: (_, __) => '取得失敗',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ✅ API から取得したユーザープロフィールセクション
              // keepAlive: true により一度取得したら再フェッチしない
              RepaintBoundary(
                child: _ApiProfileSection(profileAsync: profileAsync),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// API プロフィールセクション
///
/// AsyncValue の状態（loading / error / data）を安全にハンドリングして表示する。
class _ApiProfileSection extends StatelessWidget {
  const _ApiProfileSection({required this.profileAsync});

  final AsyncValue<dynamic> profileAsync;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'API プロフィール (JSONPlaceholder)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              leading: const Icon(Icons.error_outline),
              title: Text(
                '取得失敗',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ),
          data: (profile) => Column(
            children: [
              _InfoTile(label: '名前', value: profile.name as String),
              const SizedBox(height: 8),
              _InfoTile(label: 'メール', value: profile.email as String),
              const SizedBox(height: 8),
              _InfoTile(label: '電話', value: profile.phone as String),
              const SizedBox(height: 8),
              _InfoTile(label: '会社名', value: profile.companyName as String),
            ],
          ),
        ),
      ],
    );
  }
}

// ✅ アバター部分を独立 Widget に抽出
// - build メソッドが小さくなり責務が明確になる
// - RepaintBoundary と組み合わせることでネットワーク画像ロード時の
//   リペイント範囲をこの Widget 内に閉じ込めることができる
class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 40,
      backgroundImage: user?.photoUrl != null
          ? NetworkImage(user!.photoUrl!)
          : null,
      child: user?.photoUrl == null
          ? Text(
              user?.displayName?.isNotEmpty == true
                  ? user!.displayName![0].toUpperCase()
                  : '?',
              style: const TextStyle(fontSize: 32),
            )
          : null,
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label, style: Theme.of(context).textTheme.bodySmall),
        subtitle: Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}
