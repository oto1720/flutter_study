import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_learn/core/error/failure.dart';
import 'package:flutter_learn/core/router/app_router.dart';
import 'package:flutter_learn/features/auth/presentation/providers/auth_state_notifier.dart';
import 'package:flutter_learn/features/auth/presentation/widgets/auth_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AuthState の変化を監視してエラーを SnackBar で表示
    // maybeWhen: error ケースだけ処理し、それ以外は orElse で無視
    ref.listen<AuthState>(authStateNotifierProvider, (previous, next) {
      next.maybeWhen(
        error: (failure) {
          final message = switch (failure) {
            AuthFailure(:final message) => message,
            NetworkFailure() => 'ネットワークエラーが発生しました',
            UnexpectedFailure() => '予期しないエラーが発生しました',
          };
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        },
        orElse: () {},
      );
    });

    // maybeWhen: loading ケースだけ true を返し、それ以外は false
    final isLoading = ref.watch(
      authStateNotifierProvider
          .select((s) => s.maybeWhen(loading: () => true, orElse: () => false)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('ログイン')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Text(
                  'Flutter Auth Study',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                AuthTextField(
                  controller: _emailController,
                  label: 'メールアドレス',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'メールアドレスを入力してください';
                    if (!value.contains('@')) return '正しいメールアドレスを入力してください';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _passwordController,
                  label: 'パスワード',
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'パスワードを入力してください';
                    if (value.length < 6) return 'パスワードは6文字以上で入力してください';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: isLoading ? null : _onSignIn,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('ログイン'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: isLoading ? null : _onGoogleSignIn,
                  icon: const Icon(Icons.login),
                  label: const Text('Google でログイン'),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => context.push(Routes.register),
                  child: const Text('アカウントを作成する'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authStateNotifierProvider.notifier).signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
  }

  Future<void> _onGoogleSignIn() async {
    await ref.read(authStateNotifierProvider.notifier).signInWithGoogle();
  }
}
