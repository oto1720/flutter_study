import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_learn/core/error/failure.dart';
import 'package:flutter_learn/features/auth/presentation/providers/auth_state_notifier.dart';
import 'package:flutter_learn/features/auth/presentation/widgets/auth_text_field.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

    final isLoading = ref.watch(
      authStateNotifierProvider
          .select((s) => s.maybeWhen(loading: () => true, orElse: () => false)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('アカウント作成')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _confirmPasswordController,
                  label: 'パスワード（確認）',
                  obscureText: true,
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'パスワードが一致しません';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: isLoading ? null : _onRegister,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('アカウントを作成する'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onRegister() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authStateNotifierProvider.notifier).signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
  }
}
